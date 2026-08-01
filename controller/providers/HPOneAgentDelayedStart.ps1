[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-101'
$provider='hp-one-agent-delayed-start'
$profile='HPOneAgentDelayedStart'
$minimumSafeVersion=[version]'1.3.214.7339'
$protected='(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|defender|securityhealth|firewall|bitlocker|credential|windows update|recovery|intune|sccm|configmgr|mdm|vpn|ndis|driver|firmware'

function Write-StructuredLog([string]$Event,[string]$Result,[object]$Data){
    if([string]::IsNullOrWhiteSpace($LogPath)){return}
    $parent=Split-Path -Parent $LogPath
    if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 24|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-TextHash([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$sha.Dispose()}}
function Test-Elevated{$id=[Security.Principal.WindowsIdentity]::GetCurrent();(New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-ManagementState{
    $computer=Get-CimInstance Win32_ComputerSystem
    $signals=[ordered]@{
        DomainJoined=[bool]$computer.PartOfDomain
        MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count
        PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device'
        ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
        IntuneManagementExtension=[bool](Get-Service IntuneManagementExtension -ErrorAction SilentlyContinue)
    }
    [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt0-or$signals.PolicyManager-or$signals.ConfigMgr-or$signals.IntuneManagementExtension);Signals=$signals}
}
function Get-SupportState{
    $os=Get-CimInstance Win32_OperatingSystem;$computer=Get-CimInstance Win32_ComputerSystem;$bios=Get-CimInstance Win32_BIOS;$m=Get-ManagementState
    [pscustomobject]@{Supported=($os.Caption-match'Windows 11'-and$computer.Manufacturer-match'(?i)^HP$|Hewlett-Packard'-and(Test-Elevated));Elevated=Test-Elevated;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$computer.Manufacturer;Model=$computer.Model;BIOS=$bios.SMBIOSBIOSVersion;Managed=$m.Managed;ManagementSignals=$m.Signals}
}
function Get-ProtectedSnapshot{
    $services=foreach($name in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){$s=Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue;if($s){[ordered]@{Name=$s.Name;State=$s.State;StartMode=$s.StartMode;PathName=$s.PathName}}}
    $processes=Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale'}|Sort-Object ProcessName|Select-Object ProcessName,Id
    $json=[ordered]@{Services=@($services);Processes=@($processes)}|ConvertTo-Json -Compress -Depth 8
    [pscustomobject]@{Hash=Get-TextHash $json;Snapshot=$json}
}
function Resolve-ServiceExecutable([string]$PathName){
    $expanded=[Environment]::ExpandEnvironmentVariables($PathName).Trim()
    if($expanded-match$protected){return $null}
    if($expanded-match'^\s*"(?<exe>[^"]+\.exe)"'){$path=$matches.exe}elseif($expanded-match'^\s*(?<exe>\S+\.exe)'){$path=$matches.exe}else{return $null}
    try{[IO.Path]::GetFullPath($path)}catch{return $null}
}
function Get-PackageInventory([string]$Executable){
    $parent=Split-Path -Parent $Executable
    $roots='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    $items=foreach($root in $roots){Get-ChildItem $root -ErrorAction SilentlyContinue|ForEach-Object{$p=Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue;if($p.Publisher-match'(?i)HP|Hewlett-Packard' -and (($p.DisplayName-match'(?i)HP One Agent|HP Privacy Settings') -or ($p.InstallLocation -and $parent.StartsWith([string]$p.InstallLocation,[StringComparison]::OrdinalIgnoreCase)))){[ordered]@{Key=$_.PSChildName;DisplayName=$p.DisplayName;DisplayVersion=$p.DisplayVersion;Publisher=$p.Publisher;InstallLocation=$p.InstallLocation}}}}
    @($items)
}
function Get-OneAgentTasks([string]$ServiceName){
    $items=foreach($task in Get-ScheduledTask -ErrorAction SilentlyContinue){
        if($task.TaskName-match'(?i)HpOneAgent.*(Repair|Update)' -or $task.TaskPath-match'(?i)HP.*OneAgent'){
            $xml=Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath
            $definitionHash=Get-TextHash $xml
            [ordered]@{TaskName=$task.TaskName;TaskPath=$task.TaskPath;State=$task.State.ToString();DefinitionHash=$definitionHash;Enabled=($task.Settings.Enabled-ne$false);MentionsService=($xml-match[regex]::Escape($ServiceName));RepairOrUpdate=($task.TaskName-match'(?i)repair|update' -or $xml-match'(?i)repair|update')}
        }
    }
    @($items)
}
function Get-Identity{
    $matches=@(Get-CimInstance Win32_Service|Where-Object{$_.DisplayName-match'(?i)^HP One Agent Service$'})
    if($matches.Count-ne1){return $null}
    $service=$matches[0];$exe=Resolve-ServiceExecutable $service.PathName
    if(!$exe -or !(Test-Path -LiteralPath $exe -PathType Leaf) -or $exe-notmatch'(?i)\\HP\\.*One.?Agent.*\.exe$'){return $null}
    $file=Get-Item -LiteralPath $exe;$signature=Get-AuthenticodeSignature -LiteralPath $exe;$publisher=if($signature.SignerCertificate){$signature.SignerCertificate.Subject}else{$null}
    try{$version=[version]$file.VersionInfo.FileVersion}catch{return $null}
    $key="HKLM:\SYSTEM\CurrentControlSet\Services\$($service.Name)";$delayed=(Get-ItemProperty -LiteralPath $key -Name DelayedAutoStart -ErrorAction SilentlyContinue).DelayedAutoStart
    $dependencies=@($service.Dependencies);$dependents=@((Get-Service $service.Name).DependentServices|ForEach-Object{$_.Name})
    $failure=(& sc.exe qfailure $service.Name 2>&1|Out-String).Trim();$triggers=(& sc.exe qtriggerinfo $service.Name 2>&1|Out-String).Trim();$tasks=Get-OneAgentTasks $service.Name;$packages=Get-PackageInventory $exe
    [pscustomobject]@{
        Name=$service.Name;DisplayName=$service.DisplayName;State=$service.State;StartMode=$service.StartMode;DelayedAutoStart=[int]($null-ne$delayed-and[int]$delayed-ne0);PathName=$service.PathName;ServiceAccount=$service.StartName
        Dependencies=@($dependencies);Dependents=@($dependents);RecoveryActions=$failure;Triggers=$triggers;Tasks=@($tasks);Packages=@($packages)
        Executable=[ordered]@{Path=$file.FullName;Sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash;FileVersion=$file.VersionInfo.FileVersion;ParsedVersion=$version.ToString();ProductName=$file.VersionInfo.ProductName;CompanyName=$file.VersionInfo.CompanyName;SignatureStatus=$signature.Status.ToString();Publisher=$publisher;Thumbprint=if($signature.SignerCertificate){$signature.SignerCertificate.Thumbprint}else{$null};ValidPublisher=($signature.Status-eq'Valid'-and$publisher-match'(?i)HP Inc|Hewlett-Packard');SecurityFloorMet=($version-ge$minimumSafeVersion)}
    }
}
function Assert-Eligible($Support,$Identity){
    if(!$Support.Supported){throw 'Elevated HP Windows 11 is required.'}
    if($Support.Managed){throw 'Enterprise-management ownership detected.'}
    if($null-eq$Identity){throw 'Exactly one verified HP One Agent Service identity is required.'}
    if(!$Identity.Executable.ValidPublisher){throw 'Valid HP publisher signature is required.'}
    if(!$Identity.Executable.SecurityFloorMet){throw "HP One Agent must be version $minimumSafeVersion or later before experimentation."}
    if($Identity.StartMode-notin @('Auto','Automatic')){throw 'Baseline startup mode must be Automatic.'}
    if($Identity.DelayedAutoStart-ne0){throw 'Service is already delayed.'}
    if($Identity.Dependencies-match$protected -or $Identity.Dependents-match$protected){throw 'Protected dependency detected.'}
    if($Identity.RecoveryActions-match'(?im)^\s*REBOOT_MESSAGE\s*:\s*\S+' -or $Identity.RecoveryActions-match'(?im)^\s*COMMAND_LINE\s*:\s*\S+'){throw 'Recovery-sensitive configuration detected.'}
    if(@($Identity.Tasks|Where-Object{$_.RepairOrUpdate-and$_.Enabled}).Count-gt0){throw 'Enabled HP One Agent repair/update task may overwrite treatment; application refused.'}
    if($Identity.Packages.Count-lt1){throw 'HP One Agent package/product ownership could not be established.'}
}
function Save-State($Support,$Identity){
    Assert-Eligible $Support $Identity
    if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'}
    $protectedState=Get-ProtectedSnapshot;$taskJson=@($Identity.Tasks)|ConvertTo-Json -Compress -Depth 8;$depJson=[ordered]@{Dependencies=@($Identity.Dependencies);Dependents=@($Identity.Dependents)}|ConvertTo-Json -Compress -Depth 8
    $state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;securityBulletin=[ordered]@{Reference='HPSBHF04060 Rev. 1';MinimumVersion=$minimumSafeVersion.ToString();CheckedUtc=(Get-Date).ToUniversalTime().ToString('o')};protectedScopeHash=$protectedState.Hash;dependencyHash=Get-TextHash $depJson;taskHash=Get-TextHash $taskJson;service=$Identity}
    $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$state|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $StatePath -Encoding UTF8;$state
}
function Read-State{
    if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'}
    $state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if($state.schemaVersion-ne1-or$state.experiment-ne$experiment-or$state.provider-ne$provider-or$state.machine-ne$env:COMPUTERNAME-or$state.userSid-ne$sid){throw 'State identity validation failed.'};$state
}
function Assert-Identity($State){
    $current=Get-Identity;if($null-eq$current){throw 'HP One Agent identity drift detected.'}
    if($current.Name-ne[string]$State.service.Name-or$current.PathName-ne[string]$State.service.PathName-or$current.Executable.Sha256-ne[string]$State.service.Executable.Sha256-or$current.Executable.Thumbprint-ne[string]$State.service.Executable.Thumbprint-or$current.Executable.ParsedVersion-ne[string]$State.service.Executable.ParsedVersion){throw 'Service, executable, or version drift detected.'}
    $depJson=[ordered]@{Dependencies=@($current.Dependencies);Dependents=@($current.Dependents)}|ConvertTo-Json -Compress -Depth 8;if((Get-TextHash $depJson)-ne[string]$State.dependencyHash){throw 'Dependency drift detected.'}
    $taskJson=@($current.Tasks)|ConvertTo-Json -Compress -Depth 8;if((Get-TextHash $taskJson)-ne[string]$State.taskHash){throw 'HP One Agent repair/update task drift detected.'};$current
}
function Set-DelayedStart([string]$Name,[bool]$Delayed){
    $start=if($Delayed){'delayed-auto'}else{'auto'}
    $output=& sc.exe config $Name start= $start 2>&1
    if($LASTEXITCODE-ne0){throw "sc.exe configuration failed: $($output|Out-String)"}
}

try{
    $support=Get-SupportState;Write-StructuredLog 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
    switch($Action){
        'Check'{$identity=Get-Identity;Write-StructuredLog 'service-inventory' 'pass' @{found=[bool]$identity;service=if($identity){$identity.Name}else{$null};version=if($identity){$identity.Executable.ParsedVersion}else{$null};securityFloor=if($identity){$identity.Executable.SecurityFloorMet}else{$false};tasks=if($identity){$identity.Tasks}else{@()}};[pscustomobject]@{Support=$support;Service=$identity;Profile=$profile}}
        'Capture'{$state=Save-State $support (Get-Identity);Write-StructuredLog 'capture' 'pass' @{service=$state.service.Name;startMode=$state.service.StartMode;delayed=$state.service.DelayedAutoStart;version=$state.service.Executable.ParsedVersion;tasks=$state.service.Tasks};$state}
        'DryRun'{$identity=Get-Identity;Assert-Eligible $support $identity;$result=[pscustomobject]@{Profile=$profile;WouldChange=$true;MutationCount=1;Service=$identity.Name;From='Automatic';To='AutomaticDelayedStart';PreserveRunningState=$true;MinimumSafeVersion=$minimumSafeVersion.ToString();RebootPersistenceCheckRequired=$true;Rollback='Restore exact captured startup timing and running state.'};Write-StructuredLog 'dry-run' 'pass' $result;$result}
        'Apply'{$state=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $support (Get-Identity)};$identity=Assert-Identity $state;if($identity.StartMode-in @('Auto','Automatic')-and$identity.DelayedAutoStart-eq1){Write-StructuredLog 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};Assert-Eligible $support $identity;if((Get-ProtectedSnapshot).Hash-ne[string]$state.protectedScopeHash){throw 'Protected-scope drift detected.'};$running=$identity.State;if($WhatIfPreference){Write-StructuredLog 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess($identity.Name,'Set Automatic Delayed Start while preserving running state')){Set-DelayedStart $identity.Name $true};$after=Assert-Identity $state;if($after.StartMode-notin @('Auto','Automatic')-or$after.DelayedAutoStart-ne1-or$after.State-ne$running){throw 'Apply verification failed or running state changed.'};Write-StructuredLog 'apply' 'pass' @{mutationCount=1;runningStatePreserved=$true};[pscustomobject]@{Applied=$true;MutationCount=1}}
        'Verify'{$state=Read-State;$identity=Assert-Identity $state;if($identity.StartMode-notin @('Auto','Automatic')-or$identity.DelayedAutoStart-ne1){throw 'Immediate verification failed.'};Write-StructuredLog 'verify' 'pass' @{service=$identity.Name;state=$identity.State;startMode=$identity.StartMode;delayed=$identity.DelayedAutoStart};$true}
        'VerifyReboot'{$state=Read-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$state.capturedBootTime){throw 'A later boot is required.'};$identity=Assert-Identity $state;if($identity.StartMode-notin @('Auto','Automatic')-or$identity.DelayedAutoStart-ne1-or$identity.State-ne'Running'){throw 'Reboot persistence or delayed service health verification failed.'};Write-StructuredLog 'verify-reboot' 'pass' @{bootTime=$boot.ToString('o');service=$identity.Name;state=$identity.State};$true}
        'Rollback'{$state=Read-State;$identity=Assert-Identity $state;if($support.Managed){throw 'Management ownership appeared after capture.'};if((Get-ProtectedSnapshot).Hash-ne[string]$state.protectedScopeHash){throw 'Protected-scope drift detected.'};if($identity.DelayedAutoStart-eq[int]$state.service.DelayedAutoStart-and$identity.StartMode-in @('Auto','Automatic')-and$identity.State-eq[string]$state.service.State){Write-StructuredLog 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};if($identity.StartMode-notin @('Auto','Automatic')-or$identity.DelayedAutoStart-ne1){throw 'Rollback configuration drift detected.'};if($WhatIfPreference){Write-StructuredLog 'rollback' 'whatif' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess($identity.Name,'Restore captured startup timing and running state')){Set-DelayedStart $identity.Name ([int]$state.service.DelayedAutoStart-ne0);$service=Get-Service $identity.Name;if([string]$state.service.State-eq'Running'-and$service.Status-ne'Running'){Start-Service $identity.Name};if([string]$state.service.State-eq'Stopped'-and$service.Status-ne'Stopped'){Stop-Service $identity.Name}};$restored=Assert-Identity $state;if($restored.DelayedAutoStart-ne[int]$state.service.DelayedAutoStart-or$restored.StartMode-notin @('Auto','Automatic')-or$restored.State-ne[string]$state.service.State){throw 'Rollback verification failed.'};Write-StructuredLog 'rollback' 'pass' @{mutationCount=1;startMode=$restored.StartMode;delayed=$restored.DelayedAutoStart;state=$restored.State};[pscustomobject]@{RolledBack=$true;MutationCount=1}}
    }
}catch{Write-StructuredLog 'failure' 'failed' @{type=$_.Exception.GetType().FullName;message=$_.Exception.Message;stack=$_.ScriptStackTrace};throw}

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-124'
$provider='microsoft-365-run-demand-launch'
$profile='Microsoft365RunDemandLaunch'
$runPaths=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run')
$allRunPaths=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce')
$protected='(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|defender|securityhealth|firewall|bitlocker|credential|windows update|wuauserv|usosvc|bits|recovery|intune|sccm|configmgr|mdm|driver|firmware|accessibility'
$servicing='(?i)click.?to.?run|officeclicktorun|officec2rclient|integratedoffice|update|updater|servic|repair|activation|licens|setup|install|bootstrap|telemetry|ose\.exe|sppsvc'
$officeHint='(?i)microsoft office|office16|outlook|winword|word|excel|powerpnt|powerpoint|onenote|msaccess|access|microsoft 365'

function Write-Log([string]$Event,[string]$Result,[object]$Data){
    if([string]::IsNullOrWhiteSpace($LogPath)){return}
    $parent=Split-Path -Parent $LogPath
    if($parent -and !(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 20|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Hash([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$sha.Dispose()}}
function Test-Elevated{([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-ManagementState{
    $c=Get-CimInstance Win32_ComputerSystem
    $signals=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);Intune=[bool](Get-Service IntuneManagementExtension -ErrorAction SilentlyContinue);RunPolicy=(Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')}
    [pscustomobject]@{Managed=($signals.DomainJoined-or$signals.MdmEnrollments-gt0-or$signals.PolicyManager-or$signals.ConfigMgr-or$signals.Intune-or$signals.RunPolicy);Signals=$signals}
}
function Get-SupportState{
    $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem;$m=Get-ManagementState
    [pscustomobject]@{Supported=($o.Caption-match'Windows 11'-and$c.Manufacturer-match'(?i)^HP$|Hewlett-Packard');OS=$o.Caption;Build=$o.BuildNumber;Manufacturer=$c.Manufacturer;Model=$c.Model;Elevated=Test-Elevated;Managed=$m.Managed;ManagementSignals=$m.Signals}
}
function Get-ProtectedSnapshot{
    $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','ClickToRunSvc','Tailscale'){if($x=Get-Service $n -ErrorAction SilentlyContinue){[ordered]@{Name=$x.Name;Status=$x.Status.ToString();StartType=$x.StartType.ToString()}}}
    $processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp'}|ForEach-Object{$_.ProcessName}|Sort-Object -Unique)
    $json=[ordered]@{Services=@($services);Processes=$processes}|ConvertTo-Json -Compress -Depth 8
    [pscustomobject]@{Hash=Get-Hash $json;Snapshot=$json}
}
function Resolve-Command([string]$Command){
    $expanded=[Environment]::ExpandEnvironmentVariables($Command).Trim();if($expanded-match$protected-or$expanded-match$servicing){return $null}
    if($expanded-match'^\s*"(?<exe>[^"]+\.exe)"\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}elseif($expanded-match'^\s*(?<exe>\S+\.exe)\s*(?<args>.*)$'){$exe=$matches.exe;$args=$matches.args}else{return $null}
    try{$full=[IO.Path]::GetFullPath($exe)}catch{return $null}
    if($full-notmatch'(?i)\\Microsoft Office\\root\\Office16\\|\\Microsoft Office\\Office16\\'){return $null}
    [pscustomobject]@{ExpandedCommand=$expanded;Executable=$full;Arguments=$args.Trim()}
}
function Get-FileIdentity([string]$Path){
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){return $null};$f=Get-Item -LiteralPath $Path;$sig=Get-AuthenticodeSignature -LiteralPath $Path;$pub=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
    [pscustomobject]@{Path=$f.FullName;Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash;FileVersion=$f.VersionInfo.FileVersion;ProductName=$f.VersionInfo.ProductName;CompanyName=$f.VersionInfo.CompanyName;SignatureStatus=$sig.Status.ToString();Publisher=$pub;Thumbprint=if($sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};ValidPublisher=($sig.Status-eq'Valid'-and$pub-match'(?i)Microsoft Corporation')}
}
function Test-OfficeUserApp($Resolved,$Identity){
    $leaf=[IO.Path]::GetFileName([string]$Resolved.Executable)
    if($leaf-notmatch'(?i)^(OUTLOOK|WINWORD|EXCEL|POWERPNT|ONENOTE|MSACCESS)\.EXE$'){return $false}
    if(("$leaf $($Identity.ProductName) $($Identity.CompanyName) $($Resolved.Arguments)")-match$servicing){return $false}
    ($Identity.ProductName+' '+$Identity.CompanyName)-match'(?i)Microsoft.*(Office|Outlook|Excel|Word|PowerPoint|OneNote|Access)'
}
function Get-Candidates{
    $out=@()
    foreach($path in $runPaths){
        if(!(Test-Path -LiteralPath $path)){continue};$key=Get-Item -LiteralPath $path;$acl=Get-Acl -LiteralPath $path
        foreach($name in $key.GetValueNames()){
            $data=[string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if("$name $data"-match$protected-or"$name $data"-match$servicing){continue}
            $resolved=Resolve-Command $data;if(!$resolved){continue};$file=Get-FileIdentity $resolved.Executable
            if(!$file-or!$file.ValidPublisher-or!(Test-OfficeUserApp $resolved $file)){continue}
            $out+=[pscustomobject]@{Path=$path;Hive=if($path-like'HKLM:*'){'HKLM'}else{'HKCU'};Name=$name;Kind=$key.GetValueKind($name).ToString();Data=$data;ExpandedCommand=$resolved.ExpandedCommand;Arguments=$resolved.Arguments;Executable=$file;Product=[ordered]@{Name=$file.ProductName;Version=$file.FileVersion;Company=$file.CompanyName};KeyOwner=$acl.Owner;KeySddl=$acl.Sddl}
        }
    }
    @($out)
}
function Get-RelatedStartupInventory([string]$ExcludePath,[string]$ExcludeName){
    $registry=@()
    foreach($path in $allRunPaths){if(Test-Path -LiteralPath $path){$k=Get-Item -LiteralPath $path;foreach($n in $k.GetValueNames()|Sort-Object){if($path-eq$ExcludePath-and$n-eq$ExcludeName){continue};$d=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if("$n $d"-match$officeHint){$registry+=[ordered]@{Path=$path;Name=$n;Kind=$k.GetValueKind($n).ToString();Data=$d}}}}}
    $folders=@([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup),[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartup))|Where-Object{$_}|Sort-Object -Unique
    $startup=@();foreach($folder in $folders){if(Test-Path -LiteralPath $folder){$startup+=@(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue|Where-Object{$_.Name-match$officeHint}|Sort-Object FullName|ForEach-Object{[ordered]@{Path=$_.FullName;Length=$_.Length;LastWriteTimeUtc=$_.LastWriteTimeUtc.ToString('o')}})}}
    $tasks=@(Get-ScheduledTask -ErrorAction SilentlyContinue|ForEach-Object{$t=$_;$acts=@($t.Actions|ForEach-Object{"$($_.Execute) $($_.Arguments)"});if(($acts-join' ') -match$officeHint){[ordered]@{TaskPath=$t.TaskPath;TaskName=$t.TaskName;Enabled=[bool]$t.Settings.Enabled;Actions=$acts}}}|Sort-Object TaskPath,TaskName)
    $json=[ordered]@{Registry=$registry;StartupFolder=$startup;ScheduledTasks=$tasks}|ConvertTo-Json -Compress -Depth 10
    [pscustomobject]@{Hash=Get-Hash $json;Snapshot=$json}
}
function Assert-Eligible($Support,[object[]]$Candidates){
    if(!$Support.Supported){throw 'HP Windows 11 is required.'};if($Support.Managed){throw 'Enterprise-management ownership detected.'};if($Candidates.Count-ne1){throw "Exactly one eligible Microsoft 365 Run registration is required; found $($Candidates.Count)."};if($Candidates[0].Hive-eq'HKLM'-and!$Support.Elevated){throw 'Elevation is required for HKLM Run.'}
}
function Save-State($Support,[object[]]$Candidates){
    Assert-Eligible $Support $Candidates;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$p=Get-ProtectedSnapshot;$entry=$Candidates[0];$related=Get-RelatedStartupInventory $entry.Path $entry.Name
    $state=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;protectedScopeHash=$p.Hash;relatedStartupHash=$related.Hash;relatedStartupInventory=$related.Snapshot;entry=$entry}
    $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$state|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $StatePath -Encoding UTF8;$state
}
function Read-State{if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion-ne1-or$s.experiment-ne$experiment-or$s.provider-ne$provider-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne$sid){throw 'State identity validation failed.'};$s}
function Test-Removed($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $true};!((Get-Item -LiteralPath $State.entry.Path).GetValueNames()-contains[string]$State.entry.Name)}
function Test-Restored($State){if(!(Test-Path -LiteralPath $State.entry.Path)){return $false};$k=Get-Item -LiteralPath $State.entry.Path;if(!($k.GetValueNames()-contains[string]$State.entry.Name)){return $false};$data=[string]$k.GetValue([string]$State.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$data-eq[string]$State.entry.Data-and$k.GetValueKind([string]$State.entry.Name).ToString()-eq[string]$State.entry.Kind}
function Assert-Executable($State){$f=Get-FileIdentity ([string]$State.entry.Executable.Path);if(!$f-or!$f.ValidPublisher-or$f.Sha256-ne[string]$State.entry.Executable.Sha256-or$f.Thumbprint-ne[string]$State.entry.Executable.Thumbprint-or$f.FileVersion-ne[string]$State.entry.Executable.FileVersion){throw 'Microsoft 365 executable identity drift detected.'};$r=[pscustomobject]@{Executable=$f.Path;Arguments=[string]$State.entry.Arguments};if(!(Test-OfficeUserApp $r $f)){throw 'Microsoft 365 product identity drift detected.'}}
function Assert-Ownership($State){if(!(Test-Path -LiteralPath ([string]$State.entry.Path))){throw 'Run key missing during ownership check.'};$acl=Get-Acl -LiteralPath ([string]$State.entry.Path);if($acl.Owner-ne[string]$State.entry.KeyOwner-or$acl.Sddl-ne[string]$State.entry.KeySddl){throw 'Run key ownership or ACL drift detected.'}}
function Assert-UnrelatedStartup($State){$r=Get-RelatedStartupInventory ([string]$State.entry.Path) ([string]$State.entry.Name);if($r.Hash-ne[string]$State.relatedStartupHash){throw 'Related Microsoft 365 startup-registration drift detected.'}}

try{
    $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) @{OS=$support.OS;Build=$support.Build;Manufacturer=$support.Manufacturer;Managed=$support.Managed;Elevated=$support.Elevated}
    switch($Action){
        'Check'{$c=Get-Candidates;Write-Log 'candidate-inventory' 'pass' @{count=$c.Count;names=@($c.Name);products=@($c.Product.Name)};[pscustomobject]@{Support=$support;Candidates=$c;Profile=$profile}}
        'Capture'{$s=Save-State $support (Get-Candidates);Write-Log 'capture' 'pass' @{before=@{path=$s.entry.Path;name=$s.entry.Name;kind=$s.entry.Kind;data=$s.entry.Data};product=$s.entry.Product;exeSha256=$s.entry.Executable.Sha256;relatedStartupHash=$s.relatedStartupHash};$s}
        'DryRun'{$c=Get-Candidates;Assert-Eligible $support $c;$r=[pscustomobject]@{Profile=$profile;WouldChange=$true;MutationCount=1;Path=$c[0].Path;Name=$c[0].Name;Product=$c[0].Product.Name;Before=@{Present=$true;Kind=$c[0].Kind;Data=$c[0].Data};After=@{Present=$false};PreserveMicrosoft365=$true;PreserveClickToRun=$true;PreserveActivation=$true;PreserveUpdates=$true;PreserveDocuments=$true;PreserveAddins=$true;PreserveRunOnce=$true;RebootPersistenceCheckRequired=$true;Rollback='Restore the exact captured registry value name, type, and unexpanded data after drift checks.'};Write-Log 'dry-run' 'pass' $r;$r}
        'Apply'{$s=if($StatePath-and(Test-Path -LiteralPath $StatePath)){Read-State}else{Save-State $support (Get-Candidates)};$m=Get-ManagementState;if($m.Managed){throw 'Enterprise-management ownership detected.'};Assert-Executable $s;Assert-Ownership $s;Assert-UnrelatedStartup $s;if((Get-ProtectedSnapshot).Hash-ne[string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if(Test-Removed $s){Write-Log 'apply' 'idempotent' @{before=@{Present=$false};after=@{Present=$false};mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};$k=Get-Item -LiteralPath ([string]$s.entry.Path);$data=[string]$k.GetValue([string]$s.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if($data-ne[string]$s.entry.Data-or$k.GetValueKind([string]$s.entry.Name).ToString()-ne[string]$s.entry.Kind){throw 'Run registration drift detected.'};if($WhatIfPreference){Write-Log 'apply' 'whatif' @{before=@{Present=$true;Kind=$s.entry.Kind;Data=$s.entry.Data};after=@{Present=$true};mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Remove exact Microsoft 365 Run registration')){Remove-ItemProperty -LiteralPath ([string]$s.entry.Path) -Name ([string]$s.entry.Name)};if(!(Test-Removed $s)){throw 'Apply verification failed.'};Assert-UnrelatedStartup $s;Write-Log 'apply' 'pass' @{before=@{Present=$true;Kind=$s.entry.Kind;Data=$s.entry.Data};after=@{Present=$false};mutationCount=1;physicalMeasurements='needs-evidence'};[pscustomobject]@{Applied=$true;MutationCount=1;NeedsEvidence='Matched cold boots, Microsoft 365 readiness, servicing checks, and protected-application readiness'}}
        'Verify'{$s=Read-State;if(!(Test-Removed $s)){throw 'Immediate verification failed.'};Assert-Executable $s;Assert-UnrelatedStartup $s;Write-Log 'verify' 'pass' @{before=@{Present=$true};after=@{Present=$false};physicalMeasurements='needs-evidence'};$true}
        'VerifyReboot'{$s=Read-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$s.capturedBootTime){throw 'A later boot is required.'};if(!(Test-Removed $s)){throw 'Reboot persistence failed.'};Assert-Executable $s;Assert-UnrelatedStartup $s;Write-Log 'verify-reboot' 'pass' @{before=@{Present=$true};after=@{Present=$false};bootTime=$boot.ToString('o');physicalMeasurements='needs-evidence'};$true}
        'Rollback'{$s=Read-State;$m=Get-ManagementState;if($m.Managed){throw 'Enterprise-management ownership appeared.'};Assert-Executable $s;Assert-Ownership $s;Assert-UnrelatedStartup $s;if((Get-ProtectedSnapshot).Hash-ne[string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};if(!(Test-Removed $s)){if(Test-Restored $s){Write-Log 'rollback' 'idempotent' @{before=@{Present=$true};after=@{Present=$true;Kind=$s.entry.Kind;Data=$s.entry.Data};mutationCount=0;restoredExactOriginal=$true};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};throw 'Rollback overwrite refused.'};if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{before=@{Present=$false};after=@{Present=$false};mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if($PSCmdlet.ShouldProcess("$($s.entry.Path)::$($s.entry.Name)",'Restore exact Microsoft 365 Run registration')){(Get-Item -LiteralPath ([string]$s.entry.Path)).SetValue([string]$s.entry.Name,[string]$s.entry.Data,[Microsoft.Win32.RegistryValueKind]::$($s.entry.Kind))};if(!(Test-Restored $s)){throw 'Exact rollback verification failed.'};Assert-UnrelatedStartup $s;Write-Log 'rollback' 'pass' @{before=@{Present=$false};after=@{Present=$true;Kind=$s.entry.Kind;Data=$s.entry.Data};mutationCount=1;restoredExactOriginal=$true;postRollbackBoot='needs-evidence'};[pscustomobject]@{RolledBack=$true;MutationCount=1;NeedsEvidence='Controlled post-rollback reboot and Microsoft 365/protected-application checks'}}
    }
}catch{Write-Log 'failure' 'fail' @{stage=$Action;refusalReason=$_.Exception.Message;message=$_.Exception.Message;type=$_.Exception.GetType().FullName;stack=$_.ScriptStackTrace};throw}

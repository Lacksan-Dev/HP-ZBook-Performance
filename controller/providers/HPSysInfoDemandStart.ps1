[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')][string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-065'
$provider='hp-system-info-demand-start'
$profile='HPSysInfoDemandStart'
$serviceName='HPSysInfoCap'
$serviceKey="HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"
$protected='(?i)omnissa|horizon|vmware|windows app|remote desktop|mstsc|tailscale|defender|securityhealth|firewall|bitlocker|credential|windows update|wuauserv|usosvc|bits|recovery|intune|sccm|configmgr|mdm|vpn|ndis|network|accessibility|driver|firmware'

function Write-Log([string]$Event,[string]$Result,[object]$Data){
    if([string]::IsNullOrWhiteSpace($LogPath)){return}
    $parent=Split-Path -Parent $LogPath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
    [ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$experiment;provider=$provider;action=$Action;event=$Event;result=$Result;machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}|ConvertTo-Json -Compress -Depth 24|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Hash([string]$Text){$sha=[Security.Cryptography.SHA256]::Create();try{($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))|ForEach-Object{$_.ToString('x2')})-join''}finally{$sha.Dispose()}}
function Normalize-StartMode([string]$Mode){if($Mode-in @('Auto','Automatic')){'Automatic'}else{$Mode}}
function Test-Elevated{([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-ManagementState{
    $c=Get-CimInstance Win32_ComputerSystem
    $x=[ordered]@{DomainJoined=[bool]$c.PartOfDomain;MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count;PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device';ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);Intune=[bool](Get-Service IntuneManagementExtension -ErrorAction SilentlyContinue);ServicePolicy=Test-Path "HKLM:\SOFTWARE\Policies\Lacksan\Services\$serviceName"}
    [pscustomobject]@{Managed=($x.DomainJoined-or$x.MdmEnrollments-gt0-or$x.PolicyManager-or$x.ConfigMgr-or$x.Intune-or$x.ServicePolicy);Signals=$x}
}
function Get-SupportState{
    $o=Get-CimInstance Win32_OperatingSystem;$c=Get-CimInstance Win32_ComputerSystem;$b=Get-CimInstance Win32_BIOS;$m=Get-ManagementState
    [pscustomobject]@{Supported=($o.Caption-match'Windows 11'-and$c.Manufacturer-match'(?i)^HP$|Hewlett-Packard'-and(Test-Elevated));Elevated=Test-Elevated;OS=$o.Caption;Build=$o.BuildNumber;Manufacturer=$c.Manufacturer;Model=$c.Model;BIOS=$b.SMBIOSBIOSVersion;Managed=$m.Managed;ManagementSignals=$m.Signals}
}
function Get-ProtectedSnapshot{
    $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){if($s=Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue){[ordered]@{Name=$s.Name;State=$s.State;StartMode=$s.StartMode;PathName=$s.PathName}}}
    $processes=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale'}|Select-Object -ExpandProperty ProcessName|Sort-Object -Unique)
    $text=[ordered]@{Services=@($services);Processes=$processes}|ConvertTo-Json -Compress -Depth 8;[pscustomobject]@{Hash=Get-Hash $text;Snapshot=$text}
}
function Get-DelayedState{
    if(!(Test-Path -LiteralPath $serviceKey)){throw 'Service registry key is missing.'};$k=Get-Item -LiteralPath $serviceKey;$exists=$k.GetValueNames()-contains'DelayedAutoStart'
    if(!$exists){return [pscustomobject]@{Exists=$false;Kind=$null;Data=$null}}
    [pscustomobject]@{Exists=$true;Kind=$k.GetValueKind('DelayedAutoStart').ToString();Data=$k.GetValue('DelayedAutoStart',$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Resolve-Exe([string]$PathName){
    $expanded=[Environment]::ExpandEnvironmentVariables($PathName).Trim();if($expanded-match$protected){return $null}
    if($expanded-match'^\s*"(?<exe>[^"]+\.exe)"'){$path=$matches.exe}elseif($expanded-match'^\s*(?<exe>\S+\.exe)'){$path=$matches.exe}else{return $null}
    try{$full=[IO.Path]::GetFullPath($path)}catch{return $null};if($full-match'(?i)\\DriverStore\\|\\System32\\drivers\\'){return $null};$full
}
function Get-PackageInventory([string]$Executable){
    $parent=Split-Path -Parent $Executable;$items=@();foreach($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'){
        Get-ChildItem $root -ErrorAction SilentlyContinue|ForEach-Object{$p=Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue;if($p.Publisher-match'(?i)HP|Hewlett-Packard' -and (($p.DisplayName-match'(?i)System Info|System Information|HSA') -or ($p.InstallLocation -and $parent.StartsWith([string]$p.InstallLocation,[StringComparison]::OrdinalIgnoreCase)))){$items+=[pscustomobject]@{Key=$_.PSChildName;DisplayName=$p.DisplayName;DisplayVersion=$p.DisplayVersion;Publisher=$p.Publisher;InstallLocationHash=if($p.InstallLocation){Get-Hash ([string]$p.InstallLocation)}else{$null}}}}
    };@($items)
}
function Get-PnpEvidence{
    @((Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue|Where-Object{$_.DriverProviderName-match'(?i)^HP|Hewlett-Packard' -and ($_.DeviceName-match'(?i)System Info|HSA' -or $_.InfName-match'(?i)sysinfo|hsa')}|Select-Object DeviceName,DeviceID,DriverProviderName,DriverVersion,InfName,IsSigned))
}
function Get-RelatedService([string]$Name){$s=Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue;if(!$s){return $null};[pscustomobject]@{Name=$s.Name;DisplayName=$s.DisplayName;PathName=$s.PathName;State=$s.State;StartMode=$s.StartMode}}
function Get-Identity{
    $all=@(Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue);if($all.Count-ne1){return $null};$s=$all[0]
    if($s.DisplayName-notmatch'(?i)^HP System Info HSA Service$'){return $null};$exe=Resolve-Exe $s.PathName;if(!$exe-or!(Test-Path -LiteralPath $exe -PathType Leaf)-or$exe-notmatch'(?i)\\(HP|Hewlett-Packard)\\.*SysInfoCap\.exe$'){return $null}
    $f=Get-Item -LiteralPath $exe;$sig=Get-AuthenticodeSignature -LiteralPath $exe;$pub=if($sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null};$deps=@($s.Dependencies);$dependents=@((Get-Service $serviceName).DependentServices|ForEach-Object{$_.Name});$related=@($deps+$dependents|Sort-Object -Unique|ForEach-Object{Get-RelatedService $_}|Where-Object{$_})
    [pscustomobject]@{Name=$s.Name;DisplayName=$s.DisplayName;State=$s.State;StartMode=$s.StartMode;DelayedAutoStart=Get-DelayedState;PathName=$s.PathName;ServiceAccount=$s.StartName;Dependencies=$deps;Dependents=$dependents;RelatedServices=$related;Packages=Get-PackageInventory $exe;PnpEvidence=Get-PnpEvidence;Executable=[pscustomobject]@{Path=$f.FullName;Sha256=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash;FileVersion=$f.VersionInfo.FileVersion;ProductName=$f.VersionInfo.ProductName;CompanyName=$f.VersionInfo.CompanyName;SignatureStatus=$sig.Status.ToString();Publisher=$pub;Thumbprint=if($sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};ValidPublisher=($sig.Status-eq'Valid'-and$pub-match'(?i)HP Inc|Hewlett-Packard')}}}
}
function Assert-Eligible($Support,$Identity){
    if(!$Support.Supported){throw 'Elevated HP Windows 11 is required.'};if($Support.Managed){throw 'Enterprise-management ownership detected.'};if($null-eq$Identity){throw 'Exactly one verified HPSysInfoCap identity is required.'};if(!$Identity.Executable.ValidPublisher){throw 'Valid HP publisher signature is required.'};if((Normalize-StartMode $Identity.StartMode)-ne'Automatic'){throw 'Baseline startup mode must be Automatic.'};if($Identity.Dependents.Count-gt0){throw 'Dependent service evidence requires physical validation before mutation.'};if(@($Identity.RelatedServices|Where-Object{"$($_.Name) $($_.DisplayName) $($_.PathName)"-match$protected}).Count-gt0){throw 'Protected dependency detected.'};if($Identity.Packages.Count-ne1){throw 'Exactly one associated HP System Info package identity is required.'};if($Identity.PnpEvidence.Count-gt0){throw 'PnP or driver association detected; service-only mutation refused.'}
}
function Save-State($Support,$Identity){
    Assert-Eligible $Support $Identity;if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'};if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused.'};$p=Get-ProtectedSnapshot;$dep=@($Identity.RelatedServices)|ConvertTo-Json -Compress -Depth 8;$pkg=@($Identity.Packages)|ConvertTo-Json -Compress -Depth 8
    $s=[ordered]@{schemaVersion=1;experiment=$experiment;provider=$provider;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;support=$Support;protectedScopeHash=$p.Hash;dependencyHash=Get-Hash $dep;packageHash=Get-Hash $pkg;service=$Identity}
    $parent=Split-Path -Parent $StatePath;if($parent-and!(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$s|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $StatePath -Encoding UTF8;$s
}
function Read-State{if([string]::IsNullOrWhiteSpace($StatePath)-or!(Test-Path -LiteralPath $StatePath)){throw 'State artifact is missing.'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion-ne1-or$s.experiment-ne$experiment-or$s.provider-ne$provider-or$s.machine-ne$env:COMPUTERNAME-or$s.userSid-ne$sid){throw 'State identity validation failed.'};$s}
function Assert-Identity($State){
    $i=Get-Identity;if($null-eq$i-or$i.PathName-ne[string]$State.service.PathName-or$i.Executable.Sha256-ne[string]$State.service.Executable.Sha256-or$i.Executable.Thumbprint-ne[string]$State.service.Executable.Thumbprint-or$i.Executable.FileVersion-ne[string]$State.service.Executable.FileVersion){throw 'Service or executable identity drift detected.'}
    if((Get-Hash (@($i.RelatedServices)|ConvertTo-Json -Compress -Depth 8))-ne[string]$State.dependencyHash){throw 'Dependency topology drift detected.'};if((Get-Hash (@($i.Packages)|ConvertTo-Json -Compress -Depth 8))-ne[string]$State.packageHash){throw 'Package identity drift detected.'};if($i.PnpEvidence.Count-gt0){throw 'PnP or driver association appeared.'};$i
}
function Restore-Delayed($State){if($State.Exists){(Get-Item -LiteralPath $serviceKey).SetValue('DelayedAutoStart',$State.Data,[Microsoft.Win32.RegistryValueKind]::$($State.Kind))}elseif((Get-Item -LiteralPath $serviceKey).GetValueNames()-contains'DelayedAutoStart'){Remove-ItemProperty -LiteralPath $serviceKey -Name DelayedAutoStart}}
function Test-DelayedEqual($A,$B){$A.Exists-eq$B.Exists-and((!$A.Exists)-or($A.Kind-eq[string]$B.Kind-and[string]$A.Data-eq[string]$B.Data))}

try{
    $support=Get-SupportState;Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
    switch($Action){
        'Check'{$i=Get-Identity;Write-Log 'service-inventory' 'pass' @{found=[bool]$i;service=if($i){$i.Name}else{$null};packages=if($i){$i.Packages.Count}else{0};pnp=if($i){$i.PnpEvidence.Count}else{0}};[pscustomobject]@{Support=$support;Service=$i;Profile=$profile}}
        'Capture'{$s=Save-State $support (Get-Identity);Write-Log 'capture' 'pass' @{service=$s.service.Name;startMode=$s.service.StartMode;delayed=$s.service.DelayedAutoStart;state=$s.service.State;package=$s.service.Packages};$s}
        'DryRun'{$i=Get-Identity;Assert-Eligible $support $i;$r=[pscustomobject]@{Profile=$profile;WouldChange=$true;MutationCount=1;Service=$serviceName;From=$i.StartMode;To='Manual';PreserveRunningState=$true;PreservePackage=$true;PreserveDrivers=$true;PreserveDevices=$true;RebootPersistenceCheckRequired=$true;Rollback='Restore exact captured startup mode, delayed-auto-start registry state, and original running state.'};Write-Log 'dry-run' 'pass' $r;$r}
        'Apply'{$s=if($StatePath-and(Test-Path -LiteralPath $StatePath)){Read-State}else{Save-State $support (Get-Identity)};$i=Assert-Identity $s;if($i.StartMode-eq'Manual'){Write-Log 'apply' 'idempotent' @{mutationCount=0};return [pscustomobject]@{Applied=$true;MutationCount=0}};Assert-Eligible $support $i;if((Get-ProtectedSnapshot).Hash-ne[string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};$running=$i.State;if($WhatIfPreference){Write-Log 'apply' 'whatif' @{mutationCount=0};return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}};if(!$PSCmdlet.ShouldProcess($serviceName,'Set verified HP System Info HSA Service startup type to Manual without stopping it')){Write-Log 'apply' 'declined' @{mutationCount=0};return [pscustomobject]@{Applied=$false;MutationCount=0}};Set-Service -Name $serviceName -StartupType Manual;$after=Assert-Identity $s;if($after.StartMode-ne'Manual'-or$after.State-ne$running){throw 'Apply verification failed or running state changed.'};Write-Log 'apply' 'pass' @{mutationCount=1;runningStatePreserved=$true;physicalMeasurements='needs-evidence'};[pscustomobject]@{Applied=$true;MutationCount=1;NeedsEvidence='HP demand-start behavior, protected-app readiness, and measured boot/sign-in trials'}}
        'Verify'{$s=Read-State;$i=Assert-Identity $s;if($i.StartMode-ne'Manual'){throw 'Immediate verification failed.'};Write-Log 'verify' 'pass' @{startMode=$i.StartMode;state=$i.State;physicalMeasurements='needs-evidence'};$true}
        'VerifyReboot'{$s=Read-State;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot-le[datetime]$s.capturedBootTime){throw 'A later boot is required.'};$i=Assert-Identity $s;if($i.StartMode-ne'Manual'){throw 'Reboot persistence failed.'};Write-Log 'verify-reboot' 'pass' @{bootTime=$boot.ToString('o');startMode=$i.StartMode;serviceState=$i.State;demandStart='needs-evidence'};$true}
        'Rollback'{$s=Read-State;$i=Assert-Identity $s;if($support.Managed){throw 'Management ownership appeared.'};if((Get-ProtectedSnapshot).Hash-ne[string]$s.protectedScopeHash){throw 'Protected-scope drift detected.'};$targetMode=Normalize-StartMode ([string]$s.service.StartMode);$targetDelayed=$s.service.DelayedAutoStart;if((Normalize-StartMode $i.StartMode)-eq$targetMode-and(Test-DelayedEqual $i.DelayedAutoStart $targetDelayed)-and$i.State-eq[string]$s.service.State){Write-Log 'rollback' 'idempotent' @{mutationCount=0};return [pscustomobject]@{RolledBack=$true;MutationCount=0}};if($i.StartMode-ne'Manual'){throw 'Rollback configuration drift detected.'};if($WhatIfPreference){Write-Log 'rollback' 'whatif' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}};if(!$PSCmdlet.ShouldProcess($serviceName,'Restore exact captured startup configuration and running state')){Write-Log 'rollback' 'declined' @{mutationCount=0};return [pscustomobject]@{RolledBack=$false;MutationCount=0}};Set-Service -Name $serviceName -StartupType $targetMode;Restore-Delayed $targetDelayed;$current=Get-Service $serviceName;if([string]$s.service.State-eq'Running'-and$current.Status-ne'Running'){Start-Service $serviceName}elseif([string]$s.service.State-eq'Stopped'-and$current.Status-ne'Stopped'){Stop-Service $serviceName};$restored=Assert-Identity $s;if((Normalize-StartMode $restored.StartMode)-ne$targetMode-or!(Test-DelayedEqual $restored.DelayedAutoStart $targetDelayed)-or$restored.State-ne[string]$s.service.State){throw 'Exact rollback verification failed.'};Write-Log 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true;functionalRetest='needs-evidence'};[pscustomobject]@{RolledBack=$true;MutationCount=1;NeedsEvidence='Post-rollback HP system-information and protected-application functional checks'}}
    }
}catch{Write-Log 'failure' 'fail' @{stage=$Action;type=$_.Exception.GetType().FullName;message=$_.Exception.Message;stack=$_.ScriptStackTrace};throw}

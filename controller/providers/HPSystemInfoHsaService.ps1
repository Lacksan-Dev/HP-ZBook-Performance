[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$serviceName='HPSysInfoCap'
$serviceReg="HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName"
$policyPaths=@(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\Services\$serviceName",
    "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\SystemServices\$serviceName"
)
$protectedPattern='(?i)defender|firewall|bitlocker|credential|vbs|security|update|recovery|accessibility|omnissa|vmware|windows app|remote desktop|termservice|tailscale|driver|network|vpn'

function Write-StructuredLog([string]$Event,[string]$Result,[object]$Data){
    if($LogPath){
        $parent=Split-Path -Parent $LogPath;if($parent){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
        $record=[ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-064';provider='hp-system-info-hsa-service';action=$Action;event=$Event;result=$Result;data=$Data}
        Add-Content -LiteralPath $LogPath -Value ($record|ConvertTo-Json -Compress -Depth 14) -Encoding UTF8
    }
}
function Get-ExecutablePath([string]$CommandLine){
    if([string]::IsNullOrWhiteSpace($CommandLine)){return $null}
    if($CommandLine -match '^\s*"([^"]+)"'){return $matches[1]}
    return (($CommandLine -split '\s+',2)[0]).Trim('"')
}
function Get-ManagementSignals{
    $signals=@();foreach($path in $policyPaths){if(Test-Path -LiteralPath $path){$signals+=$path}}
    [pscustomobject]@{PolicyPaths=@($signals);EnrollmentRegistryPresent=(Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Enrollments');Owned=(@($signals).Count -gt 0)}
}
function Get-PackageEvidence([string]$Executable){
    $drivers=@()
    if($Executable){
        $escaped=$Executable.Replace('\\','\\\\')
        $drivers=@(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue|Where-Object {$_.DriverProviderName -match '(?i)HP|Hewlett-Packard' -and ($_.InfName -or $_.DriverVersion)}|Select-Object DeviceName,InfName,DriverProviderName,DriverVersion)
    }
    [pscustomobject]@{AssociatedDriverMetadata=@($drivers);DriverMutationAuthorized=$false}
}
function Get-State{
    $svc=Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction Stop
    $delayed=0;if(Test-Path -LiteralPath $serviceReg){$v=Get-ItemProperty -LiteralPath $serviceReg -Name DelayedAutoStart -ErrorAction SilentlyContinue;if($null-ne$v){$delayed=[int]$v.DelayedAutoStart}}
    $exe=Get-ExecutablePath $svc.PathName
    $sig=if($exe-and(Test-Path -LiteralPath $exe)){Get-AuthenticodeSignature -LiteralPath $exe}else{$null}
    $hash=if($exe-and(Test-Path -LiteralPath $exe)){(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash}else{$null}
    [pscustomobject]@{
        Name=$svc.Name;DisplayName=$svc.DisplayName;PathName=$svc.PathName;ExecutablePath=$exe;ExecutableHash=$hash
        StartMode=$svc.StartMode;State=$svc.State;DelayedAutoStart=$delayed;StartName=$svc.StartName
        Dependencies=@($svc.Dependencies);DependentServices=@(Get-Service -Name $serviceName|ForEach-Object {$_.DependentServices.Name})
        ExecutableVersion=if($exe-and(Test-Path -LiteralPath $exe)){(Get-Item -LiteralPath $exe).VersionInfo.FileVersion}else{$null}
        SignatureStatus=if($sig){$sig.Status}else{$null};Signer=if($sig-and$sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null}
        ServiceType=$svc.ServiceType;PackageEvidence=Get-PackageEvidence $exe
    }
}
function Get-Support{
    $os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem
    $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $services=@(Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue);$svc=if($services.Count-eq 1){$services[0]}else{$null}
    $state=if($svc){Get-State}else{$null};$management=Get-ManagementSignals
    $identity=($state-and$state.DisplayName-match'(?i)HP System Info.*HSA|HP.*System Info'-and$state.ExecutablePath-match'(?i)SysInfoCap|HPSysInfo')
    $publisher=($state-and$state.SignatureStatus-eq'Valid'-and$state.Signer-match'(?i)HP Inc|Hewlett-Packard')
    $dependencySafe=($state-and@($state.Dependencies+$state.DependentServices|Where-Object{$_-match$protectedPattern}).Count-eq 0)
    $serviceTypeSafe=($state-and$state.ServiceType-notmatch'Kernel|File System')
    [pscustomobject]@{Supported=($os.Caption-match'Windows 11'-and$cs.Manufacturer-match'(?i)^HP$|Hewlett-Packard'-and$services.Count-eq 1-and$identity-and$publisher-and$dependencySafe-and$serviceTypeSafe-and-not$management.Owned);Elevated=$admin;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;ServiceCount=$services.Count;Service=$svc;IdentityMatched=$identity;PublisherMatched=$publisher;DependencySafe=$dependencySafe;ServiceTypeSafe=$serviceTypeSafe;Management=$management;State=$state}
}
function Save-State($State,$Support){
    if([string]::IsNullOrWhiteSpace($StatePath)){throw 'StatePath is required.'}
    $saved=[ordered]@{schemaVersion=1;experiment='EXP-064';provider='hp-system-info-hsa-service';machine=$env:COMPUTERNAME;capturedUtc=(Get-Date).ToUniversalTime().ToString('o');windowsBuild=$Support.Build;manufacturer=$Support.Manufacturer;model=$Support.Model;service=$State}
    $parent=Split-Path -Parent $StatePath;if($parent){New-Item -ItemType Directory -Path $parent -Force|Out-Null};$saved|ConvertTo-Json -Depth 14|Set-Content -LiteralPath $StatePath -Encoding UTF8;$saved
}
function Read-State{
    if([string]::IsNullOrWhiteSpace($StatePath)-or-not(Test-Path -LiteralPath $StatePath)){throw "State file missing: $StatePath"}
    $saved=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
    if($saved.schemaVersion-ne 1-or$saved.experiment-ne'EXP-064'-or$saved.provider-ne'hp-system-info-hsa-service'-or$saved.machine-ne$env:COMPUTERNAME-or$saved.service.Name-ne$serviceName){throw 'State identity validation failed.'};$saved
}
function Assert-Safe($Support,$State){
    if(-not$Support.Elevated){throw 'Elevation is required.'};if(-not$Support.Supported){throw 'Exact supported HP Windows 11 HP System Info HSA service identity is required.'}
    if($State.StartMode-ne'Auto'){throw 'Eligible start mode must be Automatic or Automatic Delayed Start.'};if($State.Dependencies.Count-gt 0-or$State.DependentServices.Count-gt 0){throw 'Service dependencies require physical review before mutation.'}
}
function Test-Applied{$s=Get-State;($s.StartMode-eq'Manual'-and$s.DelayedAutoStart-eq 0)}
function Assert-CurrentIdentityMatchesSaved($Saved,$Current){
    foreach($f in @('Name','DisplayName','PathName','ExecutablePath','ExecutableHash','StartName','ExecutableVersion','SignatureStatus','Signer','ServiceType')){if([string]$Current.$f-ne[string]$Saved.service.$f){throw "Rollback refused because service identity drifted: $f"}}
    if((@($Current.Dependencies)-join'|')-ne(@($Saved.service.Dependencies)-join'|')){throw 'Rollback refused because dependencies drifted.'};if((@($Current.DependentServices)-join'|')-ne(@($Saved.service.DependentServices)-join'|')){throw 'Rollback refused because dependent services drifted.'}
}
try{
    $support=Get-Support;Write-StructuredLog 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
    switch($Action){
        'Check'{[pscustomobject]@{Support=$support;State=$support.State}}
        'Capture'{$state=Get-State;Assert-Safe $support $state;$saved=Save-State $state $support;Write-StructuredLog 'capture' 'pass' $saved;$saved}
        'DryRun'{$state=Get-State;if((Test-Path -LiteralPath $StatePath)-and(Test-Applied)){[void](Read-State);$r=[pscustomobject]@{WouldChange=$false;AlreadyApplied=$true}}else{Assert-Safe $support $state;$r=[pscustomobject]@{WouldChange=$true;Service=$serviceName;TargetStartMode='Manual';TargetDelayedAutoStart=0;PreserveRunningState=$true}};Write-StructuredLog 'dry-run' 'pass' $r;$r}
        'Apply'{if(Test-Path -LiteralPath $StatePath){[void](Read-State);if(Test-Applied){Write-StructuredLog 'apply' 'pass' @{changed=$false;reason='already-applied'};return[pscustomobject]@{Applied=$true;MutationCount=0}}}else{$state=Get-State;Assert-Safe $support $state;[void](Save-State $state $support)};if($PSCmdlet.ShouldProcess($serviceName,'Set startup type to Manual while preserving running state')){$o=& sc.exe config $serviceName start= demand 2>&1;if($LASTEXITCODE-ne 0){throw "sc.exe config failed: $($o-join' ')"};New-ItemProperty -LiteralPath $serviceReg -Name DelayedAutoStart -PropertyType DWord -Value 0 -Force|Out-Null};if(-not(Test-Applied)){throw 'Apply verification failed.'};Write-StructuredLog 'apply' 'pass' @{changed=$true};[pscustomobject]@{Applied=$true;MutationCount=1}}
        'Verify'{$ok=Test-Applied;$s=Get-State;Write-StructuredLog 'verify' $(if($ok){'pass'}else{'fail'}) $s;if(-not$ok){throw 'Verification failed.'};$true}
        'VerifyReboot'{$ok=Test-Applied;$d=[ordered]@{state=Get-State;bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime};Write-StructuredLog 'verify-reboot' $(if($ok){'pass'}else{'fail'}) $d;if(-not$ok){throw 'Reboot persistence verification failed.'};$true}
        'Rollback'{$saved=Read-State;$current=Get-State;Assert-CurrentIdentityMatchesSaved $saved $current;if(-not($current.StartMode-eq'Manual'-and$current.DelayedAutoStart-eq 0)){throw 'Rollback refused because applied configuration drifted.'};if($PSCmdlet.ShouldProcess($serviceName,'Restore exact startup configuration and running state')){$target=if($saved.service.StartMode-eq'Auto'){'auto'}else{'demand'};$o=& sc.exe config $serviceName start= $target 2>&1;if($LASTEXITCODE-ne 0){throw "sc.exe rollback config failed: $($o-join' ')"};New-ItemProperty -LiteralPath $serviceReg -Name DelayedAutoStart -PropertyType DWord -Value ([int]$saved.service.DelayedAutoStart) -Force|Out-Null;$svc=Get-Service -Name $serviceName;if($saved.service.State-eq'Running'-and$svc.Status-ne'Running'){Start-Service $serviceName};if($saved.service.State-ne'Running'-and$svc.Status-eq'Running'){Stop-Service $serviceName}};$after=Get-State;$ok=($after.StartMode-eq$saved.service.StartMode-and$after.DelayedAutoStart-eq[int]$saved.service.DelayedAutoStart-and$after.State-eq$saved.service.State);Write-StructuredLog 'rollback' $(if($ok){'pass'}else{'fail'}) @{restoredExactOriginal=$ok;state=$after};if(-not$ok){throw 'Rollback verification failed.'};[pscustomobject]@{RolledBack=$true;MutationCount=1}}
    }
}catch{Write-StructuredLog 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}

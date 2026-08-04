[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
  [string]$Action='Check',
  [string]$StatePath="$PSScriptRoot\state.json",
  [string]$LogPath="$PSScriptRoot\events.jsonl"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$Experiment='EXP-065'
$ServiceName='HPSysInfoCap'
$ServiceKey="HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"

function Write-Event([string]$Event,[string]$Result,$Data){
  $dir=Split-Path -Parent $LogPath
  if($dir -and -not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
  $sid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
  $row=[ordered]@{schemaVersion=1;timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment=$Experiment;action=$Action;event=$Event;result=$Result;computer=$env:COMPUTERNAME;userSid=$sid;data=$Data}
  ($row|ConvertTo-Json -Compress -Depth 16)|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-Elevation {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());$p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
function Get-ExecutablePath([string]$PathName){if([string]::IsNullOrWhiteSpace($PathName)){throw 'Service binary path missing'};if($PathName.TrimStart().StartsWith('"')){$m=[regex]::Match($PathName,'^\s*"([^"]+)"');if(-not $m.Success){throw 'Unable to parse quoted service executable path'};return $m.Groups[1].Value};$m=[regex]::Match($PathName,'^\s*([^\s]+\.exe)',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);if(-not $m.Success){throw 'Unable to parse service executable path'};$m.Groups[1].Value}
function Get-RegistryValueState([string]$Name){if(-not(Test-Path -LiteralPath $ServiceKey)){throw 'Service registry key missing'};$key=Get-Item -LiteralPath $ServiceKey;if($key.GetValueNames() -notcontains $Name){return [pscustomobject]@{Exists=$false;Kind=$null;Data=$null}};[pscustomobject]@{Exists=$true;Kind=$key.GetValueKind($Name).ToString();Data=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}
function Set-RegistryValueState([string]$Name,$State){$key=Get-Item -LiteralPath $ServiceKey;if([bool]$State.Exists){$kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$State.Kind,$true);$key.SetValue($Name,$State.Data,$kind)}elseif($key.GetValueNames() -contains $Name){Remove-ItemProperty -LiteralPath $ServiceKey -Name $Name}}
function Get-PendingReboot {$paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired');foreach($p in $paths){if(Test-Path -LiteralPath $p){return $true}};$sm='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager';try{$v=(Get-ItemProperty -LiteralPath $sm -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations;if($v){return $true}}catch{};return $false}
function Get-ManagementState {$cs=Get-CimInstance Win32_ComputerSystem;$mdm=$false;$root='HKLM:\SOFTWARE\Microsoft\Enrollments';if(Test-Path -LiteralPath $root){foreach($k in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue){try{$p=Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop;if($p.ProviderID -or $p.UPN -or $p.DiscoveryServiceFullURL){$mdm=$true;break}}catch{}}};[pscustomobject]@{DomainJoined=[bool]$cs.PartOfDomain;MdmEnrollment=[bool]$mdm;ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue);Managed=([bool]$cs.PartOfDomain -or [bool]$mdm -or [bool](Get-Service CcmExec -ErrorAction SilentlyContinue))}}
function Get-ProtectedState {$names=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale');$rows=@();foreach($name in $names){$s=Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue;if($s){$rows+=[pscustomobject]@{Name=$s.Name;StartMode=$s.StartMode;State=$s.State;PathName=$s.PathName}}};@($rows|Sort-Object Name)}
function Same($A,$B){(($A|ConvertTo-Json -Compress -Depth 16) -eq ($B|ConvertTo-Json -Compress -Depth 16))}
function Get-ExecutableTrustMode {
  param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][bool]$SignatureValid,
    [string]$SignatureSubject,
    [string]$Company,
    [string]$Product,
    [string]$OriginalFilename,
    [string]$WindowsRoot=$env:SystemRoot
  )
  $hpMetadata=($Company -match '(?i)^HP Inc\.?$|^Hewlett-Packard' -and $Product -match '(?i)^SysInfoCap$' -and $OriginalFilename -match '(?i)^SysInfoCap\.exe$')
  if(-not $SignatureValid -or -not $hpMetadata){return $null}
  $directHpPath=($Executable -match '(?i)\\(?:HP|Hewlett-Packard)\\')
  $directHpSigner=($SignatureSubject -match '(?i)HP Inc|Hewlett-Packard')
  if($directHpPath -and $directHpSigner){return 'direct-hp-publisher'}
  $driverStoreRoot=[regex]::Escape((Join-Path $WindowsRoot 'System32\DriverStore\FileRepository'))
  $hpDriverStorePath=($Executable -match ('(?i)^'+$driverStoreRoot+'\\hpcustomcapcomp\.inf_[a-z0-9_]+\\x64\\SysInfoCap\.exe$'))
  $hardwarePublisherSigner=($SignatureSubject -match '(?i)^CN=Microsoft Windows Hardware Compatibility Publisher(?:,|$)')
  if($hpDriverStorePath -and $hardwarePublisherSigner){return 'hp-driverstore-hardware-publisher'}
  return $null
}
function Get-Candidate {
  $os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem;$management=Get-ManagementState
  $reasons=@();if($os.Caption -notmatch 'Windows 11'){$reasons+='Windows 11 required'};if($cs.Manufacturer -notmatch '(?i)^HP$|Hewlett-Packard'){$reasons+='HP platform required'};if(-not(Test-Elevation)){$reasons+='elevation required'};if(Get-PendingReboot){$reasons+='pending reboot detected'};if($management.Managed){$reasons+='enterprise management ownership detected'}
  $matches=@(Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue);if($matches.Count -ne 1){$reasons+='exactly one HPSysInfoCap service required';return [pscustomobject]@{Supported=$false;Reasons=$reasons;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;Management=$management;Service=$null;Protected=Get-ProtectedState}}
  $svc=$matches[0];if($svc.DisplayName -notmatch '(?i)HP.*System Info.*HSA'){$reasons+='service display identity refused'}
  $exe=$null;try{$exe=Get-ExecutablePath $svc.PathName}catch{$reasons+=$_.Exception.Message}
  if($exe){if((Split-Path -Leaf $exe) -notmatch '(?i)^SysInfoCap\.exe$'){$reasons+='service executable identity refused'};if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){$reasons+='service executable missing'}}
  $sig=$null;$hash=$null;$version=$null;$company=$null;$product=$null;$originalFilename=$null;$trustMode=$null
  if($exe -and (Test-Path -LiteralPath $exe -PathType Leaf)){
    $file=Get-Item -LiteralPath $exe
    $sig=Get-AuthenticodeSignature -LiteralPath $exe
    $hash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
    $version=$file.VersionInfo.FileVersion
    $company=[string]$file.VersionInfo.CompanyName
    $product=[string]$file.VersionInfo.ProductName
    $originalFilename=[string]$file.VersionInfo.OriginalFilename
    $signatureValid=($sig.Status -eq 'Valid' -and $sig.SignerCertificate)
    $signatureSubject=if($sig.SignerCertificate){[string]$sig.SignerCertificate.Subject}else{$null}
    $trustMode=Get-ExecutableTrustMode -Executable $exe -SignatureValid $signatureValid -SignatureSubject $signatureSubject -Company $company -Product $product -OriginalFilename $originalFilename
    if(-not $trustMode){$reasons+='service executable trust identity refused'}
  }
  $gs=Get-Service -Name $ServiceName -ErrorAction SilentlyContinue;$deps=@();$dependents=@();if($gs){$deps=@($gs.ServicesDependedOn|ForEach-Object Name|Sort-Object);$dependents=@($gs.DependentServices|ForEach-Object Name|Sort-Object)}
  foreach($name in @($deps+$dependents)){if($name -match '(?i)WinDefend|mpssvc|bfe|wuauserv|bits|cryptsvc|Tailscale|Omnissa|TermService|RasMan|NlaSvc|Dhcp|Dnscache'){$reasons+="Protected dependency refused: $name"}}
  if($svc.ServiceType -match '(?i)kernel|file system|driver'){$reasons+='driver-backed service refused'};if($svc.StartMode -eq 'Disabled'){$reasons+='Disabled baseline refused'}
  $service=[pscustomobject]@{Name=$svc.Name;DisplayName=$svc.DisplayName;PathName=$svc.PathName;State=$svc.State;StartMode=$svc.StartMode;StartName=$svc.StartName;ServiceType=$svc.ServiceType;Executable=$exe;ExecutableVersion=$version;ExecutableHash=$hash;ExecutableCompanyName=$company;ExecutableProductName=$product;ExecutableOriginalFilename=$originalFilename;PublisherTrustMode=$trustMode;SignatureSubject=if($sig -and $sig.SignerCertificate){$sig.SignerCertificate.Subject}else{$null};SignatureThumbprint=if($sig -and $sig.SignerCertificate){$sig.SignerCertificate.Thumbprint}else{$null};DelayedAutoStart=(Get-RegistryValueState 'DelayedAutoStart');Dependencies=$deps;Dependents=$dependents}
  [pscustomobject]@{Supported=($reasons.Count -eq 0);Reasons=$reasons;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model;Management=$management;Service=$service;Protected=Get-ProtectedState;EvidenceStatus='needs-evidence'}
}
function Save-State($Support){if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused'};$dir=Split-Path -Parent $StatePath;if($dir -and -not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null};$state=[ordered]@{schemaVersion=2;experiment=$Experiment;computer=$env:COMPUTERNAME;userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value);capturedUtc=(Get-Date).ToUniversalTime().ToString('o');capturedBootUtc=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');support=$Support;protected=$Support.Protected;evidenceStatus='needs-evidence'};$state|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $StatePath -Encoding UTF8;Write-Event 'state-captured' 'pass' @{service=$Support.Service.Name;startMode=$Support.Service.StartMode;delayedAutoStart=$Support.Service.DelayedAutoStart;state=$Support.Service.State;hash=$Support.Service.ExecutableHash};$state}
function Read-State {if(-not(Test-Path -LiteralPath $StatePath)){throw 'State file missing'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;if($s.schemaVersion -ne 2 -or $s.experiment -ne $Experiment -or $s.computer -ne $env:COMPUTERNAME -or $s.userSid -ne ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)){throw 'State identity refused'};$s}
function Assert-DriftSafe($State,$Current){$o=$State.support.Service;$c=$Current.Service;if(-not $Current.Supported){throw ('Support drift detected: '+($Current.Reasons -join '; '))};if($c.Name -ne $o.Name -or $c.DisplayName -ne $o.DisplayName -or $c.PathName -ne $o.PathName -or $c.Executable -ne $o.Executable -or $c.ExecutableHash -ne $o.ExecutableHash -or $c.SignatureThumbprint -ne $o.SignatureThumbprint){throw 'Service identity drift detected'};if(-not(Same $c.Dependencies $o.Dependencies) -or -not(Same $c.Dependents $o.Dependents)){throw 'Service dependency drift detected'};if(-not(Same $Current.Management $State.support.Management)){throw 'Management state drift detected'};if(-not(Same (Get-ProtectedState) $State.protected)){throw 'Protected security, update, or remote-access state drift detected'}}
function Set-StartupMode([string]$Mode){$map=@{Auto='Automatic';Automatic='Automatic';Manual='Manual'};if(-not $map.ContainsKey($Mode)){throw "Unsupported startup mode: $Mode"};Set-Service -Name $ServiceName -StartupType $map[$Mode]}

try {
  $support=Get-Candidate
  Write-Event 'support-detection' $(if($support.Supported){'pass'}else{'refused'}) $support
  switch($Action){
    'Check' {$support}
    'Capture' {if(-not $support.Supported){throw ($support.Reasons -join '; ')};Save-State $support}
    'DryRun' {if(-not $support.Supported){throw ($support.Reasons -join '; ')};$x=[pscustomobject]@{WouldChange=($support.Service.StartMode -ne 'Manual');MutationCount=if($support.Service.StartMode -eq 'Manual'){0}else{1};Service=$ServiceName;From=$support.Service.StartMode;To='Manual';PreserveRunningState=$true;DelayedAutoStartPreservedExactly=$true;Rollback='restore exact captured startup mode, delayed-start value existence/type/data, and running state';EvidenceStatus='needs-evidence'};Write-Event 'dry-run' 'pass' $x;$x}
    'Apply' {if(-not(Test-Path -LiteralPath $StatePath)){throw 'Capture required before Apply'};$state=Read-State;Assert-DriftSafe $state $support;$original=$state.support.Service;if($support.Service.StartMode -eq 'Manual'){if(-not(Same $support.Service.DelayedAutoStart $original.DelayedAutoStart)){throw 'Idempotent apply refused on delayed-start drift'};Write-Event 'apply' 'idempotent' @{mutationCount=0};return $support.Service};if($support.Service.StartMode -ne $original.StartMode -or -not(Same $support.Service.DelayedAutoStart $original.DelayedAutoStart)){throw 'Configuration drift detected before Apply'};$running=$support.Service.State;if($WhatIfPreference){Write-Event 'apply' 'whatif' @{mutationCount=0;to='Manual'};return};if($PSCmdlet.ShouldProcess($ServiceName,'Set startup mode to Manual while preserving running state')){Set-StartupMode 'Manual'}else{return};$after=Get-Candidate;if($after.Service.StartMode -ne 'Manual' -or $after.Service.State -ne $running -or -not(Same $after.Service.DelayedAutoStart $original.DelayedAutoStart)){throw 'Apply verification failed'};Write-Event 'apply' 'pass' @{mutationCount=1;before=$support.Service;after=$after.Service};$after.Service}
    'Verify' {$state=Read-State;Assert-DriftSafe $state $support;if($support.Service.StartMode -ne 'Manual'){throw 'Manual treatment absent'};if(-not(Same $support.Service.DelayedAutoStart $state.support.Service.DelayedAutoStart)){throw 'Delayed-start drift detected'};Write-Event 'verify' 'pass' $support.Service;$support.Service}
    'VerifyReboot' {$state=Read-State;Assert-DriftSafe $state $support;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot -le [datetime]$state.capturedBootUtc){throw 'Later boot required for reboot persistence verification'};if($support.Service.StartMode -ne 'Manual'){throw 'Reboot persistence failed'};if(-not(Same $support.Service.DelayedAutoStart $state.support.Service.DelayedAutoStart)){throw 'Delayed-start drift detected after reboot'};Write-Event 'verify-reboot' 'pass' @{bootUtc=$boot.ToString('o');service=$support.Service;evidenceStatus='needs-evidence'};$support.Service}
    'Rollback' {$state=Read-State;Assert-DriftSafe $state $support;$o=$state.support.Service;if($support.Service.StartMode -eq $o.StartMode -and $support.Service.State -eq $o.State -and (Same $support.Service.DelayedAutoStart $o.DelayedAutoStart)){Write-Event 'rollback' 'idempotent' @{mutationCount=0};return $support.Service};if($support.Service.StartMode -ne 'Manual'){throw 'Rollback collision detected'};if(-not(Same $support.Service.DelayedAutoStart $o.DelayedAutoStart)){throw 'Rollback refused on delayed-start drift'};if($WhatIfPreference){Write-Event 'rollback' 'whatif' @{restoreStartMode=$o.StartMode;restoreDelayedAutoStart=$o.DelayedAutoStart;restoreState=$o.State};return};if($PSCmdlet.ShouldProcess($ServiceName,'Restore exact captured service startup configuration and running state')){Set-StartupMode $o.StartMode;Set-RegistryValueState 'DelayedAutoStart' $o.DelayedAutoStart;$status=(Get-Service $ServiceName).Status;if($o.State -eq 'Running' -and $status -ne 'Running'){Start-Service $ServiceName}elseif($o.State -eq 'Stopped' -and $status -ne 'Stopped'){Stop-Service $ServiceName}}else{return};$after=Get-Candidate;if($after.Service.StartMode -ne $o.StartMode -or $after.Service.State -ne $o.State -or -not(Same $after.Service.DelayedAutoStart $o.DelayedAutoStart)){throw 'Exact rollback verification failed'};Write-Event 'rollback' 'pass' @{restoredExactOriginal=$true;after=$after.Service};$after.Service}
  }
} catch {
  Write-Event 'failure' 'failed' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName}
  throw
}

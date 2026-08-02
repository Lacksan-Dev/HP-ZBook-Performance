[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
  [string]$Action='Check',
  [string]$StatePath="$PSScriptRoot\state.json",
  [string]$LogPath="$PSScriptRoot\events.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$ServiceName='HPTouchpointAnalyticsService'
$MinimumSafeVersion=[version]'4.2.2439.0'
$ServiceKey="HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
$ProtectedServices=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')

function Write-Event([string]$Event,[string]$Result,[hashtable]$Data){
  $dir=Split-Path $LogPath -Parent;if($dir -and -not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
  $row=[ordered]@{schemaVersion=3;utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-024';action=$Action;event=$Event;result=$Result;computer=$env:COMPUTERNAME;userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value);data=$Data}
  ($row|ConvertTo-Json -Compress -Depth 12)|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Test-Elevation {$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent());if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevation required'}}
function Get-ExecutablePath([string]$PathName){if([string]::IsNullOrWhiteSpace($PathName)){throw 'Service binary path missing'};if($PathName.TrimStart().StartsWith('"')){$m=[regex]::Match($PathName,'^\s*"([^"]+)"');if(-not $m.Success){throw 'Unable to parse quoted service executable path'};return $m.Groups[1].Value};$m=[regex]::Match($PathName,'^\s*([^\s]+\.exe)',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);if(-not $m.Success){throw 'Unable to parse service executable path'};$m.Groups[1].Value}
function Get-RegistryValueState([string]$Name){
  if(-not(Test-Path -LiteralPath $ServiceKey)){throw 'Service registry key missing'}
  $key=Get-Item -LiteralPath $ServiceKey
  if($key.GetValueNames() -notcontains $Name){return [pscustomobject]@{Exists=$false;Kind=$null;Data=$null}}
  [pscustomobject]@{Exists=$true;Kind=$key.GetValueKind($Name).ToString();Data=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
}
function Get-PendingReboot {$paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired');foreach($p in $paths){if(Test-Path -LiteralPath $p){return $true}};$sm='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager';try{$v=(Get-ItemProperty -LiteralPath $sm -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations;if($v){return $true}}catch [System.Management.Automation.ItemNotFoundException]{};return $false}
function Get-MdmEnrollmentDetected {$root='HKLM:\SOFTWARE\Microsoft\Enrollments';if(-not(Test-Path -LiteralPath $root)){return $false};foreach($k in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue){try{$p=Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop;if($p.ProviderID -or $p.UPN -or $p.DiscoveryServiceFullURL){return $true}}catch{}};return $false}
function Get-ManagementState {$cs=Get-CimInstance Win32_ComputerSystem;[pscustomobject]@{DomainJoined=[bool]$cs.PartOfDomain;MdmEnrollment=[bool](Get-MdmEnrollmentDetected);ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)}}
function Get-ProtectedState {
  $rows=@();foreach($name in $ProtectedServices){$s=Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue;if($s){$rows+=[pscustomobject]@{Name=$s.Name;State=$s.State;StartMode=$s.StartMode;PathName=$s.PathName}}}
  [pscustomobject]@{Services=@($rows|Sort-Object Name)}
}
function Test-Same($A,$B){($A|ConvertTo-Json -Compress -Depth 12)-eq($B|ConvertTo-Json -Compress -Depth 12)}
function Get-Candidate {
  Test-Elevation;$os=Get-CimInstance Win32_OperatingSystem;$cs=Get-CimInstance Win32_ComputerSystem
  if($os.Caption -notmatch 'Windows 11' -or $cs.Manufacturer -notmatch 'HP|Hewlett-Packard'){throw 'Unsupported platform'}
  if(Get-PendingReboot){throw 'Pending reboot detected'};$management=Get-ManagementState;if($management.DomainJoined){throw 'Enterprise-managed domain state refused'};if($management.MdmEnrollment){throw 'Enterprise MDM enrollment refused'};if($management.ConfigMgr){throw 'Enterprise ConfigMgr ownership refused'}
  $matches=@(Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue);if($matches.Count -ne 1){throw 'Candidate service absent or ambiguous'};$svc=$matches[0]
  if($svc.DisplayName -notmatch '(?i)HP.*Touchpoint.*Analytics'){throw 'Service display identity refused'};if($svc.PathName -notmatch '(?i)HP.*Touchpoint|Touchpoint.*Analytics'){throw 'Service executable identity refused'};if($svc.PathName -match '(?i)Defender|SecurityHealth|Tailscale|Omnissa|RemoteDesktop|WindowsApp'){throw 'Protected identity refused'}
  if($svc.ServiceType -match '(?i)driver'){throw 'Driver-backed service refused'};if($svc.StartMode -eq 'Disabled'){throw 'Disabled service refused'}
  $exe=Get-ExecutablePath $svc.PathName;if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Service executable missing'};$sig=Get-AuthenticodeSignature -LiteralPath $exe;if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?i)HP Inc|Hewlett-Packard'){throw 'HP publisher signature refused'}
  $rawVersion=(Get-Item -LiteralPath $exe).VersionInfo.FileVersion;try{$version=[version]($rawVersion -replace '[^0-9\.]','')}catch{throw 'Executable version unreadable'};if($version -lt $MinimumSafeVersion){throw "Outdated HP Touchpoint Analytics version refused: $version"};$hash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
  $gs=Get-Service -Name $ServiceName;$deps=@($gs.ServicesDependedOn|ForEach-Object Name|Sort-Object);$dependents=@($gs.DependentServices|ForEach-Object Name|Sort-Object);foreach($name in @($deps+$dependents)){if($name -match '(?i)WinDefend|mpssvc|bfe|wuauserv|bits|cryptsvc|Tailscale|Omnissa|TermService'){throw "Protected dependency refused: $name"}}
  $protected=Get-ProtectedState;foreach($required in 'wuauserv','BITS'){if(@($protected.Services|Where-Object Name -eq $required).Count -eq 0){throw "Windows Update dependency missing: $required"};if(($protected.Services|Where-Object Name -eq $required).StartMode -eq 'Disabled'){throw "Windows Update dependency disabled: $required"}}
  [pscustomobject]@{Service=$svc;Executable=$exe;Version=$version.ToString();Hash=$hash;SignatureSubject=$sig.SignerCertificate.Subject;DelayedAutoStart=(Get-RegistryValueState 'DelayedAutoStart');RegistryStart=(Get-RegistryValueState 'Start');Dependencies=$deps;Dependents=$dependents;WindowsBuild=$os.BuildNumber;Management=$management;Protected=$protected}
}
function Assert-BaselineEligible($candidate){if($candidate.Service.StartMode -notin @('Auto','Automatic')){throw 'Baseline startup mode must be Automatic or Automatic Delayed Start'}}
function Save-State($candidate){
  if(Test-Path -LiteralPath $StatePath){throw 'State overwrite refused'}
  $dir=Split-Path $StatePath -Parent;if($dir -and -not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}
  $svc=$candidate.Service;$state=[ordered]@{schema=3;computer=$env:COMPUTERNAME;userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value);service=$svc.Name;displayName=$svc.DisplayName;path=$svc.PathName;executable=$candidate.Executable;executableVersion=$candidate.Version;executableHash=$candidate.Hash;signatureSubject=$candidate.SignatureSubject;startMode=$svc.StartMode;registryStart=$candidate.RegistryStart;delayedAutoStart=$candidate.DelayedAutoStart;state=$svc.State;serviceAccount=$svc.StartName;dependencies=@($candidate.Dependencies);dependents=@($candidate.Dependents);windowsBuild=$candidate.WindowsBuild;management=$candidate.Management;protected=$candidate.Protected;capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o');capturedUtc=(Get-Date).ToUniversalTime().ToString('o');evidenceStatus='needs-evidence'}
  $state|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $StatePath -Encoding UTF8;Write-Event 'state-captured' 'pass' @{service=$svc.Name;startMode=$svc.StartMode;delayedAutoStart=$candidate.DelayedAutoStart;state=$svc.State;version=$candidate.Version;hash=$candidate.Hash};$state
}
function Read-State {if(-not(Test-Path -LiteralPath $StatePath)){throw 'State file missing'};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;if($s.schema -ne 3 -or $s.computer -ne $env:COMPUTERNAME -or $s.userSid -ne ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value) -or $s.service -ne $ServiceName){throw 'State identity refused'};$s}
function Restore-RegistryValue([string]$Name,$State){
  $key=Get-Item -LiteralPath $ServiceKey
  if([bool]$State.Exists){$kind=[Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$State.Kind,$true);$key.SetValue($Name,$State.Data,$kind)}elseif($key.GetValueNames() -contains $Name){Remove-ItemProperty -LiteralPath $ServiceKey -Name $Name}
}
function Set-TreatmentMode {Set-Service -Name $ServiceName -StartupType Manual;Set-ItemProperty -LiteralPath $ServiceKey -Name DelayedAutoStart -Type DWord -Value 0}
function Restore-StartupState($state){Set-Service -Name $ServiceName -StartupType Automatic;Restore-RegistryValue 'Start' $state.registryStart;Restore-RegistryValue 'DelayedAutoStart' $state.delayedAutoStart}
function Assert-DriftSafe($state,$candidate){
  if($candidate.Service.PathName -ne $state.path){throw 'Rollback service identity changed'};if($candidate.Executable -ne $state.executable){throw 'Rollback executable identity changed'};if($candidate.Hash -ne $state.executableHash){throw 'Rollback executable hash changed'};if($candidate.Version -ne $state.executableVersion){throw 'Rollback executable version changed'};if($candidate.SignatureSubject -ne $state.signatureSubject){throw 'Rollback publisher identity changed'}
  if((Compare-Object @($candidate.Dependencies) @($state.dependencies))){throw 'Rollback dependencies changed'};if((Compare-Object @($candidate.Dependents) @($state.dependents))){throw 'Rollback dependents changed'};if(-not(Test-Same $candidate.Management $state.management)){throw 'Rollback management state changed'};if(-not(Test-Same $candidate.Protected $state.protected)){throw 'Rollback protected state changed'}
}
function Test-Treatment($candidate){$candidate.Service.StartMode -eq 'Manual' -and [bool]$candidate.DelayedAutoStart.Exists -and [int]$candidate.DelayedAutoStart.Data -eq 0}
function Test-OriginalStartup($candidate,$state){$startOk=(Test-Same $candidate.RegistryStart $state.registryStart);$delayOk=(Test-Same $candidate.DelayedAutoStart $state.delayedAutoStart);$modeOk=$candidate.Service.StartMode -eq $state.startMode;$modeOk -and $startOk -and $delayOk}

try {
  $candidate=Get-Candidate;$svc=$candidate.Service
  switch($Action){
    'Check' {Write-Event 'supported' 'pass' @{service=$svc.Name;path=$svc.PathName;startMode=$svc.StartMode;delayedAutoStart=$candidate.DelayedAutoStart;version=$candidate.Version;hash=$candidate.Hash;management=$candidate.Management};[pscustomobject]@{Supported=$true;Name=$svc.Name;DisplayName=$svc.DisplayName;PathName=$svc.PathName;StartMode=$svc.StartMode;DelayedAutoStart=$candidate.DelayedAutoStart;State=$svc.State;Version=$candidate.Version;SHA256=$candidate.Hash;EvidenceStatus='needs-evidence'}}
    'Capture' {Assert-BaselineEligible $candidate;$s=Save-State $candidate;Write-Event 'capture' 'pass' @{statePath=$StatePath};$s}
    'DryRun' {Assert-BaselineEligible $candidate;$r=[pscustomobject]@{WouldChange=$true;MutationCount=1;Service=$ServiceName;From=$svc.StartMode;To='Manual';PreserveRunningState=$true;RebootPersistenceRequired=$true;Rollback='Restore exact captured Start and DelayedAutoStart registry existence, type, data, startup mode, and original running state.';EvidenceStatus='needs-evidence'};Write-Event 'dry-run' 'pass' @{from=$svc.StartMode;to='Manual';preserveRunningState=$true};$r}
    'Apply' {
      $state=Read-State;Assert-DriftSafe $state $candidate
      if(Test-Treatment $candidate){Write-Event 'already-applied' 'idempotent' @{service=$svc.Name};break}
      if(-not(Test-OriginalStartup $candidate $state)){throw 'Apply configuration drift detected'}
      $running=$svc.State;if($WhatIfPreference){Write-Event 'apply' 'whatif' @{service=$svc.Name;proposedStartMode='Manual';preserveRunningState=$running};$null=$PSCmdlet.ShouldProcess($ServiceName,'Set startup mode to Manual');break}
      if($PSCmdlet.ShouldProcess($ServiceName,'Set startup mode to Manual while preserving current running state')){Set-TreatmentMode}else{Write-Event 'apply-declined' 'declined' @{service=$svc.Name};break}
      $after=Get-Candidate;if(-not(Test-Treatment $after) -or $after.Service.State -ne $running){throw 'Apply verification failed'};Write-Event 'applied' 'pass' @{before=$svc.StartMode;after=$after.Service.StartMode;runningStatePreserved=$running}
    }
    'Verify' {$state=Read-State;Assert-DriftSafe $state $candidate;if(-not(Test-Treatment $candidate)){throw 'Verification failed'};Write-Event 'verified' 'pass' @{manual=$true;version=$candidate.Version;hash=$candidate.Hash};$true}
    'VerifyReboot' {$state=Read-State;Assert-DriftSafe $state $candidate;$boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime();if($boot -le [datetime]$state.capturedBootTime){throw 'A later boot is required for reboot persistence verification'};if(-not(Test-Treatment $candidate)){throw 'Reboot persistence failed'};Write-Event 'reboot-verified' 'pass' @{boot=$boot.ToString('o');manual=$true;state=$candidate.Service.State;version=$candidate.Version;hash=$candidate.Hash;evidenceStatus='needs-evidence'};$true}
    'Rollback' {
      $state=Read-State;Assert-DriftSafe $state $candidate
      if(Test-OriginalStartup $candidate $state -and $candidate.Service.State -eq $state.state){Write-Event 'rolled-back' 'idempotent' @{service=$svc.Name};break}
      if(-not(Test-Treatment $candidate)){throw 'Rollback collision or startup configuration drift detected'}
      if($WhatIfPreference){Write-Event 'rollback' 'whatif' @{service=$svc.Name;restoreStartMode=$state.startMode;restoreDelayedAutoStart=$state.delayedAutoStart;restoreState=$state.state};$null=$PSCmdlet.ShouldProcess($ServiceName,"Restore exact captured startup and running state");break}
      if($PSCmdlet.ShouldProcess($ServiceName,'Restore exact captured startup and running state')){Restore-StartupState $state;$status=(Get-Service $ServiceName).Status;if($state.state -eq 'Running' -and $status -ne 'Running'){Start-Service $ServiceName}elseif($state.state -eq 'Stopped' -and $status -eq 'Running'){Stop-Service $ServiceName}}else{Write-Event 'rollback-declined' 'declined' @{service=$svc.Name};break}
      $after=Get-Candidate;if(-not(Test-OriginalStartup $after $state) -or $after.Service.State -ne $state.state){throw 'Exact rollback verification failed'};Write-Event 'rolled-back' 'pass' @{restoredExactOriginal=$true;startMode=$after.Service.StartMode;delayedAutoStart=$after.DelayedAutoStart;state=$after.Service.State;version=$after.Version;hash=$after.Hash};$after
    }
  }
} catch {
  try{Write-Event 'failure' 'failure' @{stage=$Action;message=$_.Exception.Message;type=$_.Exception.GetType().FullName}}catch{}
  throw
}

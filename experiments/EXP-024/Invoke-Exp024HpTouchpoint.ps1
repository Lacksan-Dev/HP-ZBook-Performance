[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [ValidateSet('Check','Capture','Apply','Verify','VerifyReboot','Rollback')]
  [string]$Action='Check',
  [string]$StatePath="$PSScriptRoot\state.json",
  [string]$LogPath="$PSScriptRoot\events.jsonl"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ServiceName='HPTouchpointAnalyticsService'
$MinimumSafeVersion=[version]'4.2.2439.0'
$ServiceKey="HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"

function Write-Event([string]$Event,[hashtable]$Data){
  $row=[ordered]@{
    utc=(Get-Date).ToUniversalTime().ToString('o')
    experiment='EXP-024'
    action=$Action
    event=$Event
    computer=$env:COMPUTERNAME
    userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
    data=$Data
  }
  ($row|ConvertTo-Json -Compress -Depth 8)|Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Test-Elevation {
  $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevation required'}
}

function Get-ExecutablePath([string]$PathName){
  if([string]::IsNullOrWhiteSpace($PathName)){throw 'Service binary path missing'}
  if($PathName.TrimStart().StartsWith('"')){
    $m=[regex]::Match($PathName,'^\s*"([^"]+)"')
    if(-not $m.Success){throw 'Unable to parse quoted service executable path'}
    return $m.Groups[1].Value
  }
  $m=[regex]::Match($PathName,'^\s*([^\s]+\.exe)',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){throw 'Unable to parse service executable path'}
  $m.Groups[1].Value
}

function Get-DelayedAutoStart {
  if(-not(Test-Path -LiteralPath $ServiceKey)){throw 'Service registry key missing'}
  $p=Get-ItemProperty -LiteralPath $ServiceKey
  if($null -eq $p.DelayedAutoStart){return 0}
  [int]$p.DelayedAutoStart
}

function Get-PendingReboot {
  $paths=@(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
  )
  foreach($p in $paths){if(Test-Path -LiteralPath $p){return $true}}
  $sm='HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
  try {
    $v=(Get-ItemProperty -LiteralPath $sm -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations
    if($v){return $true}
  } catch [System.Management.Automation.ItemNotFoundException] {}
  return $false
}

function Get-MdmEnrollmentDetected {
  $root='HKLM:\SOFTWARE\Microsoft\Enrollments'
  if(-not(Test-Path -LiteralPath $root)){return $false}
  foreach($k in Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue){
    try {
      $p=Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop
      if($p.ProviderID -or $p.UPN -or $p.DiscoveryServiceFullURL){return $true}
    } catch {}
  }
  return $false
}

function Get-Candidate {
  Test-Elevation
  $os=Get-CimInstance Win32_OperatingSystem
  $cs=Get-CimInstance Win32_ComputerSystem
  if($os.Caption -notmatch 'Windows 11' -or $cs.Manufacturer -notmatch 'HP|Hewlett-Packard'){throw 'Unsupported platform'}
  if(Get-PendingReboot){throw 'Pending reboot detected'}
  if($cs.PartOfDomain){throw 'Enterprise-managed domain state refused'}
  if(Get-MdmEnrollmentDetected){throw 'Enterprise MDM enrollment refused'}

  $matches=@(Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue)
  if($matches.Count -ne 1){throw 'Candidate service absent or ambiguous'}
  $svc=$matches[0]
  if($svc.DisplayName -notmatch '(?i)HP.*Touchpoint.*Analytics'){throw 'Service display identity refused'}
  if($svc.PathName -notmatch '(?i)HP.*Touchpoint|Touchpoint.*Analytics'){throw 'Service executable identity refused'}
  if($svc.PathName -match '(?i)Defender|SecurityHealth|Tailscale|Omnissa|RemoteDesktop|WindowsApp'){throw 'Protected identity refused'}

  $exe=Get-ExecutablePath $svc.PathName
  if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Service executable missing'}
  $sig=Get-AuthenticodeSignature -LiteralPath $exe
  if($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch '(?i)HP Inc|Hewlett-Packard'){throw 'HP publisher signature refused'}
  $file=Get-Item -LiteralPath $exe
  $rawVersion=$file.VersionInfo.FileVersion
  try {$version=[version]($rawVersion -replace '[^0-9\.]','')} catch {throw 'Executable version unreadable'}
  if($version -lt $MinimumSafeVersion){throw "Outdated HP Touchpoint Analytics version refused: $version"}
  $hash=(Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash

  $gs=Get-Service -Name $ServiceName
  $deps=@($gs.ServicesDependedOn|ForEach-Object Name)
  $dependents=@($gs.DependentServices|ForEach-Object Name)
  foreach($name in @($deps+$dependents)){
    if($name -match '(?i)WinDefend|mpssvc|bfe|wuauserv|bits|cryptsvc|Tailscale|Omnissa|TermService'){throw "Protected dependency refused: $name"}
  }

  [pscustomobject]@{
    Service=$svc
    Executable=$exe
    Version=$version.ToString()
    Hash=$hash
    SignatureSubject=$sig.SignerCertificate.Subject
    DelayedAutoStart=(Get-DelayedAutoStart)
    Dependencies=$deps
    Dependents=$dependents
    PartOfDomain=[bool]$cs.PartOfDomain
    MdmEnrollmentDetected=$false
    WindowsBuild=$os.BuildNumber
  }
}

function Save-State($candidate){
  $svc=$candidate.Service
  $state=[ordered]@{
    schema=2
    computer=$env:COMPUTERNAME
    service=$svc.Name
    displayName=$svc.DisplayName
    path=$svc.PathName
    executable=$candidate.Executable
    executableVersion=$candidate.Version
    executableHash=$candidate.Hash
    signatureSubject=$candidate.SignatureSubject
    startMode=$svc.StartMode
    delayedAutoStart=$candidate.DelayedAutoStart
    state=$svc.State
    serviceAccount=$svc.StartName
    dependencies=@($candidate.Dependencies)
    dependents=@($candidate.Dependents)
    windowsBuild=$candidate.WindowsBuild
    capturedUtc=(Get-Date).ToUniversalTime().ToString('o')
  }
  $state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $StatePath -Encoding UTF8
  Write-Event 'state-captured' @{service=$svc.Name;startMode=$svc.StartMode;delayedAutoStart=$candidate.DelayedAutoStart;state=$svc.State;version=$candidate.Version;hash=$candidate.Hash}
  $state
}

function Read-State {
  if(-not(Test-Path -LiteralPath $StatePath)){throw 'State file missing'}
  $s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
  if($s.schema -ne 2 -or $s.computer -ne $env:COMPUTERNAME -or $s.service -ne $ServiceName){throw 'State identity refused'}
  $s
}

function Set-Mode([string]$Mode,[int]$DelayedAutoStart=0){
  $map=@{Auto='Automatic';Automatic='Automatic';Manual='Manual';Disabled='Disabled'}
  if(-not $map.ContainsKey($Mode)){throw "Unsupported startup mode: $Mode"}
  Set-Service -Name $ServiceName -StartupType $map[$Mode]
  if($map[$Mode] -eq 'Automatic'){
    Set-ItemProperty -LiteralPath $ServiceKey -Name DelayedAutoStart -Type DWord -Value $DelayedAutoStart
  } else {
    Set-ItemProperty -LiteralPath $ServiceKey -Name DelayedAutoStart -Type DWord -Value 0
  }
}

function Assert-DriftSafe($state,$candidate){
  if($candidate.Service.PathName -ne $state.path){throw 'Rollback service identity changed'}
  if($candidate.Executable -ne $state.executable){throw 'Rollback executable identity changed'}
  if($candidate.Hash -ne $state.executableHash){throw 'Rollback executable hash changed'}
  if($candidate.Version -ne $state.executableVersion){throw 'Rollback executable version changed'}
  if($candidate.SignatureSubject -ne $state.signatureSubject){throw 'Rollback publisher identity changed'}
  if((Compare-Object @($candidate.Dependencies) @($state.dependencies))){throw 'Rollback dependencies changed'}
  if((Compare-Object @($candidate.Dependents) @($state.dependents))){throw 'Rollback dependents changed'}
}

$candidate=Get-Candidate
$svc=$candidate.Service
switch($Action){
  'Check' {
    Write-Event 'supported' @{service=$svc.Name;path=$svc.PathName;startMode=$svc.StartMode;delayedAutoStart=$candidate.DelayedAutoStart;version=$candidate.Version;hash=$candidate.Hash}
    [pscustomobject]@{Name=$svc.Name;DisplayName=$svc.DisplayName;PathName=$svc.PathName;StartMode=$svc.StartMode;DelayedAutoStart=$candidate.DelayedAutoStart;State=$svc.State;Version=$candidate.Version;SHA256=$candidate.Hash}
  }
  'Capture' {Save-State $candidate|Out-Null}
  'Apply' {
    if(-not(Test-Path -LiteralPath $StatePath)){Save-State $candidate|Out-Null}
    if($svc.StartMode -eq 'Manual' -and $candidate.DelayedAutoStart -eq 0){Write-Event 'already-applied' @{service=$svc.Name};break}
    if($PSCmdlet.ShouldProcess($ServiceName,'Set startup mode to Manual')){Set-Mode 'Manual' 0}
    $after=Get-Candidate
    if($after.Service.StartMode -ne 'Manual' -or $after.DelayedAutoStart -ne 0){throw 'Apply verification failed'}
    Write-Event 'applied' @{before=$svc.StartMode;beforeDelayed=$candidate.DelayedAutoStart;after=$after.Service.StartMode;afterDelayed=$after.DelayedAutoStart}
  }
  'Verify' {
    $now=Get-Candidate
    $ok=($now.Service.StartMode -eq 'Manual' -and $now.DelayedAutoStart -eq 0)
    Write-Event 'verified' @{manual=$ok;version=$now.Version;hash=$now.Hash}
    if(-not $ok){throw 'Verification failed'}
  }
  'VerifyReboot' {
    $now=Get-Candidate
    $ok=($now.Service.StartMode -eq 'Manual' -and $now.DelayedAutoStart -eq 0)
    Write-Event 'reboot-verified' @{manual=$ok;state=$now.Service.State;version=$now.Version;hash=$now.Hash}
    if(-not $ok){throw 'Reboot persistence failed'}
  }
  'Rollback' {
    $s=Read-State
    Assert-DriftSafe $s $candidate
    if($PSCmdlet.ShouldProcess($ServiceName,"Restore startup mode $($s.startMode), delayed=$($s.delayedAutoStart)")){
      Set-Mode $s.startMode ([int]$s.delayedAutoStart)
      $status=(Get-Service $ServiceName).Status
      if($s.state -eq 'Running' -and $status -ne 'Running'){Start-Service $ServiceName}
      elseif($s.state -eq 'Stopped' -and $status -eq 'Running'){Stop-Service $ServiceName -Force}
    }
    $after=Get-Candidate
    if($after.Service.StartMode -ne $s.startMode -or $after.DelayedAutoStart -ne [int]$s.delayedAutoStart){throw 'Rollback verification failed'}
    Write-Event 'rolled-back' @{startMode=$after.Service.StartMode;delayedAutoStart=$after.DelayedAutoStart;state=$after.Service.State;version=$after.Version;hash=$after.Hash}
  }
}

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
function Write-Event([string]$Event,[hashtable]$Data){
  $row=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-024';action=$Action;event=$Event;data=$Data}
  ($row|ConvertTo-Json -Compress -Depth 6)|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-Candidate {
  $os=Get-CimInstance Win32_OperatingSystem
  $cs=Get-CimInstance Win32_ComputerSystem
  if($os.Caption -notmatch 'Windows 11' -or $cs.Manufacturer -notmatch 'HP|Hewlett-Packard'){throw 'Unsupported platform'}
  $svc=Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
  if(-not $svc){throw 'Candidate service absent'}
  if($svc.PathName -notmatch '(?i)HP.*Touchpoint|Touchpoint.*Analytics'){throw 'Service executable identity refused'}
  if($svc.PathName -match '(?i)Defender|SecurityHealth|Tailscale|Omnissa|RemoteDesktop|WindowsApp'){throw 'Protected identity refused'}
  $svc
}
function Save-State($svc){
  $state=[ordered]@{schema=1;computer=$env:COMPUTERNAME;service=$svc.Name;displayName=$svc.DisplayName;path=$svc.PathName;startMode=$svc.StartMode;state=$svc.State;capturedUtc=(Get-Date).ToUniversalTime().ToString('o')}
  $state|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $StatePath -Encoding UTF8
  Write-Event 'state-captured' @{service=$svc.Name;startMode=$svc.StartMode;state=$svc.State}
  $state
}
function Read-State {
  if(-not(Test-Path -LiteralPath $StatePath)){throw 'State file missing'}
  $s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
  if($s.schema -ne 1 -or $s.computer -ne $env:COMPUTERNAME -or $s.service -ne $ServiceName){throw 'State identity refused'}
  $s
}
function Set-Mode([string]$Mode){
  $map=@{Auto='Automatic';Automatic='Automatic';Manual='Manual';Disabled='Disabled'}
  if(-not $map.ContainsKey($Mode)){throw "Unsupported startup mode: $Mode"}
  Set-Service -Name $ServiceName -StartupType $map[$Mode]
}
$svc=Get-Candidate
switch($Action){
 'Check' { Write-Event 'supported' @{service=$svc.Name;path=$svc.PathName;startMode=$svc.StartMode}; $svc|Select-Object Name,DisplayName,PathName,StartMode,State }
 'Capture' { Save-State $svc|Out-Null }
 'Apply' {
   if(-not(Test-Path -LiteralPath $StatePath)){Save-State $svc|Out-Null}
   if($svc.StartMode -eq 'Manual'){Write-Event 'already-applied' @{service=$svc.Name};break}
   if($PSCmdlet.ShouldProcess($ServiceName,'Set startup mode to Manual')){Set-Mode 'Manual'}
   $after=Get-Candidate
   if($after.StartMode -ne 'Manual'){throw 'Apply verification failed'}
   Write-Event 'applied' @{before=$svc.StartMode;after=$after.StartMode}
 }
 'Verify' { $ok=((Get-Candidate).StartMode -eq 'Manual');Write-Event 'verified' @{manual=$ok};if(-not $ok){throw 'Verification failed'} }
 'VerifyReboot' { $ok=((Get-Candidate).StartMode -eq 'Manual');Write-Event 'reboot-verified' @{manual=$ok};if(-not $ok){throw 'Reboot persistence failed'} }
 'Rollback' {
   $s=Read-State
   $current=Get-Candidate
   if($current.PathName -ne $s.path){throw 'Rollback service identity changed'}
   if($PSCmdlet.ShouldProcess($ServiceName,"Restore startup mode $($s.startMode)")){Set-Mode $s.startMode;if($s.state -eq 'Running' -and (Get-Service $ServiceName).Status -ne 'Running'){Start-Service $ServiceName}}
   $after=Get-Candidate
   if($after.StartMode -ne $s.startMode){throw 'Rollback verification failed'}
   Write-Event 'rolled-back' @{startMode=$after.StartMode;state=$after.State}
 }
}

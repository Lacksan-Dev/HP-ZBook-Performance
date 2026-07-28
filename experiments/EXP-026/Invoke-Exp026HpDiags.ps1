[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
  [string]$Action='Check',
  [string]$StatePath="$PSScriptRoot\state.json",
  [string]$LogPath="$PSScriptRoot\events.jsonl"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ServiceName='HPDiagsCap'

function Write-Event([string]$Event,[hashtable]$Data){
  $parent=Split-Path -Parent $LogPath
  if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $row=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-026';action=$Action;event=$Event;computer=$env:COMPUTERNAME;data=$Data}
  ($row|ConvertTo-Json -Compress -Depth 8)|Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-Candidate {
  $os=Get-CimInstance Win32_OperatingSystem
  $cs=Get-CimInstance Win32_ComputerSystem
  if($os.Caption -notmatch 'Windows 11' -or $cs.Manufacturer -notmatch 'HP|Hewlett-Packard'){throw 'Unsupported platform'}
  $svc=Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
  if(-not $svc){throw 'Candidate service absent'}
  if($svc.Name -ne $ServiceName){throw 'Service name identity refused'}
  if($svc.PathName -notmatch '(?i)HP.*Diag|Diag.*Cap'){throw 'Service executable identity refused'}
  if($svc.PathName -match '(?i)Defender|SecurityHealth|BitLocker|Credential|Tailscale|Omnissa|RemoteDesktop|WindowsApp|Windows Update'){throw 'Protected identity refused'}
  $svc
}

function Save-State($svc){
  $parent=Split-Path -Parent $StatePath
  if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $state=[ordered]@{schema=1;experiment='EXP-026';computer=$env:COMPUTERNAME;service=$svc.Name;displayName=$svc.DisplayName;path=$svc.PathName;startMode=$svc.StartMode;state=$svc.State;capturedUtc=(Get-Date).ToUniversalTime().ToString('o')}
  $state|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $StatePath -Encoding UTF8
  Write-Event 'state-captured' @{service=$svc.Name;startMode=$svc.StartMode;state=$svc.State;path=$svc.PathName}
  $state
}

function Read-State {
  if(-not(Test-Path -LiteralPath $StatePath)){throw 'State file missing'}
  $s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
  if($s.schema -ne 1 -or $s.experiment -ne 'EXP-026' -or $s.computer -ne $env:COMPUTERNAME -or $s.service -ne $ServiceName){throw 'State identity refused'}
  if([string]::IsNullOrWhiteSpace([string]$s.path) -or [string]::IsNullOrWhiteSpace([string]$s.startMode)){throw 'State content refused'}
  $s
}

function Convert-StartMode([string]$Mode){
  $map=@{Auto='Automatic';Automatic='Automatic';Manual='Manual';Disabled='Disabled'}
  if(-not $map.ContainsKey($Mode)){throw "Unsupported startup mode: $Mode"}
  $map[$Mode]
}

function Set-Mode([string]$Mode){Set-Service -Name $ServiceName -StartupType (Convert-StartMode $Mode)}

try {
  $svc=Get-Candidate
  switch($Action){
    'Check' {Write-Event 'supported' @{service=$svc.Name;path=$svc.PathName;startMode=$svc.StartMode;state=$svc.State};$svc|Select-Object Name,DisplayName,PathName,StartMode,State}
    'Capture' {Save-State $svc|Out-Null}
    'DryRun' {$state=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $svc};$plan=[ordered]@{supported=$true;service=$svc.Name;path=$svc.PathName;currentStartMode=$svc.StartMode;targetStartMode='Manual';currentState=$svc.State;statePath=$StatePath;wouldChange=($svc.StartMode -ne 'Manual')};Write-Event 'dry-run' $plan;[pscustomobject]$plan}
    'Apply' {
      if(-not(Test-Path -LiteralPath $StatePath)){Save-State $svc|Out-Null}
      if($svc.StartMode -eq 'Manual'){Write-Event 'already-applied' @{service=$svc.Name;state=$svc.State};break}
      if(-not $PSCmdlet.ShouldProcess($ServiceName,'Set startup mode to Manual')){Write-Event 'apply-declined' @{service=$svc.Name};break}
      Set-Mode 'Manual'
      $after=Get-Candidate
      if($after.StartMode -ne 'Manual'){throw 'Apply verification failed'}
      if($after.State -ne $svc.State){throw 'Apply changed running state unexpectedly'}
      Write-Event 'applied' @{before=$svc.StartMode;after=$after.StartMode;state=$after.State}
    }
    'Verify' {$after=Get-Candidate;$ok=($after.StartMode -eq 'Manual');Write-Event 'verified' @{manual=$ok;state=$after.State;path=$after.PathName};if(-not $ok){throw 'Verification failed'}}
    'VerifyReboot' {$after=Get-Candidate;$ok=($after.StartMode -eq 'Manual');Write-Event 'reboot-verified' @{manual=$ok;state=$after.State;path=$after.PathName};if(-not $ok){throw 'Reboot persistence failed'}}
    'Rollback' {
      $s=Read-State;$current=Get-Candidate
      if($current.PathName -ne $s.path -or $current.DisplayName -ne $s.displayName){throw 'Rollback service identity changed'}
      if(-not $PSCmdlet.ShouldProcess($ServiceName,"Restore startup mode $($s.startMode) and running state $($s.state)")){Write-Event 'rollback-declined' @{service=$ServiceName};break}
      Set-Mode $s.startMode
      $service=Get-Service -Name $ServiceName
      if($s.state -eq 'Running' -and $service.Status -ne 'Running'){Start-Service -Name $ServiceName}
      elseif($s.state -eq 'Stopped' -and $service.Status -ne 'Stopped'){Stop-Service -Name $ServiceName -Force}
      $after=Get-Candidate
      if($after.StartMode -ne $s.startMode -or $after.State -ne $s.state){throw 'Rollback verification failed'}
      Write-Event 'rolled-back' @{startMode=$after.StartMode;state=$after.State;path=$after.PathName}
    }
  }
}
catch {Write-Event 'failure' @{type=$_.Exception.GetType().FullName;message=$_.Exception.Message};throw}

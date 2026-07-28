[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
  [string]$Action='Check',
  [string]$StatePath="$PSScriptRoot\state.json",
  [string]$LogPath="$PSScriptRoot\events.jsonl"
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$ServiceName='HPPrintScanDoctorService'
$TargetStartMode='Manual'

function Write-Event([string]$Event,[hashtable]$Data){
  $parent=Split-Path -Parent $LogPath
  if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $row=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-030';action=$Action;event=$Event;computer=$env:COMPUTERNAME;data=$Data}
  ($row|ConvertTo-Json -Compress -Depth 8)|Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-ServiceState{
  $svc=Get-CimInstance Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
  if(-not $svc){throw "$ServiceName absent"}
  $path=[string]$svc.PathName
  if($path -notmatch '(?i)HP.*(Print|Scan).*Doctor|HPPrintScanDoctor'){throw 'Service executable identity refused'}
  [ordered]@{name=$svc.Name;displayName=$svc.DisplayName;pathName=$path;startMode=$svc.StartMode;state=$svc.State;processId=[int]$svc.ProcessId}
}
function Get-Support{
  $os=Get-CimInstance Win32_OperatingSystem
  $cs=Get-CimInstance Win32_ComputerSystem
  if($os.Caption -notmatch 'Windows 11' -or $cs.Manufacturer -notmatch 'HP|Hewlett-Packard'){throw 'Unsupported platform'}
  [ordered]@{service=(Get-ServiceState);os=$os.Caption;manufacturer=$cs.Manufacturer}
}
function Save-State($support){
  $parent=Split-Path -Parent $StatePath
  if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $state=[ordered]@{schema=1;experiment='EXP-030';computer=$env:COMPUTERNAME;serviceName=$ServiceName;original=$support.service;capturedUtc=(Get-Date).ToUniversalTime().ToString('o')}
  $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding UTF8
  Write-Event 'state-captured' @{original=$support.service}
  $state
}
function Read-State{
  if(-not(Test-Path -LiteralPath $StatePath)){throw 'State file missing'}
  $s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
  if($s.schema -ne 1 -or $s.experiment -ne 'EXP-030' -or $s.computer -ne $env:COMPUTERNAME -or $s.serviceName -ne $ServiceName){throw 'State identity refused'}
  $s
}
function Set-StartMode([string]$Mode){
  $result=Invoke-CimMethod -InputObject (Get-CimInstance Win32_Service -Filter "Name='$ServiceName'") -MethodName ChangeStartMode -Arguments @{StartMode=$Mode}
  if($result.ReturnValue -ne 0){throw "ChangeStartMode failed: $($result.ReturnValue)"}
}
try{
  $support=Get-Support
  switch($Action){
    'Check'{Write-Event 'supported' @{service=$support.service};[pscustomobject]$support}
    'Capture'{Save-State $support|Out-Null}
    'DryRun'{if(-not(Test-Path -LiteralPath $StatePath)){Save-State $support|Out-Null};$plan=[ordered]@{supported=$true;service=$support.service;targetStartMode=$TargetStartMode;wouldChange=($support.service.startMode -ne $TargetStartMode);runningStatePreserved=$true};Write-Event 'dry-run' $plan;[pscustomobject]$plan}
    'Apply'{
      if(-not(Test-Path -LiteralPath $StatePath)){Save-State $support|Out-Null}
      if($support.service.startMode -eq $TargetStartMode){Write-Event 'already-applied' @{service=$support.service};break}
      if(-not $PSCmdlet.ShouldProcess($ServiceName,"Set startup mode to $TargetStartMode")){Write-Event 'apply-declined' @{};break}
      $beforeState=$support.service.state
      Set-StartMode $TargetStartMode
      $after=Get-ServiceState
      if($after.startMode -ne $TargetStartMode -or $after.state -ne $beforeState){throw 'Apply verification failed'}
      Write-Event 'applied' @{before=$support.service;after=$after}
    }
    'Verify'{
      $after=Get-ServiceState;$ok=$after.startMode -eq $TargetStartMode
      Write-Event 'verified' @{ok=$ok;current=$after};if(-not $ok){throw 'Verification failed'}
    }
    'VerifyReboot'{
      $after=Get-ServiceState;$ok=$after.startMode -eq $TargetStartMode
      Write-Event 'reboot-verified' @{ok=$ok;current=$after};if(-not $ok){throw 'Reboot persistence failed'}
    }
    'Rollback'{
      $s=Read-State;$current=Get-ServiceState
      if($current.pathName -ne $s.original.pathName -or $current.displayName -ne $s.original.displayName){throw 'Rollback service identity changed'}
      if(-not $PSCmdlet.ShouldProcess($ServiceName,'Restore exact captured startup and running state')){Write-Event 'rollback-declined' @{};break}
      Set-StartMode ([string]$s.original.startMode)
      $svc=Get-Service -Name $ServiceName
      if($s.original.state -eq 'Running' -and $svc.Status -ne 'Running'){Start-Service -Name $ServiceName}
      elseif($s.original.state -ne 'Running' -and $svc.Status -eq 'Running'){Stop-Service -Name $ServiceName -Force}
      $after=Get-ServiceState
      $ok=$after.startMode -eq $s.original.startMode -and $after.state -eq $s.original.state -and $after.pathName -eq $s.original.pathName
      if(-not $ok){throw 'Rollback verification failed'}
      Write-Event 'rolled-back' @{restored=$after}
    }
  }
}catch{Write-Event 'failure' @{type=$_.Exception.GetType().FullName;message=$_.Exception.Message};throw}

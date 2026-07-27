[CmdletBinding(SupportsShouldProcess)]
param([ValidateSet('Check','DryRun','Apply','Verify','Rollback')][string]$Mode='Check',[string]$StatePath="$PSScriptRoot/state.json",[string]$LogPath="$PSScriptRoot/exp-014.jsonl",[int]$TimeoutSeconds=20)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Write-Log($Action,$Result,$Data){([ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-014';action=$Action;result=$Result;data=$Data}|ConvertTo-Json -Compress -Depth 5)|Add-Content -LiteralPath $LogPath -Encoding utf8}
function Get-EdgePath { $c=@("$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"); $p=$c|Where-Object{Test-Path $_}|Select-Object -First 1; if(!$p){throw 'Microsoft Edge executable absent.'}; $p }
function Get-OwnedState { if(!(Test-Path $StatePath)){throw 'Launch state absent.'}; $s=Get-Content $StatePath -Raw|ConvertFrom-Json; if($s.schema -ne 1 -or !$s.processId){throw 'Launch state invalid.'}; $s }
try{
 switch($Mode){
  'Check' { $p=Get-EdgePath; $r=[pscustomobject]@{Supported=$true;EdgePath=$p;ExistingEdgeProcesses=@(Get-Process msedge -ErrorAction SilentlyContinue).Count}; Write-Log Check Success $r; $r }
  'DryRun' { $p=Get-EdgePath; $r=[pscustomobject]@{WouldLaunch=$true;EdgePath=$p;Arguments='--new-window edge://newtab'}; Write-Log DryRun Success $r; $r }
  'Apply' { $p=Get-EdgePath; if(Test-Path $StatePath){$s=Get-Content $StatePath -Raw|ConvertFrom-Json; if(Get-Process -Id $s.processId -ErrorAction SilentlyContinue){Write-Log Apply Success @{idempotent=$true;processId=$s.processId}; return}}
    if($PSCmdlet.ShouldProcess($p,'Launch controlled Edge new-tab window')){$sw=[Diagnostics.Stopwatch]::StartNew();$proc=Start-Process -FilePath $p -ArgumentList '--new-window','edge://newtab' -PassThru; $visible=$false; do{Start-Sleep -Milliseconds 100;$proc.Refresh();$visible=$proc.MainWindowHandle -ne 0}while(!$visible -and $sw.Elapsed.TotalSeconds -lt $TimeoutSeconds -and !$proc.HasExited);$sw.Stop(); if($proc.HasExited){throw 'Edge exited before readiness.'}; [ordered]@{schema=1;processId=$proc.Id;edgePath=$p;launchedUtc=(Get-Date).ToUniversalTime().ToString('o');visibleWindow=$visible;visibleMilliseconds=$sw.ElapsedMilliseconds}|ConvertTo-Json|Set-Content $StatePath -Encoding utf8; Write-Log Apply Success @{processId=$proc.Id;visibleWindow=$visible;visibleMilliseconds=$sw.ElapsedMilliseconds}; if(!$visible){throw 'Visible-window readiness timeout.'}} }
  'Verify' { $s=Get-OwnedState; $p=Get-Process -Id $s.processId -ErrorAction SilentlyContinue; $ok=[bool]$p; Write-Log Verify $(if($ok){'Success'}else{'Failure'}) @{processId=$s.processId}; if(!$ok){throw 'Owned Edge process absent.'}; $p }
  'Rollback' { $s=Get-OwnedState; $p=Get-Process -Id $s.processId -ErrorAction SilentlyContinue; if($p -and $PSCmdlet.ShouldProcess("PID $($s.processId)",'Stop broker-owned Edge process')){Stop-Process -Id $s.processId -Force; Wait-Process -Id $s.processId -Timeout 10 -ErrorAction SilentlyContinue}; if(Get-Process -Id $s.processId -ErrorAction SilentlyContinue){throw 'Rollback verification failed.'}; Remove-Item $StatePath -Force; Write-Log Rollback Success @{processId=$s.processId} }
 }
}catch{Write-Log $Mode Failure @{message=$_.Exception.Message};throw}

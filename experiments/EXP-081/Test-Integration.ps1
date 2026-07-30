[CmdletBinding()]
param([string]$OutputPath=(Join-Path $PSScriptRoot 'integration-result.json'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$scriptPath=Join-Path $PSScriptRoot 'Invoke-SetPointStartupCalibration.ps1'
$state=Join-Path $env:TEMP 'EXP-081-integration-state.json'
$log=Join-Path $env:TEMP 'EXP-081-integration-events.jsonl'
Remove-Item $state,$log -Force -ErrorAction SilentlyContinue
$before=@{}
foreach($p in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'){
 if(Test-Path $p){$k=Get-Item $p;$before[$p]=@($k.GetValueNames()|ForEach-Object{"$_=$($k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames))"})}
}
$check=& $scriptPath -Action Check -StatePath $state -LogPath $log
$dryRunError=$null
try{& $scriptPath -Action DryRun -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{$dryRunError=$_.Exception.Message}
$after=@{}
foreach($p in $before.Keys){$k=Get-Item $p;$after[$p]=@($k.GetValueNames()|ForEach-Object{"$_=$($k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames))"})}
$mutated=$false
foreach($p in $before.Keys){if((Compare-Object $before[$p] $after[$p])){$mutated=$true}}
$result=[ordered]@{experiment='EXP-081';timestampUtc=(Get-Date).ToUniversalTime().ToString('o');candidateCount=@($check).Count;dryRunError=$dryRunError;zeroMutation=(-not $mutated);stateCreated=(Test-Path $state);logCreated=(Test-Path $log)}
$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $OutputPath -Encoding UTF8
if($mutated){throw'Zero-mutation integration check detected a registry change.'}
$result

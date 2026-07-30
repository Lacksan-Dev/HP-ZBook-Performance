[CmdletBinding()]
param([string]$OutputRoot=(Join-Path $PSScriptRoot 'integration-output'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$tool=Join-Path $PSScriptRoot 'Invoke-WindowsSearchHighlightsPolicyCalibration.ps1'
New-Item -ItemType Directory -Path $OutputRoot -Force|Out-Null
$state=Join-Path $OutputRoot 'state.json';$log=Join-Path $OutputRoot 'events.jsonl'
& $tool -Action Check -StatePath $state -LogPath $log|ConvertTo-Json -Depth 12|Set-Content (Join-Path $OutputRoot 'check.json') -Encoding UTF8
& $tool -Action DryRun -StatePath $state -LogPath $log|ConvertTo-Json -Depth 12|Set-Content (Join-Path $OutputRoot 'dry-run.json') -Encoding UTF8
Write-Host 'Zero-mutation integration completed. On an eligible unmanaged HP Windows 11 lab machine, run Capture, Apply, Verify, reboot, VerifyReboot, validate local app/setting/file search and protected applications, then Rollback. Preserve every failed or inconclusive result.'

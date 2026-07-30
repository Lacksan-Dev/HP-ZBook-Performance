[CmdletBinding()]
param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot 'Invoke-LogitechDownloadAssistantCalibration.ps1'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'integration-output')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) { throw "Script missing: $ScriptPath" }
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

$before = Get-Date
$statePath = Join-Path $OutputPath 'state.json'
$logPath = Join-Path $OutputPath 'events.jsonl'

$checkResult = & $ScriptPath -Action Check -StatePath $statePath -LogPath $logPath
$dryRunResult = $null
$dryRunError = $null
try {
    $dryRunResult = & $ScriptPath -Action DryRun -StatePath $statePath -LogPath $logPath
} catch {
    $dryRunError = $_.Exception.Message
}

$after = Get-Date
$report = [ordered]@{
    experiment = 'EXP-080'
    startedUtc = $before.ToUniversalTime().ToString('o')
    completedUtc = $after.ToUniversalTime().ToString('o')
    mode = 'zero-mutation'
    checkCount = @($checkResult).Count
    dryRunSucceeded = [bool]$dryRunResult
    dryRunError = $dryRunError
    stateCreated = Test-Path -LiteralPath $statePath
    logCreated = Test-Path -LiteralPath $logPath
    mutationActionsInvoked = @()
}

$reportPath = Join-Path $OutputPath 'integration-report.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding UTF8
$report

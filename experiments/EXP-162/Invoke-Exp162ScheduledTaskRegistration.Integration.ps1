#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$TaskName,
    [string]$TaskPath,
    [string]$ExpectedExecutableSha256
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$provider = Join-Path $PSScriptRoot 'Invoke-Exp162ScheduledTaskRegistration.ps1'

if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) {
    Write-Output 'SKIP: EXP-162 integration requires Windows ScheduledTasks.'
    exit 0
}
if ([string]::IsNullOrWhiteSpace($TaskName) -or [string]::IsNullOrWhiteSpace($TaskPath) -or [string]::IsNullOrWhiteSpace($ExpectedExecutableSha256)) {
    Write-Output 'SKIP: supply TaskName, TaskPath, and ExpectedExecutableSha256 from sanitized EXP-143 inventory evidence.'
    exit 0
}

$before = Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
$root = Join-Path $env:TEMP ('Lacksan-EXP162-Integration-' + [guid]::NewGuid().ToString('N'))
$state = Join-Path $root 'state.json'
$log = Join-Path $root 'events.jsonl'
try {
    & $provider -Action Check -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedExecutableSha256 -StatePath $state -LogPath $log -SelfManagedLab | Out-Null
    & $provider -Action DryRun -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedExecutableSha256 -StatePath $state -LogPath $log -SelfManagedLab | Out-Null
    & $provider -Action Capture -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedExecutableSha256 -StatePath $state -LogPath $log -SelfManagedLab | Out-Null
    & $provider -Action Apply -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedExecutableSha256 -StatePath $state -LogPath $log -SelfManagedLab -WhatIf | Out-Null
    $after = Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
    if ($before -ne $after) { throw 'Zero-mutation integration contract failed: scheduled task XML changed.' }
    Write-Output 'PASS: Check, DryRun, Capture, and Apply -WhatIf left the selected task unchanged.'
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}

#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$tool = (Resolve-Path (Join-Path $PSScriptRoot '..\Lacksan-ZBook-Performance.ps1')).Path
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$failures = New-Object Collections.Generic.List[string]

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($tool, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -gt 0) {
    foreach ($errorItem in $parseErrors) {
        $failures.Add("Parse: $($errorItem.Message)")
    }
}

foreach ($testMode in @('SelfTest', 'Audit', 'Preview', 'Configuration')) {
    $output = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool -Mode $testMode 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("$testMode exited $LASTEXITCODE`: $($output -join ' ')")
    }
}

$whatIfOutput = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool -Mode Apply -WhatIf 2>&1
if ($LASTEXITCODE -ne 0) {
    $failures.Add("Apply -WhatIf exited $LASTEXITCODE`: $($whatIfOutput -join ' ')")
}
if (($whatIfOutput -join "`n") -notmatch 'No backup or setting is written') {
    $failures.Add('Apply -WhatIf did not report the dry-run safety boundary.')
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'All static and read-only integration tests passed.'

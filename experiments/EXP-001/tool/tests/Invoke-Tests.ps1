#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$tool = (Resolve-Path (Join-Path $PSScriptRoot '..\Lacksan-ZBook-Performance.ps1')).Path
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$failures = New-Object Collections.Generic.List[string]

$tokens = $null
$parseErrors = $null
$toolAst = [Management.Automation.Language.Parser]::ParseFile($tool, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -gt 0) {
    foreach ($errorItem in $parseErrors) {
        $failures.Add("Parse: $($errorItem.Message)")
    }
}

foreach ($testMode in @('SelfTest', 'Audit', 'Preview', 'Configuration', 'Check', 'Settings', 'Backups')) {
    $output = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool -Mode $testMode 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("$testMode exited $LASTEXITCODE`: $($output -join ' ')")
    }
    if ($testMode -in @('Audit', 'Check') -and ($output -join "`n") -notmatch 'Restart test:') {
        $failures.Add("$testMode did not report the one-time auto-login safety state.")
    }
}

$whatIfOutput = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool -Mode Apply -WhatIf 2>&1
if ($LASTEXITCODE -ne 0) {
    $failures.Add("Apply -WhatIf exited $LASTEXITCODE`: $($whatIfOutput -join ' ')")
}
if (($whatIfOutput -join "`n") -notmatch 'No backup or setting is written') {
    $failures.Add('Apply -WhatIf did not report the dry-run safety boundary.')
}

foreach ($changingAction in @('FullTest', 'RestartTest', 'StopAutoLogin')) {
    $output = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool $changingAction -WhatIf 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("$changingAction -WhatIf exited $LASTEXITCODE`: $($output -join ' ')")
    }
    if (($output -join "`n") -notmatch 'No backup or setting is written') {
        $failures.Add("$changingAction -WhatIf did not report the dry-run safety boundary.")
    }
}

$benchmarkOutput = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool Benchmark -BenchmarkRuns 3 2>&1
if ($LASTEXITCODE -ne 0) {
    $failures.Add("Benchmark exited $LASTEXITCODE`: $($benchmarkOutput -join ' ')")
}
if (($benchmarkOutput -join "`n") -notmatch 'Raw results:') {
    $failures.Add('Benchmark did not preserve and report a raw-result file.')
}

$sourceText = Get-Content -LiteralPath $tool -Raw
if ($sourceText -match "Name 'DefaultPassword' -Type String -Value") {
    $failures.Add('Tool appears to write a plaintext Winlogon DefaultPassword.')
}
if ($sourceText -notmatch 'LsaStorePrivateData') {
    $failures.Add('Tool does not contain the required LSA-secret storage path.')
}
if ($sourceText -notmatch 'will not claim ownership or change that configuration automatically') {
    $failures.Add('Check does not preserve externally configured automatic sign-in.')
}
if ($sourceText -notmatch 'MatchingTaskStateValid') {
    $failures.Add('Check does not verify a matching recovery state record.')
}
if ($sourceText -notmatch 'Read-IntegrityProtectedJson -Path \$matchingTaskManifestPath') {
    $failures.Add('Check does not validate recovery-manifest integrity before offering cleanup.')
}
if ($sourceText -notmatch 'if \(-not \$safety\.ToolRecoveryAvailable\)') {
    $failures.Add('StopAutoLogin does not enforce recovery-record ownership at its action boundary.')
}
if ($sourceText -notmatch 'Get-RestartStateManifestPath -StateId \$safety\.TaskStateId') {
    $failures.Add('StopAutoLogin does not use the state ID from the active resume task.')
}
if ($sourceText -notmatch "Write-LabEvent -Event 'AutoLoginCleanupVerification' -Status 'Failure'") {
    $failures.Add('Auto-login cleanup does not preserve a structured verification failure.')
}
if ($sourceText -notmatch "Write-LabEvent -Event 'AutoLoginCleanupVerification' -Status 'Pass'") {
    $failures.Add('Auto-login cleanup does not record successful post-restore verification.')
}

foreach ($functionName in @('Write-IntegrityProtectedJson', 'Read-IntegrityProtectedJson')) {
    $functionAst = @(
        $toolAst.FindAll({
            param($node)
            $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
        }, $true)
    ) | Select-Object -First 1
    if ($null -eq $functionAst) {
        $failures.Add("Required function '$functionName' was not found for the manifest integrity test.")
    }
    else {
        Invoke-Expression $functionAst.Extent.Text
    }
}

$integrityTestRoot = Join-Path ([IO.Path]::GetTempPath()) ('Lacksan-ZBookPerformance-IntegrityTest-' + [guid]::NewGuid().ToString('N'))
$integrityTestPath = Join-Path $integrityTestRoot 'restart-state.json'
try {
    New-Item -ItemType Directory -Path $integrityTestRoot -ErrorAction Stop | Out-Null
    $testState = [ordered]@{
        SchemaVersion = 1
        StateId = 'integrity-test-state'
        TaskName = 'Lacksan-ZBookPerformance-Resume'
    }
    Write-IntegrityProtectedJson -Value $testState -Path $integrityTestPath
    $roundTrip = Read-IntegrityProtectedJson -Path $integrityTestPath
    if (
        [string]$roundTrip.StateId -cne [string]$testState.StateId -or
        [string]$roundTrip.TaskName -cne [string]$testState.TaskName
    ) {
        $failures.Add('Recovery-manifest integrity round trip changed the state identity.')
    }

    [IO.File]::AppendAllText($integrityTestPath, [Environment]::NewLine)
    $corruptionRejected = $false
    try {
        [void](Read-IntegrityProtectedJson -Path $integrityTestPath)
    }
    catch {
        $corruptionRejected = $true
    }
    if (-not $corruptionRejected) {
        $failures.Add('Recovery-manifest checksum validation accepted a modified JSON file.')
    }
}
catch {
    $failures.Add("Recovery-manifest integrity test failed: $($_.Exception.Message)")
}
finally {
    Remove-Item -LiteralPath ($integrityTestPath + '.sha256') -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $integrityTestPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $integrityTestRoot -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'All static and non-destructive integration tests passed.'

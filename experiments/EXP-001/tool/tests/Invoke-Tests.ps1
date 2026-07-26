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
    if ($testMode -in @('Audit', 'Check') -and ($output -join "`n") -notmatch 'Sign-in details:') {
        $failures.Add("$testMode did not report the low-friction sign-in privacy state.")
    }
    if ($testMode -in @('Audit', 'Check')) {
        $stateMatch = [regex]::Match(($output -join "`n"), 'Tuning state: (APPLIED|NOT YET APPLIED) \((\d+) of (\d+) checks pass')
        if (-not $stateMatch.Success) {
            $failures.Add("$testMode did not report calculated passed/total tuning checks.")
        }
        elseif (
            [int]$stateMatch.Groups[2].Value -gt [int]$stateMatch.Groups[3].Value -or
            [int]$stateMatch.Groups[3].Value -lt 1
        ) {
            $failures.Add("$testMode reported an invalid passed/total tuning count.")
        }
    }
}

$whatIfOutput = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool -Mode Apply -WhatIf 2>&1
if ($LASTEXITCODE -ne 0) {
    $failures.Add("Apply -WhatIf exited $LASTEXITCODE`: $($whatIfOutput -join ' ')")
}
if (($whatIfOutput -join "`n") -notmatch 'No backup or setting is written') {
    $failures.Add('Apply -WhatIf did not report the dry-run safety boundary.')
}

foreach ($changingAction in @('FullTest', 'RestartTest', 'StopAutoLogin', 'Privacy', 'UndoPrivacy')) {
    $output = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool $changingAction -WhatIf 2>&1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("$changingAction -WhatIf exited $LASTEXITCODE`: $($output -join ' ')")
    }
    if (($output -join "`n") -notmatch 'No backup or setting is written') {
        $failures.Add("$changingAction -WhatIf did not report the dry-run safety boundary.")
    }
}

$privacyWhatIfOutput = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool Privacy -WhatIf 2>&1
if (
    ($privacyWhatIfOutput -join "`n") -notmatch 'display name' -or
    ($privacyWhatIfOutput -join "`n") -notmatch 'normal sign-in tile'
) {
    $failures.Add('Privacy -WhatIf did not clearly disclose that the display name remains visible.')
}
$privacyUndoWhatIfOutput = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool UndoPrivacy -WhatIf 2>&1
if (($privacyUndoWhatIfOutput -join "`n") -notmatch 'rollback preview') {
    $failures.Add('UndoPrivacy -WhatIf did not show the dedicated rollback preview.')
}

$benchmarkOutput = & $powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File $tool Benchmark -BenchmarkRuns 3 2>&1
if ($LASTEXITCODE -ne 0) {
    $failures.Add("Benchmark exited $LASTEXITCODE`: $($benchmarkOutput -join ' ')")
}
if (($benchmarkOutput -join "`n") -notmatch 'Raw results:') {
    $failures.Add('Benchmark did not preserve and report a raw-result file.')
}
$benchmarkText = $benchmarkOutput -join "`n"
if ($benchmarkText -notmatch 'Evidence class: PRE-PROTOCOL SCREENING') {
    $failures.Add('Benchmark did not visibly identify its pre-protocol evidence class.')
}
$rawResultMatch = [regex]::Match($benchmarkText, '(?m)^Raw results:\s+(.+?)\s*$')
if ($rawResultMatch.Success) {
    try {
        $rawResultRecord = Get-Content -LiteralPath $rawResultMatch.Groups[1].Value.Trim() -Raw | ConvertFrom-Json
        if ([string]$rawResultRecord.EvidenceClass -cne 'PreProtocolScreening') {
            $failures.Add('Benchmark JSON did not identify itself as pre-protocol screening evidence.')
        }
        if ($rawResultRecord.FormalBaselineEligible -ne $false) {
            $failures.Add('Benchmark JSON did not explicitly exclude itself from the formal baseline.')
        }
    }
    catch {
        $failures.Add("Benchmark evidence-class validation failed: $($_.Exception.Message)")
    }
}

$sourceText = Get-Content -LiteralPath $tool -Raw
if ($sourceText -match "Name 'DefaultPassword' -Type String -Value") {
    $failures.Add('Tool appears to write a plaintext Winlogon DefaultPassword.')
}
if ($sourceText -notmatch 'LsaStorePrivateData') {
    $failures.Add('Tool does not contain the required LSA-secret storage path.')
}
if ($sourceText -notmatch "Name = 'BlockUserFromShowingAccountDetailsOnSignin'") {
    $failures.Add('Tool does not declare the documented account-details sign-in policy.')
}
if ($sourceText -match "Name = 'DontDisplayLastUserName'") {
    $failures.Add('Low-friction privacy unexpectedly hides the full last-user identity.')
}
foreach ($privacyFunction in @('New-PrivacyBackup', 'Show-PrivacyPreview', 'Invoke-PrivacyApply', 'Invoke-PrivacyRollback')) {
    if ($sourceText -notmatch ('function ' + [regex]::Escape($privacyFunction))) {
        $failures.Add("Required sign-in privacy function '$privacyFunction' is missing.")
    }
}
foreach ($privacyEvent in @('PrivacyBackupCreated', 'PrivacyApplyVerification', 'PrivacyRollbackVerification')) {
    if ($sourceText -notmatch [regex]::Escape($privacyEvent)) {
        $failures.Add("Required structured privacy event '$privacyEvent' is missing.")
    }
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
if ($sourceText -match '17 of 17 checks pass') {
    $failures.Add('Check still contains a hard-coded tuning-state count.')
}
if ($sourceText -notmatch "Write-LabEvent -Event 'ConfigurationState'") {
    $failures.Add('Check does not structured-log its calculated configuration state.')
}
if ($sourceText -match 'PendingSettingCount = if \(\$Label -eq ''Before''\)') {
    $failures.Add('Benchmark aggregation still hard-codes the untuned pending-setting count.')
}
if ($sourceText -notmatch 'pending-setting counts are inconsistent') {
    $failures.Add('Benchmark aggregation does not reject inconsistent configuration counts.')
}
if ($sourceText -notmatch 'do not report configuration state') {
    $failures.Add('Benchmark aggregation does not reject mislabeled configuration blocks.')
}
if (([regex]::Matches($sourceText, 'EvidenceClass = \$script:ScreeningEvidenceClass')).Count -lt 3) {
    $failures.Add('Raw, aggregate, and comparison records do not all carry the screening evidence class.')
}
if (([regex]::Matches($sourceText, 'FormalBaselineEligible = \$script:FormalBaselineEligible')).Count -lt 3) {
    $failures.Add('Raw, aggregate, and comparison records do not all carry formal-baseline eligibility.')
}
if (([regex]::Matches($sourceText, 'Test-IsPreProtocolScreeningRecord -Record')).Count -lt 2) {
    $failures.Add('Derived benchmark records do not consistently validate input evidence provenance.')
}

foreach ($functionName in @('Write-IntegrityProtectedJson', 'Read-IntegrityProtectedJson', 'Get-Median', 'Test-IsPreProtocolScreeningRecord', 'Merge-BenchmarkBlocks', 'Find-LatestScreeningBenchmarkFile')) {
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

$aggregateTestRoot = Join-Path ([IO.Path]::GetTempPath()) ('Lacksan-ZBookPerformance-AggregateTest-' + [guid]::NewGuid().ToString('N'))
function Get-BenchmarkRoot {
    return $aggregateTestRoot
}
function New-SyntheticBenchmarkBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$ConfigurationState,
        [Parameter(Mandatory = $true)][int]$PendingSettingCount,
        [string]$Label
    )
    $recordLabel = if ([string]::IsNullOrWhiteSpace($Label)) {
        if ($ConfigurationState -ceq 'Untuned') { 'Before' } else { 'After' }
    }
    else {
        $Label
    }
    return [pscustomobject]@{
        Record = [pscustomobject]@{
            BenchmarkId = $Id
            Label = $recordLabel
            ConfigurationState = $ConfigurationState
            PendingSettingCount = $PendingSettingCount
            EvidenceClass = 'PreProtocolScreening'
            FormalBaselineEligible = $false
            Environment = [pscustomobject]@{ TestFixture = $true }
            Metrics = @(
                [pscustomobject]@{
                    Id = 'Synthetic'
                    Name = 'Synthetic metric'
                    Runs = @(
                        [pscustomobject]@{
                            Run = 1
                            Status = 'Pass'
                            Milliseconds = 1.0
                            Error = $null
                        }
                    )
                }
            )
        }
    }
}
try {
    New-Item -ItemType Directory -Path $aggregateTestRoot -ErrorAction Stop | Out-Null
    $script:ToolVersion = 'test'
    $script:RunId = [guid]::NewGuid().ToString('N')
    $script:ScreeningEvidenceClass = 'PreProtocolScreening'
    $script:FormalBaselineEligible = $false
    $consistentBlocks = @(
        New-SyntheticBenchmarkBlock -Id 'before-1' -ConfigurationState 'Untuned' -PendingSettingCount 3
        New-SyntheticBenchmarkBlock -Id 'before-2' -ConfigurationState 'Untuned' -PendingSettingCount 3
    )
    $aggregateResult = Merge-BenchmarkBlocks -Blocks $consistentBlocks -Label Before
    if ([int]$aggregateResult.Record.PendingSettingCount -ne 3) {
        $failures.Add('Benchmark aggregation did not preserve the observed pending-setting count.')
    }
    if (
        [string]$aggregateResult.Record.EvidenceClass -cne 'PreProtocolScreening' -or
        $aggregateResult.Record.FormalBaselineEligible -ne $false
    ) {
        $failures.Add('Benchmark aggregate was not explicitly excluded from the formal baseline.')
    }

    $unclassifiedBlocks = @(
        New-SyntheticBenchmarkBlock -Id 'before-unclassified-1' -ConfigurationState 'Untuned' -PendingSettingCount 3
        New-SyntheticBenchmarkBlock -Id 'before-unclassified-2' -ConfigurationState 'Untuned' -PendingSettingCount 3
    )
    $unclassifiedBlocks[1].Record.PSObject.Properties.Remove('EvidenceClass')
    $unclassifiedRejected = $false
    try {
        [void](Merge-BenchmarkBlocks -Blocks $unclassifiedBlocks -Label Before)
    }
    catch {
        $unclassifiedRejected = $_.Exception.Message -match 'lack explicit pre-protocol screening provenance'
    }
    if (-not $unclassifiedRejected) {
        $failures.Add('Benchmark aggregation accepted an input without explicit screening provenance.')
    }

    $validSelectionPath = Join-Path $aggregateTestRoot 'valid-screening-before.json'
    $invalidSelectionPath = Join-Path $aggregateTestRoot 'newer-unclassified-before.json'
    $validSelectionRecord = (New-SyntheticBenchmarkBlock -Id 'valid-screening-before' -ConfigurationState 'Untuned' -PendingSettingCount 3).Record
    $invalidSelectionRecord = (New-SyntheticBenchmarkBlock -Id 'newer-unclassified-before' -ConfigurationState 'Untuned' -PendingSettingCount 3).Record
    $invalidSelectionRecord.PSObject.Properties.Remove('FormalBaselineEligible')
    [IO.File]::WriteAllText($validSelectionPath, ($validSelectionRecord | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($invalidSelectionPath, ($invalidSelectionRecord | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    (Get-Item -LiteralPath $validSelectionPath).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(1)
    (Get-Item -LiteralPath $invalidSelectionPath).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(2)
    $selectedBeforeFile = Find-LatestScreeningBenchmarkFile -Root $aggregateTestRoot -ConfigurationState Untuned
    if ($null -eq $selectedBeforeFile -or $selectedBeforeFile.FullName -cne $validSelectionPath) {
        $failures.Add('Automatic comparison selection did not skip the newer unclassified benchmark file.')
    }

    $validTunedPath = Join-Path $aggregateTestRoot 'valid-screening-after.json'
    $restartTunedPath = Join-Path $aggregateTestRoot 'newer-after-restart.json'
    $validTunedRecord = (New-SyntheticBenchmarkBlock -Id 'valid-screening-after' -ConfigurationState 'Tuned' -PendingSettingCount 0).Record
    $restartTunedRecord = (New-SyntheticBenchmarkBlock -Id 'newer-after-restart' -ConfigurationState 'Tuned' -PendingSettingCount 0 -Label AfterRestart).Record
    [IO.File]::WriteAllText($validTunedPath, ($validTunedRecord | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($restartTunedPath, ($restartTunedRecord | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    (Get-Item -LiteralPath $validTunedPath).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(3)
    (Get-Item -LiteralPath $restartTunedPath).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(4)
    $selectedTunedFile = Find-LatestScreeningBenchmarkFile -Root $aggregateTestRoot -ConfigurationState Tuned
    if ($null -eq $selectedTunedFile -or $selectedTunedFile.FullName -cne $validTunedPath) {
        $failures.Add('Automatic comparison selection did not exclude the newer restart-test benchmark file.')
    }

    $inconsistentBlocks = @(
        New-SyntheticBenchmarkBlock -Id 'before-3' -ConfigurationState 'Untuned' -PendingSettingCount 3
        New-SyntheticBenchmarkBlock -Id 'before-4' -ConfigurationState 'Untuned' -PendingSettingCount 2
    )
    $inconsistentRejected = $false
    try {
        [void](Merge-BenchmarkBlocks -Blocks $inconsistentBlocks -Label Before)
    }
    catch {
        $inconsistentRejected = $_.Exception.Message -match 'pending-setting counts are inconsistent'
    }
    if (-not $inconsistentRejected) {
        $failures.Add('Benchmark aggregation accepted inconsistent pending-setting counts.')
    }
}
catch {
    $failures.Add("Benchmark aggregate test failed: $($_.Exception.Message)")
}
finally {
    if (Test-Path -LiteralPath $aggregateTestRoot) {
        Get-ChildItem -LiteralPath $aggregateTestRoot -File -ErrorAction SilentlyContinue |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
        Remove-Item -LiteralPath $aggregateTestRoot -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'All static and non-destructive integration tests passed.'

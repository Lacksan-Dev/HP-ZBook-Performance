$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sut = Join-Path $repoRoot 'ZBookPerf.ps1'
$core = Join-Path $repoRoot 'controller\core\ZBookPerf.Core.ps1'
$installer = Join-Path $repoRoot 'Install-UXROM.ps1'
$progress = Join-Path $repoRoot 'controller\ui\UxRomWorkProgress.ps1'
$layerIntegration = Join-Path $repoRoot 'controller\ui\UxRomLayerIntegration.ps1'
$stableValidation = Join-Path $repoRoot 'controller\release\UxRomStableValidation.ps1'
$stableApproval = Join-Path $repoRoot 'release\STABLE-APPROVAL-2026-08-02.md'
$source = Get-Content -LiteralPath $sut -Raw
$coreSource = Get-Content -LiteralPath $core -Raw
$installerSource = Get-Content -LiteralPath $installer -Raw
$progressSource = Get-Content -LiteralPath $progress -Raw
$layerSource = Get-Content -LiteralPath $layerIntegration -Raw
$stableSource = Get-Content -LiteralPath $stableValidation -Raw

Describe 'UX-ROM bootstrap contract' {
    It 'keeps the existing performance controller available through the core component' {
        $source | Should -Match 'controller\\core\\ZBookPerf.Core.ps1'
        $source | Should -Match 'Resolve-UxRomComponent'
        $source | Should -Match '\. \$core @forward'
        $source | Should -Match 'Invoke-ZBookPerfMain'
    }

    It 'preserves the ASCII UX-ROM product interface for normal launches' {
        $coreSource | Should -Match 'Show-UxRomHeader'
        $coreSource | Should -Match 'U X - R O M'
        $coreSource | Should -Match 'Loading the twelve performance layers'
        $source | Should -Match 'function Show-UxRomSplash'
        $source | Should -Match 'INDEXING LAYER'
        $source | Should -Match 'PERFORMANCE MAP ONLINE'
        $source | Should -Match 'Rendering command surface'
        $source | Should -Match 'function Show-ZBookPerfMenu'
        $source | Should -Match 'Full system diagnostics'
        $source | Should -Match 'Apply all eligible tweaks'
        $source | Should -Match 'Maintenance and direct measurement tools'
    }

    It 'animates interactive component fetching without delaying redirected automation' {
        $source | Should -Match 'Test-UxRomAnimationEnabled'
        $source | Should -Match '\[Console\]::IsOutputRedirected'
        $source | Should -Match 'Invoke-UxRomAnimatedDownload'
        $source | Should -Match 'DownloadFileTaskAsync'
        $source | Should -Match 'Start-Sleep -Milliseconds'
        $source | Should -Match 'if \(-not \(Test-UxRomAnimationEnabled\)\)'
    }

    It 'loads a restrained native PowerShell work-progress surface' {
        Test-Path -LiteralPath $progress | Should -BeTrue
        $source | Should -Match 'controller\\ui\\UxRomWorkProgress.ps1'
        $source | Should -Match '\. \$workProgress'
        $progressSource | Should -Match 'Write-Progress'
        $progressSource | Should -Match 'Preparing measurement session'
        $progressSource | Should -Match 'Reading Windows and hardware state'
        $progressSource | Should -Match 'Starting Windows performance trace'
        $progressSource | Should -Match 'samples captured'
        $progressSource | Should -Match 'SecondsRemaining'
        $progressSource | Should -Match 'Finalizing Windows performance trace'
        $progressSource | Should -Match 'Calculating measurement summary'
        $progressSource | Should -Match 'Saving evidence'
    }

    It 'shows work immediately for slow layer assessments and suppresses progress in redirected automation' {
        $progressSource | Should -Match 'UxRomCoreInvokeLayerAssessmentStep'
        $progressSource | Should -Match 'Running the required internal baseline'
        $progressSource | Should -Match 'Test-UxRomWorkProgressEnabled'
        $progressSource | Should -Match '\[Console\]::IsOutputRedirected'
        $progressSource | Should -Match 'Write-UxRomWorkProgress -Activity \$activity -Completed'
    }

    It 'keeps Layer 5 visibly active through its synchronous counter windows' {
        $progressSource | Should -Match 'function Invoke-KernelProfile'
        $progressSource | Should -Match 'Layer 5 kernel-pressure profile'
        $progressSource | Should -Match 'Checking required performance counters'
        $progressSource | Should -Match 'Calibrating counter observer'
        $progressSource | Should -Match 'Collecting block \$blockNumber of \$BlockCount'
        $progressSource | Should -Match 'Completed block \$blockNumber of \$BlockCount'
        $progressSource | Should -Match 'Reading Windows environment'
        $progressSource | Should -Match 'Checking trace-tool availability'
        $progressSource | Should -Match 'Calculating kernel-pressure summary'
        $progressSource | Should -Match 'Saving kernel-pressure evidence'
        $progressSource | Should -Match 'Get-KernelCounterBlock'
    }

    It 'preserves the measurement evidence contract while changing presentation only' {
        $progressSource | Should -Match "instrumentation = 'Get-Counter with CIM fallback; per-process CIM snapshots; optional WPR GeneralProfile \+ CPU \+ DiskIO'"
        $progressSource | Should -Match 'Join-Path \$Root ''session\.json'''
        $progressSource | Should -Match "Event 'measurement-complete'"
        $progressSource | Should -Match 'Show-MeasurementSummary -Measurement \$measurement'
        $progressSource | Should -Match 'Stop-WprCapture -Trace \$trace'
    }

    It 'preserves the Layer 5 evidence contract while changing presentation only' {
        $progressSource | Should -Match "kind = 'kernel-pressure-profile'"
        $progressSource | Should -Match "source = 'Local Windows performance counters through Get-Counter'"
        $progressSource | Should -Match "Event 'kernel-pressure-profile-complete'"
        $progressSource | Should -Match 'Get-KernelProfileSummary -Blocks \$blocks'
        $progressSource | Should -Match 'Get-KernelTraceToolState'
    }

    It 'runs an integrated layer assessment even when its legacy treatment list is empty' {
        Test-Path -LiteralPath $layerIntegration | Should -BeTrue
        $source | Should -Match 'controller\\ui\\UxRomLayerIntegration.ps1'
        $source | Should -Match '\. \$layerIntegration'
        $layerSource | Should -Match "if \(\[string\]\$layer\.assessment -ne 'NotIntegrated'\)"
        $layerSource | Should -Match 'Invoke-LayerAssessmentStep @Runtime'
        $layerSource | Should -Match 'Assessment complete\.'
        $layerSource | Should -Match 'Physical Validation / Stable Promotion providers'
        $layerSource.IndexOf('Invoke-LayerAssessmentStep @Runtime') | Should -BeLessThan $layerSource.IndexOf('if (-not $candidate)')
    }

    It 'integrates human-approved Physical Validation and Stable Promotion into the main UX-ROM menu' {
        Test-Path -LiteralPath $stableValidation | Should -BeTrue
        Test-Path -LiteralPath $stableApproval | Should -BeTrue
        $source | Should -Match 'controller\\release\\UxRomStableValidation.ps1'
        $source | Should -Match '\. \$stableValidation'
        $source | Should -Match 'V\. Physical Validation / Stable Promotion'
        $source | Should -Match 'Show-UxRomStableValidationMenu -Root \$DataRoot'
        $stableSource | Should -Match 'STABLE-APPROVAL-2026-08-02'
        $stableSource | Should -Match 'Get-UxRomMergedProviderCatalog'
        $stableSource | Should -Match 'contents/controller/providers\?ref=main'
        $stableSource | Should -Match "'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'"
        $stableSource | Should -Match 'Physical mechanics validated / performance evidence may still be required'
        $stableSource | Should -Match 'stableClaim=\$false'
    }

    It 'never converts human approval into fabricated physical evidence' {
        $approvalSource = Get-Content -LiteralPath $stableApproval -Raw
        $approvalSource | Should -Match 'does not manufacture or substitute physical evidence'
        $approvalSource | Should -Match 'Stable approved / physical validation pending'
        $stableSource | Should -Match 'five baseline and five treatment runs'
        $stableSource | Should -Match 'rebootVerified=\$true'
        $stableSource | Should -Match 'rollbackExecuted=\$true'
    }

    It 'exposes EXP-137 inside the same UX-ROM menu and as a direct action' {
        $source | Should -Match "'EnrollmentCleanup'"
        $source | Should -Match 'SelfManagedEnrollmentConfirmed'
        $source | Should -Match 'controller\\maintenance\\UxRomEnrollmentCleanup.ps1'
        $source | Should -Match 'E\. Self-managed enrollment cleanup'
        $source | Should -Match 'Invoke-EnrollmentMaintenance -Mode Start'
    }

    It 'keeps standalone-download compatibility through a cached component resolver' {
        $source | Should -Match 'raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main'
        $source | Should -Match 'Invoke-WebRequest -UseBasicParsing'
        $source | Should -Match "Join-Path \$DataRoot 'runtime'"
    }

    It 'provides an animated installer for first-run deployment' {
        Test-Path -LiteralPath $installer | Should -BeTrue
        $installerSource | Should -Match 'LACKSAN UX-ROM DEPLOYMENT'
        $installerSource | Should -Match 'Authorizing session'
        $installerSource | Should -Match 'FETCHING UX-ROM'
        $installerSource | Should -Match 'Unsealing package'
        $installerSource | Should -Match 'Transferring control'
        $installerSource | Should -Match 'Set-ExecutionPolicy -Scope Process'
        $installerSource | Should -Match 'Unblock-File'
    }

    It 'parses every new release-surface PowerShell file' {
        foreach ($path in @($sut,$layerIntegration,$stableValidation)) {
            $tokens=$null;$errors=$null
            [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
            @($errors).Count | Should -Be 0 -Because "$path must remain valid Windows PowerShell"
        }
    }
}

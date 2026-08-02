$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sut = Join-Path $repoRoot 'ZBookPerf.ps1'
$core = Join-Path $repoRoot 'controller\core\ZBookPerf.Core.ps1'
$source = Get-Content -LiteralPath $sut -Raw
$coreSource = Get-Content -LiteralPath $core -Raw

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
        $source | Should -Match 'function Show-ZBookPerfMenu'
        $source | Should -Match 'Full system diagnostics'
        $source | Should -Match 'Apply all eligible tweaks'
        $source | Should -Match 'Maintenance and direct measurement tools'
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
}

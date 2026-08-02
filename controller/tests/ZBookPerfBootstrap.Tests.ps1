$sut = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'ZBookPerf.ps1'
$source = Get-Content -LiteralPath $sut -Raw

Describe 'UX-ROM bootstrap contract' {
    It 'keeps the existing performance controller available through the core component' {
        $source | Should -Match 'controller\\core\\ZBookPerf.Core.ps1'
        $source | Should -Match 'Resolve-UxRomComponent'
        $source | Should -Match '& \$core @forward'
    }

    It 'exposes the EXP-137 maintenance action from the UX-ROM entrypoint' {
        $source | Should -Match "'EnrollmentCleanup'"
        $source | Should -Match 'SelfManagedEnrollmentConfirmed'
        $source | Should -Match 'controller\\maintenance\\UxRomEnrollmentCleanup.ps1'
    }

    It 'keeps standalone-download compatibility through a cached component resolver' {
        $source | Should -Match 'raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main'
        $source | Should -Match 'Invoke-WebRequest -UseBasicParsing'
        $source | Should -Match "Join-Path \$DataRoot 'runtime'"
    }
}

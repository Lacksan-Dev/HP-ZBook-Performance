Describe 'EXP-057 Logi Tune removal contract' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\experiments\EXP-057\LogiTuneRemoval.ps1'
        $content = Get-Content -LiteralPath $scriptPath -Raw
    }

    It 'parses as PowerShell' {
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'exposes all required actions' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $content | Should -Match ([regex]::Escape("'$action'"))
        }
    }

    It 'requires exact product identity and offline rollback media' {
        $content | Should -Match "DisplayName -eq \$productName"
        $content | Should -Match "Publisher -match '\^Logitech'"
        $content | Should -Match 'Get-FileHash'
        $content | Should -Match 'matching offline installer'
    }

    It 'preserves drivers by avoiding device and driver mutation commands' {
        $content | Should -Not -Match 'pnputil\s+/delete-driver'
        $content | Should -Not -Match 'Remove-PnpDevice'
        $content | Should -Not -Match 'Disable-PnpDevice'
    }

    It 'provides logging idempotence and exact rollback verification' {
        $content | Should -Match 'ConvertTo-Json -Compress'
        $content | Should -Match 'already-applied'
        $content | Should -Match 'already-restored'
        $content | Should -Match 'Exact-version rollback verification failed'
    }
}

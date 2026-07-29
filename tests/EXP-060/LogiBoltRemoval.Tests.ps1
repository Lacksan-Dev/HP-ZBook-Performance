Describe 'EXP-060 Logi Bolt removal contract' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\experiments\EXP-060\LogiBoltRemoval.ps1'
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

    It 'requires strict product identity rollback media and management refusal' {
        $content | Should -Match 'Logi\(\?:tech\)\? Bolt'
        $content | Should -Match 'Logitech\|Logi'
        $content | Should -Match 'EnterpriseManaged'
        $content | Should -Match 'Get-FileHash'
        $content | Should -Match 'matching offline installer'
    }

    It 'preserves devices drivers firmware pairing and protected applications by avoiding mutation commands' {
        $content | Should -Not -Match 'pnputil\s+/delete-driver'
        $content | Should -Not -Match 'Remove-PnpDevice'
        $content | Should -Not -Match 'Disable-PnpDevice'
        $content | Should -Not -Match 'Update-PnpDevice'
        $content | Should -Not -Match 'Remove-BluetoothDevice'
        $content | Should -Not -Match 'Omnissa|Windows App|Remote Desktop|Tailscale.*(?:Remove|Disable|Stop)'
    }

    It 'provides structured logging idempotence failure handling and exact rollback verification' {
        $content | Should -Match 'ConvertTo-Json -Compress'
        $content | Should -Match 'already-applied'
        $content | Should -Match 'already-restored'
        $content | Should -Match "Write-Event 'failure' 'error'"
        $content | Should -Match 'Exact-version rollback verification failed'
        $content | Should -Match 'productCode'
    }
}

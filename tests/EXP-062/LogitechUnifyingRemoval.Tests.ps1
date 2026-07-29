Describe 'EXP-062 Logitech Unifying removal contract' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\experiments\EXP-062\LogitechUnifyingRemoval.ps1'
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

    It 'requires strict product identity rollback media management refusal and unsafe command refusal' {
        $content | Should -Match 'Logitech\\s\+Unifying'
        $content | Should -Match 'publisherPattern'
        $content | Should -Match 'EnterpriseManaged'
        $content | Should -Match 'Get-FileHash'
        $content | Should -Match 'matching offline installer'
        $content | Should -Match 'UnsafeUninstallCommand'
        $content | Should -Match 'pnputil|remove-driver|devcon'
    }

    It 'preserves receiver pairing devices drivers firmware and protected applications by avoiding mutation commands' {
        $content | Should -Not -Match 'pnputil\s+/delete-driver'
        $content | Should -Not -Match 'Remove-PnpDevice'
        $content | Should -Not -Match 'Disable-PnpDevice'
        $content | Should -Not -Match 'Update-PnpDevice'
        $content | Should -Not -Match 'Remove-BluetoothDevice'
        $content | Should -Not -Match 'Omnissa|Windows App|Remote Desktop|Tailscale.*(?:Remove|Disable|Stop)'
    }

    It 'provides structured logging idempotence failure handling reboot verification and exact rollback verification' {
        $content | Should -Match 'ConvertTo-Json -Compress'
        $content | Should -Match 'already-applied'
        $content | Should -Match 'already-restored'
        $content | Should -Match "Write-Event 'failure' 'error'"
        $content | Should -Match "'VerifyReboot'"
        $content | Should -Match 'Exact-version rollback verification failed'
        $content | Should -Match 'productCode'
    }
}

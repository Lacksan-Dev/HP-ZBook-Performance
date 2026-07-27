BeforeAll {
    $ScriptPath = Join-Path $PSScriptRoot '..\experiments\EXP-020\OfficeBackgroundTaskRegistration.ps1'
    $Source = Get-Content -LiteralPath $ScriptPath -Raw
}

Describe 'EXP-020 engineering contract' {
    It 'uses the exact Office task identity' {
        $Source | Should -Match "Office Background Task Handler Registration"
        $Source | Should -Match "\\Microsoft\\Office\\"
    }

    It 'implements all required modes' {
        foreach ($mode in 'Check','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $Source | Should -Match "'$mode'"
        }
    }

    It 'captures and validates rollback state integrity' {
        $Source | Should -Match 'xmlSha256'
        $Source | Should -Match 'Rollback state identity mismatch'
        $Source | Should -Match 'Rollback state integrity check failed'
    }

    It 'uses ShouldProcess for live changes' {
        $Source | Should -Match 'SupportsShouldProcess=\$true'
        $Source | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'has support detection and structured logging' {
        $Source | Should -Match 'Windows 11'
        $Source | Should -Match 'HP\|Hewlett'
        $Source | Should -Match 'ConvertTo-Json -Compress'
    }

    It 'limits changes to task enablement' {
        $Source | Should -Match 'Disable-ScheduledTask'
        $Source | Should -Match 'Enable-ScheduledTask'
        $Source | Should -Not -Match 'Unregister-ScheduledTask'
        $Source | Should -Not -Match 'Remove-Item'
        $Source | Should -Not -Match 'Set-Service'
    }
}

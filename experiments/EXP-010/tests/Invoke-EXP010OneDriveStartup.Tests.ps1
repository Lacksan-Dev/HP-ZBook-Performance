$scriptPath = Join-Path $PSScriptRoot '..\Invoke-EXP010OneDriveStartup.ps1'
$source = Get-Content -LiteralPath $scriptPath -Raw

Describe 'EXP-010 OneDrive startup calibration contract' {
    It 'supports the required actions' {
        $source | Should -Match "Check','DryRun','Apply','Verify','Rollback','VerifyRollback"
    }

    It 'targets only the current-user OneDrive Run value' {
        $source | Should -Match "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
        $source | Should -Match "ValueName = 'OneDrive'"
    }

    It 'requires OneDrive executable command identity' {
        $source | Should -Match 'OneDrive\\\.exe'
        $source | Should -Match 'Refusing candidate'
    }

    It 'implements support detection and exact state capture' {
        $source | Should -Match 'Get-SupportState'
        $source | Should -Match 'Save-OriginalState'
        $source | Should -Match 'schemaVersion=1'
    }

    It 'implements structured logging and ShouldProcess' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match 'SupportsShouldProcess=\$true'
        $source | Should -Match '\$PSCmdlet.ShouldProcess'
    }

    It 'implements apply and rollback verification' {
        $source | Should -Match 'Apply verification failed'
        $source | Should -Match 'Rollback verification failed'
        $source | Should -Match 'VerifyRollback'
    }

    It 'contains no service, task, package, driver, or file deletion commands' {
        $source | Should -Not -Match 'Stop-Service|Set-Service|Disable-ScheduledTask|Uninstall-Package|pnputil|Remove-Item\s'
    }
}

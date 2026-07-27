BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\Invoke-TeamsRunCalibration.ps1'
    $source = Get-Content -LiteralPath $scriptPath -Raw
}

Describe 'EXP-016 engineering contract' {
    It 'uses ShouldProcess for destructive and restorative operations' {
        $source | Should -Match 'SupportsShouldProcess=\$true'
        $source | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'implements every required action' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $source | Should -Match "'$action'"
        }
    }

    It 'captures exact registry data and value kind' {
        $source | Should -Match 'GetValueKind'
        $source | Should -Match 'DoNotExpandEnvironmentNames'
        $source | Should -Match 'SetValue'
    }

    It 'requires Teams executable identity' {
        $source | Should -Match 'teams\\\.exe'
        $source | Should -Match 'Test-TeamsIdentity'
    }

    It 'protects required remote access and security identities' {
        foreach ($token in 'omnissa','windows app','remote desktop','tailscale','windows security','defender') {
            $source.ToLowerInvariant() | Should -Match [regex]::Escape($token)
        }
    }

    It 'does not uninstall packages or alter services and scheduled tasks' {
        $source | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|sc\.exe|Set-Service|Disable-ScheduledTask|Unregister-ScheduledTask'
    }

    It 'writes structured JSONL logs and records failures' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match "'failure' 'fail'"
    }

    It 'contains idempotent missing-value handling' {
        $source | Should -Match 'Remove-ItemProperty.+SilentlyContinue'
        $source | Should -Match 'Test-Removed'
    }
}

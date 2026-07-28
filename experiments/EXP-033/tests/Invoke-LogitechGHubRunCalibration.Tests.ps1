BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\Invoke-LogitechGHubRunCalibration.ps1'
    $source = Get-Content -LiteralPath $scriptPath -Raw
}

Describe 'EXP-033 engineering contract' {
    It 'uses ShouldProcess for removal and restoration' {
        $source | Should -Match 'SupportsShouldProcess=\$true'
        $source | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'implements every required action' {
        foreach ($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') {
            $source | Should -Match "'$action'"
        }
    }

    It 'captures exact unexpanded registry data and value kind' {
        $source | Should -Match 'DoNotExpandEnvironmentNames'
        $source | Should -Match 'GetValueKind'
        $source | Should -Match 'SetValue'
        $source | Should -Match 'userSid'
    }

    It 'requires exact Logitech G Hub background identity' {
        $source | Should -Match 'Test-LogitechGHubIdentity'
        $source | Should -Match 'lghub\\\.exe'
        $source | Should -Match '--background|--minimized'
        $source | Should -Match '\^\(LGHUB\|Logitech G HUB\|LogitechGHub\)\$'
    }

    It 'protects remote access, security, credentials, and BitLocker identities' {
        foreach ($token in 'omnissa','windows app','remote desktop','tailscale','windows security','defender','credential','bitlocker') {
            $source.ToLowerInvariant() | Should -Match [regex]::Escape($token)
        }
    }

    It 'limits scope to the current-user Run registration' {
        $source | Should -Match 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run'
        $source | Should -Not -Match 'HKLM:|RunOnce|StartupTask|Disable-ScheduledTask|Set-Service|sc\.exe'
    }

    It 'does not uninstall packages, delete files, or alter drivers' {
        $source | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Remove-Item\s+-LiteralPath.*\.exe|pnputil|devcon'
    }

    It 'writes structured JSONL logs and terminating failure evidence' {
        $source | Should -Match 'ConvertTo-Json -Compress'
        $source | Should -Match "'failure' 'fail'"
        $source | Should -Match '\$ErrorActionPreference = ''Stop'''
    }

    It 'is idempotent and refuses ambiguous candidates or rollback overwrite' {
        $source | Should -Match 'Remove-ItemProperty.+SilentlyContinue'
        $source | Should -Match 'More than one eligible'
        $source | Should -Match 'Rollback refused because the registration already exists'
        $source | Should -Match 'Test-Removed'
        $source | Should -Match 'Test-Restored'
    }
}

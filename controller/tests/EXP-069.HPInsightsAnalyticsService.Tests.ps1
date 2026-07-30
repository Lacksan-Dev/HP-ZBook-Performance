$providerPath = Join-Path $PSScriptRoot '..\providers\HPInsightsAnalyticsService.ps1'
$manifestPath = Join-Path $PSScriptRoot '..\lacksan.manifest.json'
$provider = Get-Content -LiteralPath $providerPath -Raw
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

Describe 'EXP-069 HP Insights Analytics provider contract' {
    It 'uses the exact experiment, provider, service, and executable identities' {
        $provider | Should -Match "experiment='EXP-069'"
        $provider | Should -Match "provider='hp-insights-analytics-service'"
        $provider | Should -Match "serviceName='HPTouchpointAnalyticsService'"
        $provider | Should -Match 'TouchpointAnalyticsClientService\\.exe'
        $provider | Should -Not -Match "experiment='EXP-068'"
    }

    It 'implements every required lifecycle action' {
        foreach ($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')) {
            $provider | Should -Match ([regex]::Escape("'$action'"))
        }
    }

    It 'captures exact identity and supports drift-safe rollback' {
        foreach ($token in @('ExecutableHash','ExecutableVersion','SignatureStatus','Signer','DelayedAutoStart','DependentServices','Assert-Identity','Rollback refused')) {
            $provider | Should -Match ([regex]::Escape($token))
        }
    }

    It 'preserves protected scopes and refuses policy, dependency, and active-use ambiguity' {
        foreach ($token in @('Get-ManagementSignals','DependencySafe','Get-ProtectedActivity','Elevation is required','Windows 11','Hewlett-Packard')) {
            $provider | Should -Match ([regex]::Escape($token))
        }
        $provider | Should -Not -Match 'Set-MpPreference|Disable-WindowsOptionalFeature|Remove-WindowsDriver|pnputil.+/delete-driver|Disable-NetAdapter|Set-NetFirewallProfile'
    }

    It 'supports dry run, ShouldProcess, JSONL logging, idempotence, verification, and exact rollback' {
        foreach ($token in @('SupportsShouldProcess','ShouldProcess','ConvertTo-Json -Compress','AlreadyApplied','MutationCount=0','Test-Applied','VerifyReboot','Restore exact startup and running state')) {
            $provider | Should -Match ([regex]::Escape($token))
        }
    }

    It 'is registered in the controller manifest' {
        ($manifest.providers.id) | Should -Contain 'hp-insights-analytics-service'
        ($manifest.profiles.id) | Should -Contain 'HPInsightsAnalyticsDemandStart'
        $entry = $manifest.providers | Where-Object id -eq 'hp-insights-analytics-service'
        $entry.mode | Should -Be 'Reversible'
        $entry.protectedScopes | Should -Contain 'WindowsSecurity'
        $entry.protectedScopes | Should -Contain 'DeviceCriticalDrivers'
        $entry.protectedScopes | Should -Contain 'Omnissa'
        $entry.protectedScopes | Should -Contain 'Tailscale'
    }
}

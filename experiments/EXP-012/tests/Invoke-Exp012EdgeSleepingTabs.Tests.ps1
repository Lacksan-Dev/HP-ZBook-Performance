$scriptPath = Join-Path $PSScriptRoot '..\Invoke-Exp012EdgeSleepingTabs.ps1'
$source = Get-Content -LiteralPath $scriptPath -Raw

Describe 'EXP-012 Edge Sleeping Tabs engineering contract' {
    It 'targets only the recommended SleepingTabsEnabled policy' {
        $source | Should -Match 'Edge\\Recommended'
        $source | Should -Match "ValueName = 'SleepingTabsEnabled'"
        $source | Should -Not -Match 'SleepingTabsTimeout'
        $source | Should -Not -Match 'StartupBoostEnabled'
        $source | Should -Not -Match 'BackgroundModeEnabled'
    }

    It 'includes support detection and mandatory-policy refusal' {
        $source | Should -Match 'Win32_OperatingSystem'
        $source | Should -Match 'Win32_ComputerSystem'
        $source | Should -Match 'Edge 88 or later'
        $source | Should -Match 'Mandatory enterprise SleepingTabsEnabled policy controls this setting'
    }

    It 'implements the complete reversible modification contract' {
        foreach ($required in @('Capture','DryRun','Apply','Verify','VerifyReboot','Rollback','ShouldProcess','Write-ExpLog','Set-StrictMode','ErrorActionPreference')) {
            $source | Should -Match ([regex]::Escape($required))
        }
    }

    It 'captures exact registry type and data for rollback' {
        $source | Should -Match 'GetValueKind'
        $source | Should -Match 'recommended = Get-RegistryValueState'
        $source | Should -Match 'Restore exact original state'
        $source | Should -Match 'Exact rollback verification failed'
    }

    It 'does not alter protected surfaces' {
        $source | Should -Not -Match 'Remove-AppxPackage|Uninstall|Stop-Service|Set-Service|Disable-WindowsOptionalFeature|Remove-Item.+Startup'
    }
}

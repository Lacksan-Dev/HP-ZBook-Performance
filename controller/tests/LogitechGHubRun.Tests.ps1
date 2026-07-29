Describe 'EXP-053 Logitech G Hub controller provider' {
    BeforeAll {
        $controllerRoot=Split-Path $PSScriptRoot -Parent
        $providerPath=Join-Path $controllerRoot 'providers/LogitechGHubRun.ps1'
        $manifestPath=Join-Path $controllerRoot 'lacksan.manifest.json'
    }
    It 'parses without PowerShell syntax errors' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
    }
    It 'exposes the full reversible action contract' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$content | Should -Match "'$action'"}
    }
    It 'limits mutation to the current-user Run key and recognized G Hub identities' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        $content | Should -Match [regex]::Escape('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')
        $content | Should -Match 'lghub_agent'
        $content | Should -Match 'lghub_updater'
        $content | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Remove-Service|pnputil|Set-MpPreference'
    }
    It 'registers a reversible profile with every protected scope' {
        $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
        $profile=@($manifest.profiles|Where-Object id -eq 'LogitechGHubDemandLaunch')
        $profile.Count | Should -Be 1
        @($profile[0].providers) | Should -Contain 'logitech-ghub-run'
        $provider=@($manifest.providers|Where-Object id -eq 'logitech-ghub-run')[0]
        $provider.mode | Should -Be 'Reversible'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($provider.protectedScopes)|Should -Contain $scope}
    }
}

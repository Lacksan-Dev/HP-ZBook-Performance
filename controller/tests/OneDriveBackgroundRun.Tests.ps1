Describe 'EXP-048 OneDrive controller provider' {
    BeforeAll {
        $controllerRoot = Split-Path $PSScriptRoot -Parent
        $providerPath = Join-Path $controllerRoot 'providers/OneDriveBackgroundRun.ps1'
        $manifestPath = Join-Path $controllerRoot 'lacksan.manifest.json'
    }

    It 'parses without PowerShell syntax errors' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'exposes every controller provider action' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$content | Should -Match "'$action'"}
    }

    It 'limits mutation to the current-user Run key' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        $content | Should -Match [regex]::Escape("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run")
        $content | Should -Not -Match 'Uninstall-Package|Remove-AppxPackage|Remove-Service|pnputil|Set-MpPreference|Disable-WindowsOptionalFeature'
    }

    It 'requires exact OneDrive background identity and refuses updater commands' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        $content | Should -Match 'OneDrive\\\.exe'
        $content | Should -Match '/background'
        $content | Should -Match 'OneDriveSetup|OneDriveStandaloneUpdater'
    }

    It 'registers a reversible profile with protected scopes' {
        $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
        $profile=@($manifest.profiles|Where-Object id -eq 'OneDriveDemandLaunch')
        $profile.Count | Should -Be 1
        @($profile[0].providers) | Should -Contain 'onedrive-background-run'
        $provider=@($manifest.providers|Where-Object id -eq 'onedrive-background-run')[0]
        $provider.mode | Should -Be 'Reversible'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($provider.protectedScopes) | Should -Contain $scope}
    }
}

Describe 'EXP-054 Edge true demand-launch controller provider' {
    BeforeAll {
        $controllerRoot=Split-Path $PSScriptRoot -Parent
        $providerPath=Join-Path $controllerRoot 'providers/EdgeStartupBoostPolicy.ps1'
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
    It 'limits mutation to the documented recommended Startup Boost policy' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        $content | Should -Match [regex]::Escape('HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended')
        $content | Should -Match 'StartupBoostEnabled'
        $content | Should -Match 'DWord'
        $content | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Remove-Service|Stop-Service|Remove-Item.*User Data|Set-MpPreference'
    }
    It 'refuses mandatory policy, existing recommended policy, and managed devices' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        $content | Should -Match 'mandatory or recommended Edge policy detected'
        $content | Should -Match 'Enterprise management detected'
        $content | Should -Match 'Elevation is required'
    }
    It 'registers a reversible profile with every protected scope' {
        $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
        $profile=@($manifest.profiles|Where-Object id -eq 'EdgeTrueDemandLaunch')
        $profile.Count | Should -Be 1
        @($profile[0].providers) | Should -Contain 'edge-startup-boost-policy'
        $provider=@($manifest.providers|Where-Object id -eq 'edge-startup-boost-policy')[0]
        $provider.mode | Should -Be 'Reversible'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($provider.protectedScopes)|Should -Contain $scope}
    }
}

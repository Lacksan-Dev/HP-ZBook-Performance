Describe 'EXP-052 Logi Tune controller provider' {
    BeforeAll {
        $controllerRoot=Split-Path $PSScriptRoot -Parent
        $providerPath=Join-Path $controllerRoot 'providers/LogiTuneRun.ps1'
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
    It 'limits mutation to the current-user Run key and recognized Logi Tune identities' {
        $content=Get-Content -LiteralPath $providerPath -Raw
        $content | Should -Match [regex]::Escape('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run')
        $content | Should -Match 'LogiTuneAgent'
        $content | Should -Match 'logituneupdater'
        $content | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Remove-Service|pnputil|Set-MpPreference'
    }
    It 'registers a reversible profile with every protected scope' {
        $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
        $profile=@($manifest.profiles|Where-Object id -eq 'LogiTuneDemandLaunch')
        $profile.Count | Should -Be 1
        @($profile[0].providers) | Should -Contain 'logi-tune-run'
        $provider=@($manifest.providers|Where-Object id -eq 'logi-tune-run')[0]
        $provider.mode | Should -Be 'Reversible'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($provider.protectedScopes)|Should -Contain $scope}
    }
}

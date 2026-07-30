Describe 'EXP-072 Edge sleeping tabs policy provider' {
    BeforeAll {
        $controllerRoot=Split-Path $PSScriptRoot -Parent
        $providerPath=Join-Path $controllerRoot 'providers/EdgeSleepingTabsPolicy.ps1'
        $manifestPath=Join-Path $controllerRoot 'lacksan.manifest.json'
    }
    It 'parses without PowerShell syntax errors' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
    }
    It 'exposes the complete reversible action contract' {
        $content=Get-Content $providerPath -Raw
        foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$content|Should -Match "'$action'"}
    }
    It 'limits mutation to the recommended Edge sleeping tabs policy' {
        $content=Get-Content $providerPath -Raw
        $content|Should -Match [regex]::Escape('HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended')
        $content|Should -Match 'SleepingTabsEnabled'
        $content|Should -Match 'DWord'
        $content|Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Remove-Service|Stop-Service|Remove-Item.*User Data|Set-MpPreference|Update-Service'
    }
    It 'requires support detection management refusal structured logging and drift-safe rollback' {
        $content=Get-Content $providerPath -Raw
        foreach($term in @('Windows 11','Hewlett-Packard','Elevation is required','Enterprise management detected','Existing mandatory or recommended','ConvertTo-Json -Compress','State identity validation failed','Rollback refused because policy drifted','Apply verification failed','Reboot persistence verification failed')){$content|Should -Match [regex]::Escape($term)}
    }
    It 'registers one reversible profile with all protected scopes' {
        $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
        $profile=@($manifest.profiles|Where-Object id -eq 'EdgeSleepingTabsEnabled')
        $profile.Count|Should -Be 1
        @($profile[0].providers)|Should -Contain 'edge-sleeping-tabs-policy'
        $provider=@($manifest.providers|Where-Object id -eq 'edge-sleeping-tabs-policy')[0]
        $provider.mode|Should -Be 'Reversible'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($provider.protectedScopes)|Should -Contain $scope}
    }
}

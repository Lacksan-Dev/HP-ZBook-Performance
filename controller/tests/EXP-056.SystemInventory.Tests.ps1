$providerPath = Join-Path $PSScriptRoot '..\providers\SystemInventory.ps1'
$manifestPath = Join-Path $PSScriptRoot '..\lacksan.manifest.json'

Describe 'EXP-056 cross-OEM system inventory contracts' {
    BeforeAll {
        $providerText = Get-Content -LiteralPath $providerPath -Raw
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }

    It 'supports Windows 11 without imposing an OEM-wide controller gate' {
        $providerText | Should Match "Windows 11"
        $providerText | Should Match 'supported = \$isWindows11'
        $providerText | Should Not Match "supports HP systems running Windows 11 only"
    }

    It 'preserves explicit HP reference-platform eligibility' {
        $providerText | Should Match 'hpReferencePlatform'
        $providerText | Should Match 'HP\|Hewlett-Packard'
    }

    It 'captures OEM architecture BIOS processor and protected applications' {
        foreach ($token in @('manufacturer','model','architecture','biosVersion','processor','protectedApplications')) {
            $providerText | Should Match $token
        }
    }

    It 'remains mutation-free across every action' {
        $providerText | Should Match 'mutationCount = 0'
        foreach ($action in @('DryRun','Apply','Verify','VerifyReboot','Rollback')) {
            $providerText | Should Match ([regex]::Escape("'$action'"))
        }
        $providerText | Should Not Match 'Remove-ItemProperty|Set-ItemProperty|New-ItemProperty|Set-Service|Stop-Service|Disable-ScheduledTask|Remove-Item'
    }

    It 'retains protected scopes in the inventory provider manifest' {
        $provider = @($manifest.providers | Where-Object id -eq 'system-inventory')[0]
        $provider.mode | Should Be 'ReadOnly'
        foreach ($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')) {
            @($provider.protectedScopes) | Should Contain $scope
        }
    }
}

Describe 'EXP-063 HP App Helper HSA service provider' {
    BeforeAll {
        $root=Split-Path $PSScriptRoot -Parent
        $provider=Join-Path $root 'providers/HPAppHelperHsaService.ps1'
        $manifest=Join-Path $root 'lacksan.manifest.json'
        $content=Get-Content -LiteralPath $provider -Raw
    }
    It 'parses without syntax errors' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)
        $errors.Count|Should -Be 0
    }
    It 'exposes the complete reversible contract' {
        foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$content|Should -Match "'$action'"}
        foreach($term in @('Write-StructuredLog','Save-State','Read-State','ShouldProcess','Test-Applied','Rollback refused','Apply verification failed')){$content|Should -Match [regex]::Escape($term)}
    }
    It 'targets one exact HP App Helper service and changes startup mode only' {
        $content|Should -Match "serviceName='HPAppHelperCap'"
        $content|Should -Match 'HP App Helper.*HSA|HP.*App Helper'
        $content|Should -Match 'Get-AuthenticodeSignature'
        $content|Should -Match 'sc\.exe config'
        $content|Should -Match 'start= demand'
        $content|Should -Not -Match 'Remove-Service|Remove-AppxPackage|pnputil|devcon|Disable-WindowsOptionalFeature|Set-MpPreference|Stop-Process'
    }
    It 'captures identity configuration dependencies and running state' {
        foreach($field in @('DisplayName','PathName','ExecutablePath','ExecutableVersion','SignatureStatus','Signer','StartMode','DelayedAutoStart','State','StartName','Dependencies','DependentServices','windowsBuild','manufacturer','model')){$content|Should -Match $field}
    }
    It 'refuses management and dependency ambiguity' {
        $content|Should -Match 'PolicyManager'
        $content|Should -Match 'ManagementSignals'
        $content|Should -Match 'DependencySafe'
        $content|Should -Match 'ServiceCount'
        $content|Should -Match 'Dependencies require physical review before mutation'
    }
    It 'requires a machine-bound versioned state artifact' {
        foreach($term in @('schemaVersion=1','experiment=''EXP-063''','provider=''hp-app-helper-hsa-service''','machine=$env:COMPUTERNAME','State identity validation failed')){$content|Should -Match [regex]::Escape($term)}
    }
    It 'verifies immediate and reboot-persistent application state' {
        $content|Should -Match "'VerifyReboot'"
        $content|Should -Match 'LastBootUpTime'
        $content|Should -Match 'Reboot persistence verification failed'
        $content|Should -Match "StartMode -eq 'Manual'"
        $content|Should -Match 'DelayedAutoStart -eq 0'
    }
    It 'uses terminating command and verification failures' {
        $content|Should -Match "ErrorActionPreference='Stop'"
        $content|Should -Match 'LASTEXITCODE -ne 0'
        $content|Should -Match "Write-StructuredLog 'failure' 'fail'"
        $content|Should -Match 'throw'
    }
    It 'restores exact startup delayed-start and running state with drift refusal' {
        foreach($term in @('Assert-CurrentIdentityMatchesSaved','applied configuration drifted','Restore exact startup configuration and running state','Start-Service','Stop-Service','Rollback verification failed')){$content|Should -Match [regex]::Escape($term)}
    }
    It 'registers the profile and all protected scopes' {
        $manifestObject=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
        @($manifestObject.profiles|Where-Object id -eq 'HPAppHelperDemandStart').Count|Should -Be 1
        $registered=@($manifestObject.providers|Where-Object id -eq 'hp-app-helper-hsa-service')[0]
        $registered.mode|Should -Be 'Reversible'
        $registered.script|Should -Be 'providers/HPAppHelperHsaService.ps1'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($registered.protectedScopes)|Should -Contain $scope}
    }
}

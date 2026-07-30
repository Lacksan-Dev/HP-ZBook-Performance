Describe 'EXP-064 HP System Info HSA service provider' {
    BeforeAll {
        $root=Split-Path $PSScriptRoot -Parent
        $provider=Join-Path $root 'providers/HPSystemInfoHsaService.ps1'
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
    It 'targets one exact HP System Info service and changes startup mode only' {
        $content|Should -Match "serviceName='HPSysInfoCap'"
        $content|Should -Match 'HP System Info.*HSA|HP.*System Info'
        $content|Should -Match 'Get-AuthenticodeSignature'
        $content|Should -Match 'Get-FileHash'
        $content|Should -Match 'sc\.exe config'
        $content|Should -Match 'start= demand'
        $content|Should -Not -Match 'Remove-Service|Remove-AppxPackage|pnputil|devcon|Disable-WindowsOptionalFeature|Set-MpPreference|Stop-Process|Remove-Item.*DriverStore'
    }
    It 'captures identity configuration package evidence dependencies and running state' {
        foreach($field in @('DisplayName','PathName','ExecutablePath','ExecutableHash','ExecutableVersion','SignatureStatus','Signer','StartMode','DelayedAutoStart','State','StartName','Dependencies','DependentServices','ServiceType','PackageEvidence','windowsBuild','manufacturer','model')){$content|Should -Match $field}
    }
    It 'refuses management driver and dependency ambiguity' {
        foreach($term in @('PolicyManager','ManagementSignals','DependencySafe','ServiceTypeSafe','ServiceCount','DriverMutationAuthorized')){$content|Should -Match $term}
    }
    It 'registers the profile and all protected scopes' {
        $manifestObject=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
        @($manifestObject.profiles|Where-Object id -eq 'HPSystemInfoDemandStart').Count|Should -Be 1
        $registered=@($manifestObject.providers|Where-Object id -eq 'hp-system-info-hsa-service')[0]
        $registered.mode|Should -Be 'Reversible'
        $registered.script|Should -Be 'providers/HPSystemInfoHsaService.ps1'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($registered.protectedScopes)|Should -Contain $scope}
    }
}

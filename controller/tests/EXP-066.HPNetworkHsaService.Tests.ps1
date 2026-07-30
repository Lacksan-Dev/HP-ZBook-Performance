Describe 'EXP-066 HP Network HSA service provider' {
    BeforeAll {
        $root=Split-Path $PSScriptRoot -Parent
        $provider=Join-Path $root 'providers/HPNetworkHsaService.ps1'
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
    It 'uses the EXP-066 state and log identity' {
        $content|Should -Match "experiment='EXP-066'"
        $content|Should -Not -Match "experiment='EXP-065'"
    }
    It 'targets one exact HP Network service and changes startup mode only' {
        $content|Should -Match "serviceName='HPNetworkCap'"
        $content|Should -Match 'HP Network.*HSA|HP.*Network'
        $content|Should -Match 'NetworkCap\\.exe'
        $content|Should -Match 'Get-AuthenticodeSignature'
        $content|Should -Match 'sc\.exe config'
        $content|Should -Match 'start= demand'
        $content|Should -Not -Match 'Remove-Service|Remove-AppxPackage|pnputil|devcon|Disable-WindowsOptionalFeature|Set-MpPreference|Stop-Process|Disable-NetAdapter|Set-DnsClient|New-NetRoute|Set-NetFirewall'
    }
    It 'captures service, application, and protected network boundaries' {
        foreach($field in @('DisplayName','PathName','ExecutablePath','ExecutableVersion','ExecutableHash','SignatureStatus','Signer','StartMode','DelayedAutoStart','State','StartName','Dependencies','DependentServices','windowsBuild','manufacturer','model','NetworkBoundary','ApplicationBoundary','Get-NetAdapter','Get-NetAdapterBinding','Get-NetRoute','Get-DnsClientServerAddress')){$content|Should -Match $field}
    }
    It 'refuses management dependency and OMEN ambiguity' {
        $content|Should -Match 'PolicyManager'
        $content|Should -Match 'ManagementSignals'
        $content|Should -Match 'DependencySafe'
        $content|Should -Match 'ContinuousDependencyDetected'
        $content|Should -Match 'OMEN Gaming Hub'
        $content|Should -Match 'ServiceCount'
    }
    It 'registers the profile and all protected scopes' {
        $manifestObject=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
        @($manifestObject.profiles|Where-Object id -eq 'HPNetworkDemandStart').Count|Should -Be 1
        $registered=@($manifestObject.providers|Where-Object id -eq 'hp-network-hsa-service')[0]
        $registered.mode|Should -Be 'Reversible'
        $registered.script|Should -Be 'providers/HPNetworkHsaService.ps1'
        foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){@($registered.protectedScopes)|Should -Contain $scope}
    }
}

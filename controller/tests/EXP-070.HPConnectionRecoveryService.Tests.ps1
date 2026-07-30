$providerPath=Join-Path $PSScriptRoot '..\providers\HPConnectionRecoveryService.ps1'
$manifestPath=Join-Path $PSScriptRoot '..\lacksan.manifest.json'
$provider=Get-Content -LiteralPath $providerPath -Raw
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json

Describe 'EXP-070 HP Connection Recovery provider contract' {
    It 'parses without syntax errors' {$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors);$errors.Count|Should -Be 0}
    It 'uses exact experiment provider service and executable identities' {$provider|Should -Match "experiment='EXP-070'";$provider|Should -Match "provider='hp-connection-recovery-service'";$provider|Should -Match "serviceName='HPCommRecovery'";$provider|Should -Match 'HPCommRecovery\\.exe';$provider|Should -Not -Match "experiment='EXP-069'"}
    It 'implements every lifecycle action' {foreach($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')){$provider|Should -Match ([regex]::Escape("'$action'"))}}
    It 'captures identity network boundary and drift-safe rollback' {foreach($token in @('ExecutableHash','ExecutableVersion','SignatureStatus','Signer','DelayedAutoStart','DependentServices','NetworkBoundary','Assert-Identity','Rollback refused')){$provider|Should -Match ([regex]::Escape($token))}}
    It 'refuses policy dependency and active recovery ambiguity' {foreach($token in @('Get-ManagementSignals','DependencySafe','Get-RecoveryActivity','Elevation is required','Windows 11','Hewlett-Packard','Active HP Connection Recovery activity')){$provider|Should -Match ([regex]::Escape($token))}}
    It 'supports dry run ShouldProcess JSONL idempotence verification and exact rollback' {foreach($token in @('SupportsShouldProcess','ShouldProcess','ConvertTo-Json -Compress','AlreadyApplied','MutationCount=0','Test-Applied','VerifyReboot','Restore exact startup and running state')){$provider|Should -Match ([regex]::Escape($token))}}
    It 'contains no protected network driver security update or recovery mutation' {$provider|Should -Not -Match 'Disable-NetAdapter|Set-DnsClient|New-NetRoute|Set-NetFirewall|Remove-WindowsDriver|pnputil.+/delete-driver|Set-MpPreference|Disable-WindowsOptionalFeature|Remove-AppxPackage'}
    It 'is registered with every protected scope' {($manifest.providers.id)|Should -Contain 'hp-connection-recovery-service';($manifest.profiles.id)|Should -Contain 'HPConnectionRecoveryDemandStart';$entry=$manifest.providers|Where-Object id -eq 'hp-connection-recovery-service';$entry.mode|Should -Be 'Reversible';foreach($scope in @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')){$entry.protectedScopes|Should -Contain $scope}}
}

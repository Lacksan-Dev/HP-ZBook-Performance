$providerPath=Join-Path $PSScriptRoot '..\providers\EdgeStartupBoostPolicy.ps1'
$manifestPath=Join-Path $PSScriptRoot '..\lacksan.manifest.json'
Describe 'EXP-054 Edge Startup Boost policy provider contract' {
    BeforeAll {
        $text=Get-Content -LiteralPath $providerPath -Raw
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors)
        $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    }
    It 'parses as PowerShell' {$errors.Count|Should -Be 0}
    It 'supports the full reversible action contract' {foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$action'"}}
    It 'uses ShouldProcess and terminating failures' {$text|Should -Match 'SupportsShouldProcess';$text|Should -Match 'ShouldProcess';$text|Should -Match "ErrorActionPreference='Stop'";$text|Should -Match "Write-ProviderLog 'failure'"}
    It 'captures support, management, Edge identity, exact policy state, machine, and user identity' {foreach($token in 'Windows 11','Manufacturer','EdgeVersion','EdgeHash','EdgePublisher','DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','KeyExists','ValueExists','Kind','Data','machine','userSid'){$text|Should -Match $token}}
    It 'limits mutation to the one recommended Startup Boost value' {$text|Should -Match "recommendedPath='HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge\\Recommended'";$text|Should -Match "valueName='StartupBoostEnabled'";$text|Should -Match 'New-ItemProperty';$text|Should -Match 'Remove-ItemProperty';$text|Should -Not -Match 'Set-Service|Stop-Service|Disable-ScheduledTask|Remove-AppxPackage|Uninstall-Package|pnputil|Set-MpPreference|Disable-NetAdapter'}
    It 'requires immediate and reboot persistence verification' {$text|Should -Match 'Test-Applied';$text|Should -Match 'VerifyReboot';$text|Should -Match 'LastBootUpTime'}
    It 'provides idempotence, drift refusal, structured JSONL logging, and exact rollback' {$text|Should -Match "'idempotent'";$text|Should -Match 'identity drift';$text|Should -Match 'policy changed after application';$text|Should -Match 'ConvertTo-Json -Compress';$text|Should -Match 'Remove empty experiment-created key'}
    It 'is registered with all protected scopes' {
        $manifest.profiles.id|Should -Contain 'EdgeTrueDemandLaunch'
        $entry=$manifest.providers|Where-Object id -eq 'edge-startup-boost-policy'
        $entry.mode|Should -Be 'Reversible'
        foreach($scope in 'WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale'){$entry.protectedScopes|Should -Contain $scope}
    }
}

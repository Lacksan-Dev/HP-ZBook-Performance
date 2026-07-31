$provider=Join-Path $PSScriptRoot '..\providers\LogitechSetPointEventManagerRun.ps1'
Describe 'EXP-081 Logitech SetPoint Event Manager provider contract' {
    BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
    It 'exists and uses strict terminating behavior' {Test-Path $provider|Should -BeTrue;$text|Should -Match 'Set-StrictMode -Version Latest';$text|Should -Match "ErrorActionPreference='Stop'"}
    It 'supports the complete reversible lifecycle' {foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$action'"}}
    It 'supports ShouldProcess and dry run' {$text|Should -Match 'SupportsShouldProcess';$text|Should -Match 'ShouldProcess';$text|Should -Match "'DryRun'"}
    It 'binds state to schema experiment provider machine and user' {foreach($token in 'schemaVersion','EXP-081','logitech-setpoint-event-manager-run','machine','userSid'){$text|Should -Match [regex]::Escape($token)}}
    It 'captures exact registry and executable identity' {foreach($token in 'DoNotExpandEnvironmentNames','GetValueKind','ExecutableHash','ExecutableVersion','PublisherSubject','Get-AuthenticodeSignature'){$text|Should -Match $token}}
    It 'requires one exact candidate and refuses unsafe identities' {$text|Should -Match 'Assert-One';$text|Should -Match 'SetPoint\(\?:II\)';$text|Should -Match 'update\|updater\|uninstall\|repair\|firmware\|pair\|driver\|device'}
    It 'refuses enterprise-managed systems' {foreach($token in 'DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','Enterprise-management signals'){$text|Should -Match $token}}
    It 'protects required applications and Windows controls' {foreach($token in 'omnissa','windows app','remote desktop','tailscale','defender','bitlocker','windows update','recovery','driver','firmware'){$text.ToLowerInvariant()|Should -Match [regex]::Escape($token)}}
    It 'provides structured JSONL logging and failure records' {$text|Should -Match 'ConvertTo-Json -Compress';$text|Should -Match "'failure' 'fail'"}
    It 'implements idempotence and exact rollback refusal' {$text|Should -Match "'idempotent'";$text|Should -Match 'already exists';$text|Should -Match 'publisher drift';$text|Should -Match 'hash drift';$text|Should -Match 'Test-Restored'}
    It 'requires reboot-persistence verification' {$text|Should -Match 'VerifyReboot';$text|Should -Match 'LastBootUpTime'}
    It 'limits mutation to one Run value' {$text|Should -Match 'Remove-ItemProperty';$text|Should -Match '\.SetValue\(';@($text|Select-String -Pattern 'Remove-Service|Stop-Service|Disable-ScheduledTask|pnputil|Remove-AppxPackage|Uninstall-Package' -AllMatches).Matches.Count|Should -Be 0}
}

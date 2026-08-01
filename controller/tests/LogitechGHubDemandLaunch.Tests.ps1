$provider = Join-Path $PSScriptRoot '..\providers\LogitechGHubDemandLaunch.ps1'
Describe 'LogitechGHubDemandLaunch contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'parses as PowerShell' { [scriptblock]::Create($text) | Should -Not -BeNullOrEmpty }
    It 'exposes the full reversible lifecycle' { foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$action'" } }
    It 'uses ShouldProcess and supports WhatIf' { foreach($token in 'SupportsShouldProcess','ShouldProcess','WhatIfPreference'){ $text | Should -Match $token } }
    It 'captures exact registry and executable identity' { foreach($token in 'RegistryValueOptions','GetValueKind','Get-AuthenticodeSignature','Get-FileHash','Thumbprint','KeySddl'){ $text | Should -Match $token } }
    It 'matches bounded G Hub identities and refuses unsafe components' { foreach($token in 'lghub_agent','lghub_system_tray','Exactly one eligible Logitech G Hub'){ $text | Should -Match $token }; $text | Should -Match 'updat\|uninstall\|repair\|firmware\|dfu\|driver' }
    It 'refuses enterprise ownership and ambiguous candidates' { foreach($token in 'DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','Exactly one eligible'){ $text | Should -Match $token } }
    It 'preserves profiles drivers protected applications and Windows controls' { foreach($token in 'PreserveOnboardProfiles','PreserveDrivers','omnissa','windows app','remote desktop','tailscale','defender','windows update','recovery'){ $text | Should -Match $token } }
    It 'limits application to one current-user Run value' { $text | Should -Match 'Remove-ItemProperty'; $text | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|pnputil|sc\.exe\s+delete|Remove-Service|Disable-WindowsOptionalFeature|Set-Service|Disable-ScheduledTask' }
    It 'retains failed evidence in structured JSONL' { $text | Should -Match 'ConvertTo-Json -Compress'; $text | Should -Match "'failure' 'fail'" }
    It 'implements idempotent application and exact rollback refusal' { $text | Should -Match "'idempotent'"; $text | Should -Match 'Rollback overwrite refused'; $text | Should -Match 'restoredExactOriginal' }
}

$provider=Join-Path $PSScriptRoot '..\providers\PriorityRunRegistrationRemoval.ps1'
Describe 'EXP-153 priority Run/RunOnce provider contract' {
 BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0}
 It 'uses EXP-153 evidence identity and rejects the retired EXP-144 identity' {$text|Should -Match "EXP-153-state\.json";$text|Should -Match "EXP-153\.jsonl";$text|Should -Match "\$Experiment='EXP-153'";$text|Should -Not -Match 'EXP-144'}
 It 'implements the full reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match ([regex]::Escape("'$a'"))}}
 It 'requires an EXP-143 priority-target selection and approved Run paths' {foreach($t in 'EXP-143','priority-target','ApprovedPaths','RunOnce','WOW6432Node','Exactly one EXP-143 registry selection is required'){$text|Should -Match ([regex]::Escape($t))}}
 It 'supports only direct signed executable registrations' {foreach($t in 'Resolve-Command','Get-AuthenticodeSignature','Unsigned or invalid startup executable refused','REG_SZ and REG_EXPAND_SZ','Script, shell, installer, or indirection launcher refused'){$text|Should -Match ([regex]::Escape($t))}}
 It 'preserves protected remote access security update recovery management and driver identities' {foreach($t in 'omnissa','windows app','remote desktop','tailscale','defender','credential','bitlocker','firewall','windows update','recovery','accessibility','driver','firmware','Enterprise management ownership'){$text|Should -Match ([regex]::Escape($t))}}
 It 'captures exact original value and executable identity' {foreach($t in 'Kind','Data','Sha256','FileVersion','ProductName','CompanyName','Publisher','Thumbprint','KeyOwner','KeySddl','entrySnapshotSha256'){$text|Should -Match $t}}
 It 'uses ShouldProcess WhatIf structured JSONL logging and idempotence' {foreach($t in 'SupportsShouldProcess','WhatIfPreference','ConvertTo-Json -Compress','mutationCount','idempotent','failure'){$text|Should -Match $t}}
 It 'requires a later boot for persistence verification' {$text|Should -Match 'capturedBootTime';$text|Should -Match 'A later boot is required for reboot persistence verification';$text|Should -Match 'Reboot persistence failed'}
 It 'refuses conflicting rollback and restores exact registry type and raw data' {$text|Should -Match 'Rollback overwrite refused';$text|Should -Match 'RegistryValueKind';$text|Should -Match 'SetValue';$text|Should -Match 'Exact rollback verification failed';$text|Should -Match 'restoredExactOriginal'}
 It 'retains missing physical evidence explicitly' {$text|Should -Match 'needs-evidence'}
 It 'does not contain broad package device driver firmware or security mutation commands' {$text|Should -Not -Match 'Uninstall-Package|Remove-AppxPackage|Disable-PnpDevice|Remove-PnpDevice|pnputil\s+/delete-driver|bcdedit|Set-MpPreference|Disable-WindowsOptionalFeature|Stop-Service\s+.*WinDefend|Set-Service\s+.*wuauserv'}
}

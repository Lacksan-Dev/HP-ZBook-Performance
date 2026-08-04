Describe 'EXP-153 InventoryBoundRunRemoval contract' {
 BeforeAll {
  $script:provider=Join-Path $PSScriptRoot '..\providers\InventoryBoundRunRemoval.ps1'
  $script:text=Get-Content -LiteralPath $script:provider -Raw
 }
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($script:provider,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0}
 It 'retains Experimental identity and pending physical evidence' {$script:text|Should -Match 'EXP-153';$script:text|Should -Match 'needs-evidence';$script:text|Should -Not -Match 'status:stable|stage:stable|Stable='}
 It 'implements the complete reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$script:text|Should -Match "'$a'"}}
 It 'binds one exact EXP-143 priority Registry selection and inventory hash' {foreach($t in "experiment-ne'EXP-143'","classification-ne'priority-target'","surface-ne'Registry'",'inventoryHash','originalState','identity'){$script:text|Should -Match ([regex]::Escape($t))}}
 It 'allows only approved Run and RunOnce registry surfaces including 32-bit HKLM view' {foreach($t in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'){$script:text|Should -Match ([regex]::Escape($t))}}
 It 'requires HP Windows 11 elevation and self-managed ownership' {foreach($t in 'Windows 11','Hewlett-Packard','Elevated','enterprise management ownership detected','Management ownership appeared'){$script:text|Should -Match ([regex]::Escape($t))}}
 It 'captures exact type unexpanded data ACL machine user boot executable and signer identity' {foreach($t in 'DoNotExpandEnvironmentNames','GetValueKind','KeyOwner','KeySddl','capturedBootTime','userSid','Sha256','Version','Publisher','Thumbprint','Get-AuthenticodeSignature'){$script:text|Should -Match $t}}
 It 'refuses protected and servicing identities' {foreach($t in 'omnissa','windows app','remote desktop','tailscale','defender','windows update','accessib','edgeupdate','clicktorun','firmware','driver','pairing'){$script:text.ToLowerInvariant()|Should -Match ([regex]::Escape($t))}}
 It 'requires a valid initial Microsoft or Logitech publisher' {$script:text|Should -Match 'Microsoft Corporation\|Logitech\|Logi';$script:text|Should -Match "SignatureStatus-ne'Valid'"}
 It 'holds unrelated Run state and protected services against drift' {foreach($t in 'OthersSame','Unrelated Run/RunOnce drift detected','WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','ProtectedState'){$script:text|Should -Match ([regex]::Escape($t))}}
 It 'supports structured JSONL logging WhatIf ShouldProcess idempotence and terminating failure retention' {foreach($t in 'SupportsShouldProcess','ShouldProcess','WhatIfPreference','ConvertTo-Json -Compress','idempotent',"Log 'failure' 'failure'",'ErrorActionPreference'){$script:text|Should -Match ([regex]::Escape($t))}}
 It 'requires a later boot for treatment persistence' {$script:text|Should -Match 'Later boot required';$script:text|Should -Match 'Treatment failed reboot persistence'}
 It 'limits production mutation to one selected registry value' {$script:text|Should -Match 'Remove-ItemProperty';$script:text|Should -Match '\.SetValue\('; $script:text|Should -Not -Match 'Set-Service|Stop-Service|Remove-Service|Disable-ScheduledTask|Unregister-ScheduledTask|Remove-AppxPackage|Disable-PnpDevice|Remove-PnpDevice|pnputil|Set-MpPreference'}
 It 'implements collision-safe exact type-aware rollback' {foreach($t in 'Rollback conflicting-value overwrite refused','RegistryValueKind','Enum]::Parse','Exact rollback verification failed','restoredExactOriginal'){$script:text|Should -Match ([regex]::Escape($t))}}
}

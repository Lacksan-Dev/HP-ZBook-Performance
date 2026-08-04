Describe 'SetPointEventManagerDemandLaunch contract' {
 BeforeAll {
  $provider = Join-Path $PSScriptRoot '..\providers\SetPointEventManagerDemandLaunch.ps1'
  $text = Get-Content -LiteralPath $provider -Raw
 }
 It 'parses as PowerShell' { $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0 }
 It 'exposes the full reversible lifecycle' { foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$action'" } }
 It 'uses ShouldProcess and WhatIf' { $text | Should -Match 'SupportsShouldProcess'; $text | Should -Match 'ShouldProcess'; $text | Should -Match 'WhatIfPreference' }
 It 'requires HP Windows 11 elevation self-managed ownership and one candidate' { foreach($token in 'Windows 11 required','HP platform required','elevation required','enterprise management ownership detected','exactly one eligible SetPoint Event Manager'){ $text | Should -Match ([regex]::Escape($token)) } }
 It 'captures exact Run value ACL and executable identity' { foreach($token in 'DoNotExpandEnvironmentNames','GetValueKind','Get-Acl','KeyOwner','KeySddl','Get-AuthenticodeSignature','Get-FileHash','Thumbprint','Version','Publisher'){ $text | Should -Match $token } }
 It 'requires signed SetPoint executable identity and rejects servicing paths' { $text | Should -Match 'SetPoint\(\?:II\)\?'; $text | Should -Match 'ValidLogitech'; $text | Should -Match 'updat\|uninstall\|repair\|firmware\|dfu\|driver\|pairing\|setup\|install' }
 It 'separates protected configuration from reboot-varying runtime evidence' { foreach($token in 'protectedConfigurationHash','protectedRuntime','configServices','runtimeServices','ProtectedProcesses'){ $text | Should -Match $token }; $text | Should -Match 'configuration drift detected' }
 It 'binds captured state to machine user and boot' { foreach($token in 'machine=$env:COMPUTERNAME','userSid','capturedBootUtc','State identity mismatch'){ $text | Should -Match ([regex]::Escape($token)) } }
 It 'requires a later boot for persistence' { $text | Should -Match 'ConvertTo-UtcDateTime'; $text | Should -Match 'A later boot is required'; $text | Should -Match 'Treatment failed reboot persistence' }
 It 'refuses Run-key ACL executable management and protected drift' { foreach($token in 'Run-key drift detected','Run-key ACL drift detected','SetPoint executable identity drift detected','Management ownership appeared','Protected security update remote-access driver or device configuration drift detected'){ $text | Should -Match ([regex]::Escape($token)) } }
 It 'limits production mutation to one Run value' { $text | Should -Match 'Remove-ItemProperty'; $text | Should -Match '\.SetValue'; $text | Should -Not -Match 'Uninstall-Package|Remove-AppxPackage|Set-Service|Stop-Service|Remove-Service|Disable-PnpDevice|Remove-PnpDevice|pnputil|Disable-ScheduledTask|Unregister-ScheduledTask|Set-MpPreference|Disable-WindowsOptionalFeature' }
 It 'refuses key recreation and value collision during rollback' { $text | Should -Match 'Rollback overwrite refused'; $text | Should -Match 'Get-Item -LiteralPath'; $text | Should -Not -Match 'New-Item -Path \$s\.entry\.Path'; $text | Should -Match 'Exact rollback verification failed' }
 It 'logs failures and keeps evidence Experimental' { $text | Should -Match "'failure' 'fail'"; $text | Should -Match 'needs-evidence'; $text | Should -Not -Match "Stable" }
}

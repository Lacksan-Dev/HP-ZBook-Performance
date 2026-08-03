Describe 'SetPointEventManagerDemandLaunch contract' {
 BeforeAll {
  $provider = Join-Path $PSScriptRoot '..\providers\SetPointEventManagerDemandLaunch.ps1'
  $text = Get-Content -LiteralPath $provider -Raw
 }
 It 'parses as PowerShell' { $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0 }
 It 'exposes the full reversible lifecycle' { foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$action'" } }
 It 'uses ShouldProcess and supports WhatIf' { $text | Should -Match 'SupportsShouldProcess'; $text | Should -Match 'ShouldProcess'; $text | Should -Match 'WhatIfPreference' }
 It 'supports approved HKCU and HKLM Run locations with bounded elevation' { $text | Should -Match 'HKCU:'; $text | Should -Match 'HKLM:'; $text | Should -Match 'MachineWide'; $text | Should -Match 'Test-Elevated'; $text | Should -Match 'Elevation is required' }
 It 'captures exact registry ACL executable and signer identity' { foreach($token in 'DoNotExpandEnvironmentNames','GetValueKind','Get-Acl','KeySddl','Get-AuthenticodeSignature','Get-FileHash','Thumbprint','ProductName','CompanyName'){ $text | Should -Match $token } }
 It 'requires SetPoint executable identity and rejects servicing paths' { $text | Should -Match 'SetPoint\(\?:II\)\?'; $text | Should -Match 'Logitech'; $text | Should -Match 'updat\|uninstall\|repair\|firmware\|dfu\|driver\|pairing\|setup\|install' }
 It 'captures bounded management ownership signals' { foreach($token in 'DomainJoined','MdmEnrollments','OmadmAccounts','PolicyManager','ConfigMgr','RunPolicy'){ $text | Should -Match $token }; $text | Should -Match 'Exactly one eligible SetPoint Event Manager' }
 It 'holds protected services Logitech drivers and Logitech devices against drift' { foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','LogitechDrivers','LogitechDevices','Get-PnpDevice','Assert-Protected'){ $text | Should -Match $token } }
 It 'records Experimental evidence and requires a later boot for persistence' { $text | Should -Match 'needs-evidence'; $text | Should -Match 'capturedBootTime'; $text | Should -Match 'A later boot is required' }
 It 'limits production mutation to the selected Run value' { $text | Should -Match 'Remove-ItemProperty'; $text | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Remove-Package|Set-Service|Stop-Service|Remove-Service|Disable-PnpDevice|Remove-PnpDevice|pnputil|Disable-ScheduledTask|Unregister-ScheduledTask|Set-MpPreference|Disable-WindowsOptionalFeature' }
 It 'retains failures and performs collision-safe exact rollback' { $text | Should -Match "'failure' 'fail'"; $text | Should -Match "'idempotent'"; $text | Should -Match 'Rollback overwrite refused'; $text | Should -Match 'Enum]::Parse'; $text | Should -Match 'Exact rollback verification failed' }
}

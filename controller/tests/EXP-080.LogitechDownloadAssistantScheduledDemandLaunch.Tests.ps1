Describe 'EXP-080 Logitech Download Assistant scheduled demand-launch contract' {
 BeforeAll {
  $Provider=Join-Path $PSScriptRoot '..\providers\LogitechDownloadAssistantScheduledDemandLaunch.ps1'
  $Text=Get-Content -LiteralPath $Provider -Raw
 }
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($Provider,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0}
 It 'implements the complete reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$Text|Should -Match "'$a'"}}
 It 'requires HP Windows 11 elevation unmanaged ownership and one exact candidate' {foreach($t in 'Windows 11','Hewlett-Packard','elevation required','enterprise management ownership detected','exactly one eligible Logitech Download Assistant scheduled task'){$Text|Should -Match $t}}
 It 'binds candidate identity to a signed Logitech payload and startup trigger' {foreach($t in 'LogiLDA','Get-AuthenticodeSignature','Get-FileHash','ValidLogitech','LogonTrigger','BootTrigger','AllowDemandStart'){$Text|Should -Match $t}}
 It 'captures task XML identity actions triggers principal payload machine user and boot state' {foreach($t in 'Export-ScheduledTask','XmlSha256','Actions','Triggers','PrincipalUserId','Payload','capturedBootTime','userSid'){$Text|Should -Match $t}}
 It 'preserves protected Windows remote access and Logitech drivers' {foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','Win32_SystemDriver','LogitechDrivers','Protected security update remote-access or Logitech driver state drift detected'){$Text|Should -Match $t}}
 It 'limits production mutation to the exact task enabled state' {$Text|Should -Match 'Disable-ScheduledTask';$Text|Should -Match 'Enable-ScheduledTask';$Text|Should -Not -Match 'Unregister-ScheduledTask|Register-ScheduledTask|Remove-AppxPackage|Uninstall-Package|Set-Service|Stop-Service|Disable-PnpDevice|pnputil|Set-MpPreference'}
 It 'supports dry run WhatIf structured logging idempotence failure retention and exact rollback' {foreach($t in 'SupportsShouldProcess','WhatIfPreference','ConvertTo-Json -Compress','idempotent','failure','Exact rollback verification failed','definitionPreserved'){$Text|Should -Match $t}}
 It 'requires later-boot persistence verification and retains physical observations' {$Text|Should -Match 'A later boot is required';$Text|Should -Match 'Treatment failed reboot persistence';$Text|Should -Match 'needs-evidence'}
}

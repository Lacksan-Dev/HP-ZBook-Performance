$Provider=Join-Path $PSScriptRoot '..\providers\Microsoft365StartupFolderDemandLaunch.ps1'
Describe 'EXP-058 Microsoft365StartupFolderDemandLaunch contract' {
 BeforeAll {$Text=Get-Content -LiteralPath $Provider -Raw}
 It 'declares the complete reversible action surface' {
  $Text | Should -Match "Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback"
 }
 It 'limits eligibility to supported Microsoft 365 desktop executables' {
  foreach($name in 'OUTLOOK.EXE','WINWORD.EXE','EXCEL.EXE','POWERPNT.EXE','ONENOTE.EXE','MSACCESS.EXE'){$Text | Should -Match [regex]::Escape($name)}
  $Text | Should -Match 'ValidMicrosoft'
  $Text | Should -Match 'Microsoft Corporation'
 }
 It 'targets the current-user Startup folder and refuses shortcut arguments' {
  $Text | Should -Match "GetFolderPath\('Startup'\)"
  $Text | Should -Not -Match "GetFolderPath\('CommonStartup'\)"
  $Text | Should -Match 'IsNullOrWhiteSpace.*Arguments'
 }
 It 'captures exact bytes, hash, shortcut metadata, timestamps, attributes and ACL' {
  foreach($token in 'bytesBase64','Sha256','CreationTimeUtc','LastWriteTimeUtc','LastAccessTimeUtc','Attributes','AclSddl','TargetPath','WorkingDirectory','IconLocation','Description','WindowStyle','Hotkey'){$Text | Should -Match $token}
 }
 It 'implements dry run and ShouldProcess semantics' {
  $Text | Should -Match 'SupportsShouldProcess'
  $Text | Should -Match 'WhatIfPreference'
  $Text | Should -Match 'ShouldProcess'
  $Text | Should -Match "'DryRun'"
 }
 It 'requires a later boot for persistence verification' {
  $Text | Should -Match 'capturedBootTime'
  $Text | Should -Match 'Later boot required'
  $Text | Should -Match "'VerifyReboot'"
 }
 It 'retains structured needs-evidence logging and terminating failures' {
  $Text | Should -Match 'ConvertTo-Json -Compress'
  $Text | Should -Match "EvidenceStatus='needs-evidence'"
  $Text | Should -Match "'failure' 'failure'"
  $Text | Should -Match "ErrorActionPreference='Stop'"
 }
 It 'preserves protected Windows and remote-access services' {
  foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$Text | Should -Match $token}
  foreach($token in 'omnissa','windows app','remote desktop','tailscale'){$Text | Should -Match $token}
 }
 It 'refuses managed systems' {
  $Text | Should -Match 'enterprise management ownership detected'
  $Text | Should -Match 'PartOfDomain'
  $Text | Should -Match 'CcmExec'
  $Text | Should -Match 'OMADM'
 }
 It 'provides idempotent apply and rollback with collision refusal' {
  $Text | Should -Match "'apply' 'idempotent'"
  $Text | Should -Match "'rollback' 'idempotent'"
  $Text | Should -Match 'Rollback conflicting-path overwrite refused'
  $Text | Should -Match 'Exact rollback verification failed'
 }
 It 'preserves Office servicing by restricting the mutation to one shortcut' {
  $Text | Should -Match 'PreserveMicrosoft365'
  $Text | Should -Match 'PreserveClickToRun'
  $Text | Should -Match 'Remove exact Microsoft 365 Startup-folder shortcut'
 }
}

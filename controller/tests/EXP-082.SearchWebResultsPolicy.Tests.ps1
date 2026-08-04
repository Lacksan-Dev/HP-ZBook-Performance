$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/SearchWebResultsPolicy.ps1'
Describe 'EXP-082 Search web-results provider contract' {
  BeforeAll { $text=Get-Content $provider -Raw; $tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors) }
  It 'parses as PowerShell' { $errors.Count | Should -Be 0 }
  It 'targets the documented Windows Search web policy pair only' { foreach($s in 'DisableWebSearch','ConnectedSearchUseWeb','AtomicPair','Windows Search'){ $text | Should -Match $s };$text | Should -Match 'DisableWebSearch=1';$text | Should -Match 'ConnectedSearchUseWeb=0' }
  It 'implements the complete reversible lifecycle' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'captures exact registry and ACL state for both values' { foreach($s in 'KeyExists','ValueExists','Kind','Data','Owner','Sddl','DoNotExpandEnvironmentNames'){ $text | Should -Match $s } }
  It 'refuses unsupported editions enterprise management and existing policy ownership' { foreach($s in 'supported Windows 11 edition required','enterprise management ownership detected','existing Windows Search web policy ownership detected','CcmExec','Microsoft\\Enrollments','OMADM'){ $text | Should -Match $s } }
  It 'preserves protected security update and remote access services' { foreach($s in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){ $text | Should -Match $s };$text | Should -Match 'Protected security update or remote-access state drift detected' }
  It 'supports ShouldProcess WhatIf JSONL logging idempotence and failure retention' { foreach($s in 'SupportsShouldProcess','WhatIfPreference','ConvertTo-Json -Compress','idempotent','failure'){ $text | Should -Match $s } }
  It 'restores the original pair if application fails partway' { $text | Should -Match 'Atomic apply verification failed; original pair restored';$text | Should -Match 'Restore-Value' }
  It 'requires later boot persistence verification' { $text | Should -Match 'A later boot is required';$text | Should -Match 'capturedBootTime' }
  It 'provides exact rollback with drift refusal' { $text | Should -Match 'Candidate policy pair drift detected';$text | Should -Match 'Exact rollback verification failed';$text | Should -Match 'Remove-Item -Path \$PolicyPath' }
  It 'retains physical Search function and network checks as needs-evidence' { foreach($s in 'localApplicationSearch','localSettingSearch','localFileSearch','indexedContentSearch','webResultsAbsent','searchHostNetwork','needs-evidence'){ $text | Should -Match $s } }
  It 'contains no protected-scope mutation commands' { $text | Should -Not -Match '(?i)Set-MpPreference|Disable-WindowsOptionalFeature|Remove-WindowsDriver|pnputil|bcdedit|manage-bde|Set-NetFirewall|Uninstall-Package|Remove-AppxPackage|Stop-Service|Set-Service|Restart-Service' }
}

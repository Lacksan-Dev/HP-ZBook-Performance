$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/SearchHighlightsPolicy.ps1'
Describe 'EXP-083 Search highlights provider contract' {
  BeforeAll { $text=Get-Content $provider -Raw; $tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors) }
  It 'parses as PowerShell' { $errors.Count | Should -Be 0 }
  It 'targets only the documented Search highlights policy' { $text | Should -Match 'EnableDynamicContentInWSB';$text | Should -Match "Treatment=0";$text | Should -Match 'Windows Search' }
  It 'implements the complete reversible lifecycle' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'captures exact registry and ACL state' { foreach($s in 'KeyExists','ValueExists','Kind','Data','Owner','Sddl','DoNotExpandEnvironmentNames'){ $text | Should -Match $s } }
  It 'refuses unsupported editions enterprise management and existing policy ownership' { foreach($s in 'supported Windows 11 edition required','enterprise management ownership detected','existing AllowSearchHighlights policy ownership detected','CcmExec','Microsoft\\Enrollments','OMADM'){ $text | Should -Match $s } }
  It 'preserves protected security update and remote access services' { foreach($s in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){ $text | Should -Match $s };$text | Should -Match 'Protected security update or remote-access state drift detected' }
  It 'supports ShouldProcess WhatIf JSONL logging idempotence and failure retention' { foreach($s in 'SupportsShouldProcess','WhatIfPreference','ConvertTo-Json -Compress','idempotent','failure'){ $text | Should -Match $s } }
  It 'requires later boot persistence verification' { $text | Should -Match 'A later boot is required';$text | Should -Match 'capturedBootTime' }
  It 'provides exact rollback with collision and drift refusal' { $text | Should -Match 'Candidate policy drift detected';$text | Should -Match 'Exact rollback verification failed';$text | Should -Match 'original.KeyExists';$text | Should -Match 'Remove-Item -Path \$PolicyPath' }
  It 'retains physical Search function checks as needs-evidence' { foreach($s in 'localApplicationSearch','localSettingSearch','localFileSearch','searchHighlightsAbsent','needs-evidence'){ $text | Should -Match $s } }
  It 'contains no protected-scope mutation commands' { $text | Should -Not -Match '(?i)Set-MpPreference|Disable-WindowsOptionalFeature|Remove-WindowsDriver|pnputil|bcdedit|manage-bde|Set-NetFirewall|Uninstall-Package|Remove-AppxPackage|Stop-Service|Set-Service|Restart-Service' }
}

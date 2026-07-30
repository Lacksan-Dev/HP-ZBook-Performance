$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/EdgeNewTabPrerenderPolicy.ps1'
Describe 'EXP-076 Edge new-tab prerender provider contract' {
  BeforeAll { $text=Get-Content $provider -Raw; $tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors) }
  It 'parses as PowerShell' { $errors.Count | Should -Be 0 }
  It 'uses the exact recommended policy and disabled DWORD' { $text | Should -Match "Edge\\Recommended"; $text | Should -Match "NewTabPagePrerenderEnabled"; $text | Should -Match '\$targetValue=0'; $text | Should -Match 'Major-ge85' }
  It 'implements the complete reversible action contract' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'captures identity before mutation and validates state identity' { $text | Should -Match 'Save-State';$text | Should -Match 'Read-State';$text | Should -Match "experiment='EXP-076'" }
  It 'supports ShouldProcess, structured JSONL logging, idempotence, and terminating failures' { $text | Should -Match 'SupportsShouldProcess';$text | Should -Match 'ConvertTo-Json -Compress';$text | Should -Match 'MutationCount=0';$text | Should -Match "ErrorActionPreference='Stop'" }
  It 'refuses management ownership and existing policy values' { $text | Should -Match 'Enterprise management detected';$text | Should -Match 'Existing mandatory or recommended' }
  It 'refuses rollback after drift' { $text | Should -Match 'Rollback refused because policy drifted' }
  It 'contains no protected-scope mutation commands' { $text | Should -Not -Match '(?i)Set-MpPreference|Disable-WindowsOptionalFeature|Remove-WindowsDriver|pnputil|bcdedit|manage-bde|Set-NetFirewall|Uninstall-Package|Remove-AppxPackage|Stop-Service' }
}

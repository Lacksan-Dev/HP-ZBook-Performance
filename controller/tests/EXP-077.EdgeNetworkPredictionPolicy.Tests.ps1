$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/EdgeNetworkPredictionPolicy.ps1'
Describe 'EXP-077 Edge network prediction provider contract' {
  BeforeAll { $text=Get-Content $provider -Raw; $tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors) }
  It 'parses as PowerShell' { $errors.Count | Should -Be 0 }
  It 'uses the exact recommended policy and NetworkPredictionNever DWORD' { $text | Should -Match "Edge\\Recommended"; $text | Should -Match "NetworkPredictionOptions"; $text | Should -Match '\$targetValue=2'; $text | Should -Match 'Major-ge77' }
  It 'implements the complete reversible action contract' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'captures identity before mutation and validates state identity' { $text | Should -Match 'Save-State';$text | Should -Match 'Read-State';$text | Should -Match "experiment='EXP-077'" }
  It 'supports ShouldProcess, structured JSONL logging, idempotence, and terminating failures' { $text | Should -Match 'SupportsShouldProcess';$text | Should -Match 'ConvertTo-Json -Compress';$text | Should -Match 'MutationCount=0';$text | Should -Match "ErrorActionPreference='Stop'" }
  It 'refuses management ownership and existing policy values' { $text | Should -Match 'Enterprise management detected';$text | Should -Match 'Existing mandatory or recommended' }
  It 'refuses rollback after drift and verifies exact restoration' { $text | Should -Match 'Rollback refused because policy drifted';$text | Should -Match 'restoredExactOriginal' }
  It 'does not reference protected mutation commands or scopes' { $text | Should -Not -Match 'Set-MpPreference|Disable-BitLocker|Set-NetFirewallProfile|Remove-AppxPackage|Uninstall-Package|Remove-Item\s+.*(Windows Defender|Tailscale|Omnissa)' }
}

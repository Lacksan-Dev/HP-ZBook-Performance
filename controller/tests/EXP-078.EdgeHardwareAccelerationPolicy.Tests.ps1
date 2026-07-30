$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/EdgeHardwareAccelerationPolicy.ps1'
Describe 'EXP-078 Edge graphics acceleration provider contract' {
  BeforeAll { $text=Get-Content $provider -Raw; $tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors) }
  It 'parses as PowerShell' { $errors.Count | Should -Be 0 }
  It 'uses the exact mandatory policy and enabled DWORD' { $text | Should -Match 'SOFTWARE\\Policies\\Microsoft\\Edge'; $text | Should -Match 'HardwareAccelerationModeEnabled'; $text | Should -Match '\$targetValue=1'; $text | Should -Match 'Major-ge77' }
  It 'implements the complete reversible action contract' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'captures graphics and state identity before mutation' { $text | Should -Match 'Win32_VideoController';$text | Should -Match 'Save-State';$text | Should -Match 'Read-State';$text | Should -Match "experiment='EXP-078'" }
  It 'supports ShouldProcess, JSONL logging, idempotence, and terminating failures' { $text | Should -Match 'SupportsShouldProcess';$text | Should -Match 'ConvertTo-Json -Compress';$text | Should -Match 'MutationCount=0';$text | Should -Match "ErrorActionPreference='Stop'" }
  It 'refuses management ownership and an existing policy value' { $text | Should -Match 'Enterprise management detected';$text | Should -Match 'Existing mandatory Edge graphics acceleration policy' }
  It 'requires browser restart verification and reboot persistence' { $text | Should -Match 'BrowserRestartRequired';$text | Should -Match 'browserRestartRequired';$text | Should -Match 'Reboot persistence verification failed' }
  It 'refuses rollback after drift and verifies exact restoration' { $text | Should -Match 'Rollback refused because policy drifted';$text | Should -Match 'restoredExactOriginal' }
  It 'does not reference protected mutation commands or scopes' { $text | Should -Not -Match 'Set-MpPreference|Disable-BitLocker|Set-NetFirewallProfile|Remove-AppxPackage|Uninstall-Package|Remove-Item\s+.*(Windows Defender|Tailscale|Omnissa)' }
}

$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/EdgeNewTabPrerenderPolicy.ps1'
Describe 'EXP-076 Edge new-tab prerender provider contract' {
  BeforeAll { $text=Get-Content $provider -Raw; $tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors) }
  It 'parses as PowerShell' { $errors.Count | Should -Be 0 }
  It 'uses the exact supported recommended policy' { $text | Should -Match "Edge\\Recommended"; $text | Should -Match "NewTabPagePrerenderEnabled"; $text | Should -Match '\$Treatment=0'; $text | Should -Match 'Major-lt85' }
  It 'implements the complete reversible lifecycle' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$a'" } }
  It 'captures Edge executable identity and security evidence' { foreach($s in 'Get-AuthenticodeSignature','Microsoft Corporation','Get-FileHash','Sha256','Thumbprint'){ $text | Should -Match $s } }
  It 'captures boot machine user and original registry state before mutation' { foreach($s in 'capturedBootTime','machine=','userSid=','CandidateRecommended','State overwrite refused'){ $text | Should -Match $s } }
  It 'refuses enterprise ownership and Edge Startup-folder state' { $text | Should -Match 'enterprise management ownership detected';$text | Should -Match 'Edge Startup-folder registration detected';$text | Should -Match 'CcmExec';$text | Should -Match 'Microsoft\\Enrollments' }
  It 'holds related Edge policies and protected services against drift' { foreach($s in 'StartupBoostEnabled','BackgroundModeEnabled','NetworkPredictionOptions','WinDefend','mpssvc','wuauserv','TermService','Tailscale','edgeupdate'){ $text | Should -Match $s };$text | Should -Match 'Related Edge policy drift detected';$text | Should -Match 'Protected security update or remote-access state drift detected' }
  It 'requires browser closure for treatment verification and rollback' { $text | Should -Match 'Close Edge before application';$text | Should -Match 'Full Edge restart required before verification';$text | Should -Match 'Close Edge before rollback' }
  It 'requires a later boot for persistence verification' { $text | Should -Match 'A later boot is required';$text | Should -Match 'capturedBootTime' }
  It 'supports ShouldProcess WhatIf structured JSONL and idempotence' { $text | Should -Match 'SupportsShouldProcess';$text | Should -Match 'WhatIfPreference';$text | Should -Match 'ConvertTo-Json -Compress';$text | Should -Match "'idempotent'";$text | Should -Match 'MutationCount=0' }
  It 'uses drift-safe exact rollback including experiment-created key cleanup' { $text | Should -Match 'Rollback collision or policy drift detected';$text | Should -Match 'Exact rollback verification failed';$text | Should -Match 'original.KeyExists';$text | Should -Match 'Remove-Item \$PolicyPath' }
  It 'retains missing physical measurements as needs-evidence' { $text | Should -Match "EvidenceStatus='needs-evidence'" }
  It 'contains no protected-scope mutation commands' { $text | Should -Not -Match '(?i)Set-MpPreference|Disable-WindowsOptionalFeature|Remove-WindowsDriver|pnputil|bcdedit|manage-bde|Set-NetFirewall|Uninstall-Package|Remove-AppxPackage|Stop-Service|Set-Service|Restart-Service' }
}

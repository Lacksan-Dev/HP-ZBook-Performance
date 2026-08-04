Describe 'EXP-066 HP Network provider contract' {
  BeforeAll {$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp066HpNetwork.ps1';$text=Get-Content -LiteralPath $scriptPath -Raw}
  It 'exposes the complete reversible lifecycle' {foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text | Should -Match "'$action'"}}
  It 'requires HP Windows 11 identity and signed NetworkCap executable' {$text | Should -Match 'Windows 11 required';$text | Should -Match 'HP platform required';$text | Should -Match 'NetworkCap\\.exe';$text | Should -Match 'Get-AuthenticodeSignature';$text | Should -Match 'Get-FileHash'}
  It 'refuses managed and protected dependency scope' {$text | Should -Match 'enterprise management ownership detected';$text | Should -Match 'Protected dependency refused';$text | Should -Match 'Tailscale';$text | Should -Match 'TermService';$text | Should -Match 'Omnissa'}
  It 'captures and guards network state' {$text | Should -Match 'Get-NetAdapter';$text | Should -Match 'Get-NetAdapterBinding';$text | Should -Match 'Get-NetIPConfiguration';$text | Should -Match 'Protected network stack drift detected'}
  It 'supports dry run, idempotence, reboot verification, structured logging, and exact rollback' {$text | Should -Match 'SupportsShouldProcess=\$true';$text | Should -Match "Write-Event 'dry-run'";$text | Should -Match "'idempotent'";$text | Should -Match "'VerifyReboot'";$text | Should -Match 'capturedBootUtc';$text | Should -Match 'Restore exact captured service state';$text | Should -Match 'DelayedAutoStart'}
  It 'keeps measurement outcome evidence-gated' {$text | Should -Match "EvidenceStatus='needs-evidence'"}
}

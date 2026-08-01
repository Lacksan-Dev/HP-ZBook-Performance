$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp024HpTouchpoint.ps1'
Describe 'EXP-024 engineering contract' {
  $text=Get-Content -LiteralPath $scriptPath -Raw
  It 'uses ShouldProcess and strict candidate identity' {$text|Should Match 'SupportsShouldProcess';$text|Should Match 'HPTouchpointAnalyticsService';$text|Should Match 'Service display identity refused';$text|Should Match 'Service executable identity refused'}
  It 'requires elevation and refuses pending reboot or enterprise management' {$text|Should Match 'Elevation required';$text|Should Match 'Pending reboot detected';$text|Should Match 'Enterprise-managed domain state refused';$text|Should Match 'Enterprise MDM enrollment refused'}
  It 'enforces the HP security version floor and publisher identity' {$text|Should Match "4\.2\.2439\.0";$text|Should Match 'Get-AuthenticodeSignature';$text|Should Match 'HP publisher signature refused';$text|Should Match 'Outdated HP Touchpoint Analytics version refused'}
  It 'captures exact binary startup dependency and running state' {foreach($name in 'startMode','delayedAutoStart','executableVersion','executableHash','signatureSubject','dependencies','dependents','serviceAccount','capturedUtc'){$text|Should Match $name}}
  It 'implements the full reversible lifecycle' {foreach($name in 'Check','Capture','Apply','Verify','VerifyReboot','Rollback'){$text|Should Match "'$name'"}}
  It 'provides structured logging and idempotence' {$text|Should Match 'ConvertTo-Json -Compress';$text|Should Match 'userSid';$text|Should Match 'already-applied'}
  It 'makes WhatIf paths mutation-safe and skips treatment verification' {$text|Should Match '\$WhatIfPreference';$text|Should Match "'dry-run'";$text|Should Match "'rollback-dry-run'";$text|Should Match "'apply-declined'";$text|Should Match "'rollback-declined'"}
  It 'performs drift-aware exact rollback' {$text|Should Match 'Assert-DriftSafe';$text|Should Match 'Rollback executable hash changed';$text|Should Match 'Rollback dependencies changed';$text|Should Match 'Restore startup mode';$text|Should Match 'Rollback verification failed'}
  It 'preserves protected identities and dependencies' {foreach($name in 'Defender','SecurityHealth','Tailscale','Omnissa','RemoteDesktop','WindowsApp','WinDefend','mpssvc','wuauserv','TermService'){$text|Should Match $name}}
  It 'uses terminating failures' {$text|Should Match "ErrorActionPreference='Stop'";$text|Should Match 'throw'}
}

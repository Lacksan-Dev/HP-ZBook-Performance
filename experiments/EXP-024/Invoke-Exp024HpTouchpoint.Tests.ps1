$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp024HpTouchpoint.ps1'
Describe 'EXP-024 engineering contract' {
  $text=Get-Content -LiteralPath $scriptPath -Raw
  It 'uses ShouldProcess and strict candidate identity' { $text|Should Match 'SupportsShouldProcess';$text|Should Match 'HPTouchpointAnalyticsService';$text|Should Match 'Service executable identity refused' }
  It 'captures exact startup and running state' { $text|Should Match 'startMode';$text|Should Match 'PathName';$text|Should Match 'capturedUtc' }
  It 'implements the full reversible lifecycle' { foreach($name in 'Check','Capture','Apply','Verify','VerifyReboot','Rollback'){ $text|Should Match "'$name'" } }
  It 'provides structured logging and idempotence' { $text|Should Match 'ConvertTo-Json -Compress';$text|Should Match 'already-applied' }
  It 'preserves protected identities' { foreach($name in 'Defender','SecurityHealth','Tailscale','Omnissa','RemoteDesktop','WindowsApp'){ $text|Should Match $name } }
  It 'uses terminating failures' { $text|Should Match "ErrorActionPreference='Stop'";$text|Should Match 'throw' }
}

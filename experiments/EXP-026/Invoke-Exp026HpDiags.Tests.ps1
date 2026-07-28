$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp026HpDiags.ps1'

Describe 'EXP-026 engineering contract' {
  $text=Get-Content -LiteralPath $scriptPath -Raw

  It 'uses ShouldProcess and exact candidate identity' {
    $text|Should Match 'SupportsShouldProcess'
    $text|Should Match "ServiceName='HPDiagsCap'"
    $text|Should Match 'Service executable identity refused'
    $text|Should Match 'Service name identity refused'
  }

  It 'captures exact service state and identity' {
    foreach($token in 'startMode','displayName','PathName','computer','capturedUtc'){ $text|Should Match $token }
  }

  It 'implements the full reversible lifecycle' {
    foreach($name in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text|Should Match "'$name'" }
  }

  It 'provides structured logging, idempotence, and terminating failures' {
    $text|Should Match 'ConvertTo-Json -Compress'
    $text|Should Match 'already-applied'
    $text|Should Match "ErrorActionPreference='Stop'"
    $text|Should Match "Write-Event 'failure'"
    $text|Should Match 'throw'
  }

  It 'refuses protected identities' {
    foreach($name in 'Defender','SecurityHealth','BitLocker','Credential','Tailscale','Omnissa','RemoteDesktop','WindowsApp','Windows Update'){ $text|Should Match $name }
  }

  It 'preserves running state and restores exact state' {
    $text|Should Match 'Apply changed running state unexpectedly'
    $text|Should Match 'Start-Service'
    $text|Should Match 'Stop-Service'
    $text|Should Match 'Rollback service identity changed'
    $text|Should Match 'Rollback verification failed'
  }

  It 'avoids destructive package, file, device, and driver actions' {
    $text|Should Not Match 'Uninstall-Package|Remove-AppxPackage|pnputil|Remove-Item|Disable-PnpDevice|sc.exe delete'
  }
}

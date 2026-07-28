$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp032LogitechGHubUpdater.ps1'

Describe 'EXP-032 engineering contract' {
  $text=Get-Content -LiteralPath $scriptPath -Raw

  It 'uses ShouldProcess and exact candidate identity' {
    $text|Should Match 'SupportsShouldProcess'
    $text|Should Match "ServiceName='LGHUBUpdaterService'"
    $text|Should Match 'Service display-name identity refused'
    $text|Should Match 'Service executable identity refused'
    $text|Should Match 'Service name identity refused'
  }

  It 'captures exact service state and identity' {
    foreach($token in 'startMode','delayedAutoStart','displayName','PathName','computer','capturedUtc'){ $text|Should Match $token }
  }

  It 'implements the reversible lifecycle' {
    foreach($name in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text|Should Match "'$name'" }
  }

  It 'provides logging idempotence and terminating failures' {
    $text|Should Match 'ConvertTo-Json -Compress'
    $text|Should Match 'already-applied'
    $text|Should Match "ErrorActionPreference='Stop'"
    $text|Should Match "Write-Event 'failure'"
  }

  It 'preserves protected and device-critical surfaces' {
    foreach($name in 'Defender','SecurityHealth','BitLocker','Credential','Tailscale','Omnissa','RemoteDesktop','WindowsApp','Windows Update'){ $text|Should Match $name }
    $text|Should Not Match 'Uninstall-Package|Remove-AppxPackage|pnputil|Disable-PnpDevice|sc.exe delete'
  }

  It 'preserves and restores running and delayed-auto state' {
    $text|Should Match 'Apply changed running state unexpectedly'
    $text|Should Match 'DelayedAutoStart'
    $text|Should Match 'Start-Service'
    $text|Should Match 'Stop-Service'
    $text|Should Match 'Rollback service identity changed'
    $text|Should Match 'Rollback verification failed'
  }
}

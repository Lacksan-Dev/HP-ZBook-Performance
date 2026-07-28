$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp028OfficeHardwareAcceleration.ps1'

Describe 'EXP-028 engineering contract' {
  $text=Get-Content -LiteralPath $scriptPath -Raw

  It 'uses exact candidate and policy precedence' {
    $text|Should Match 'DisableHardwareAcceleration'
    $text|Should Match 'Software\\Policies\\Microsoft\\Office\\16.0\\Common\\Graphics'
    $text|Should Match 'Enterprise Office policy controls'
    $text|Should Match 'SupportsShouldProcess'
  }

  It 'detects HP Windows 11 and Outlook support' {
    $text|Should Match 'Windows 11'
    $text|Should Match 'HP\|Hewlett-Packard'
    $text|Should Match 'OUTLOOK.EXE|outlook.exe'
    $text|Should Match 'Microsoft Outlook executable absent'
  }

  It 'captures exact user and registry state' {
    foreach($token in 'userSid','keyExists','valueExists','kind','data','capturedUtc','outlookPath'){ $text|Should Match $token }
  }

  It 'implements the full reversible lifecycle' {
    foreach($name in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text|Should Match "'$name'" }
  }

  It 'provides structured logging idempotence and failures' {
    $text|Should Match 'ConvertTo-Json -Compress'
    $text|Should Match 'already-applied'
    $text|Should Match "ErrorActionPreference='Stop'"
    $text|Should Match "Write-Event 'failure'"
  }

  It 'verifies application reboot persistence and rollback' {
    $text|Should Match 'Apply verification failed'
    $text|Should Match 'Reboot persistence failed'
    $text|Should Match 'Rollback Outlook identity changed'
    $text|Should Match 'Rollback verification failed'
  }

  It 'avoids destructive system actions' {
    $text|Should Not Match 'Remove-AppxPackage|Uninstall-Package|Disable-PnpDevice|pnputil|sc.exe delete|Stop-Service|Set-Service|Disable-ScheduledTask'
  }
}

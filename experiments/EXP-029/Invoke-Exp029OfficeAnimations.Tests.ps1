$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp029OfficeAnimations.ps1'
Describe 'EXP-029 engineering contract' {
  $text=Get-Content -LiteralPath $scriptPath -Raw
  It 'uses the exact candidate with enterprise-policy precedence' {
    $text|Should Match 'DisableAnimations'
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
  It 'captures exact identity and current state' {
    foreach($token in 'userSid','keyExists','valueExists','kind','data','capturedUtc','outlookPath'){ $text|Should Match $token }
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
  It 'verifies application persistence and rollback' {
    $text|Should Match 'Apply verification failed'
    $text|Should Match 'Reboot persistence failed'
    $text|Should Match 'Rollback Outlook identity changed'
    $text|Should Match 'Rollback verification failed'
  }
  It 'contains no destructive system actions' {
    $text|Should Not Match 'Remove-AppxPackage|Uninstall-Package|Disable-PnpDevice|pnputil|sc.exe delete|Stop-Service|Set-Service|Disable-ScheduledTask'
  }
}

BeforeAll {
  $ScriptPath=Join-Path $PSScriptRoot 'Invoke-Exp030HpPrintScanDoctorService.ps1'
  $Text=Get-Content -LiteralPath $ScriptPath -Raw
}
Describe 'EXP-030 engineering contract' {
  It 'uses ShouldProcess' { $Text | Should -Match 'SupportsShouldProcess=\$true'; $Text | Should -Match '\$PSCmdlet\.ShouldProcess' }
  It 'implements every lifecycle action' {
    foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $Text | Should -Match "'$action'" }
  }
  It 'binds to the exact service name' { $Text | Should -Match "\$ServiceName='HPPrintScanDoctorService'" }
  It 'requires HP Windows 11' { $Text | Should -Match 'Windows 11'; $Text | Should -Match 'HP\|Hewlett-Packard' }
  It 'refuses executable identity mismatch' { $Text | Should -Match 'Service executable identity refused' }
  It 'captures and restores start mode and running state' {
    $Text | Should -Match 'startMode'
    $Text | Should -Match 'original\.state'
    $Text | Should -Match 'Start-Service'
    $Text | Should -Match 'Stop-Service'
  }
  It 'writes structured JSONL events' { $Text | Should -Match 'ConvertTo-Json -Compress'; $Text | Should -Match 'Add-Content' }
  It 'contains terminating failure handling and rollback verification' { $Text | Should -Match "\$ErrorActionPreference='Stop'"; $Text | Should -Match 'Rollback verification failed' }
  It 'does not target protected platform services' {
    $Text | Should -Not -Match "\$ServiceName='(WinDefend|mpssvc|BITS|wuauserv|CryptSvc|Tailscale|TermService|Spooler)'"
  }
}

$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp065HpSystemInfo.ps1'
Describe 'EXP-065 HP System Info controller contract' {
  BeforeAll {$text=Get-Content -LiteralPath $scriptPath -Raw}
  It 'supports ShouldProcess and WhatIf' {$text | Should -Match 'SupportsShouldProcess=\$true';$text | Should -Match '\$WhatIfPreference';$text | Should -Match 'ShouldProcess'}
  It 'targets only HPSysInfoCap' {$text | Should -Match "\$ServiceName='HPSysInfoCap'"}
  It 'requires Windows 11 and HP platform identity' {$text | Should -Match 'Windows 11';$text | Should -Match 'HP\|Hewlett-Packard'}
  It 'requires the SysInfoCap executable and HP publisher identity' {$text | Should -Match 'SysInfoCap\\\.exe';$text | Should -Match 'Get-AuthenticodeSignature';$text | Should -Match 'HP Inc\|Hewlett-Packard'}
  It 'captures executable hash and dependency state' {$text | Should -Match 'Get-FileHash';$text | Should -Match 'dependencies';$text | Should -Match 'dependents'}
  It 'refuses enterprise domain and MDM states' {$text | Should -Match 'PartOfDomain';$text | Should -Match 'Get-MdmEnrollmentDetected'}
  It 'refuses pending reboot and protected dependencies' {$text | Should -Match 'Get-PendingReboot';$text | Should -Match 'WinDefend';$text | Should -Match 'Tailscale';$text | Should -Match 'TermService'}
  It 'changes startup configuration to Manual without stopping the service during apply' {
    $apply=[regex]::Match($text,"'Apply' \{(?<body>[\s\S]*?)\n \}").Groups['body'].Value
    $apply | Should -Match "Set-Mode 'Manual'"
    $apply | Should -Not -Match 'Stop-Service'
  }
  It 'provides reboot persistence verification' {$text | Should -Match "'VerifyReboot'";$text | Should -Match 'Reboot persistence failed'}
  It 'provides structured JSONL logging' {$text | Should -Match 'ConvertTo-Json -Compress';$text | Should -Match 'events.jsonl';$text | Should -Match "experiment='EXP-065'"}
  It 'uses drift-aware exact rollback' {$text | Should -Match 'Assert-DriftSafe';$text | Should -Match 'Restore startup mode';$text | Should -Match 'Rollback verification failed'}
  It 'restores the captured running state during rollback' {$text | Should -Match "\$s.state -eq 'Running'";$text | Should -Match "\$s.state -eq 'Stopped'"}
  It 'avoids package, driver, device, firewall, and update mutation commands' {
    $text | Should -Not -Match 'Remove-AppxPackage|pnputil|Disable-NetAdapter|Remove-NetAdapter|Set-NetFirewall|Stop-Service\s+(WinDefend|mpssvc|wuauserv)'
  }
}

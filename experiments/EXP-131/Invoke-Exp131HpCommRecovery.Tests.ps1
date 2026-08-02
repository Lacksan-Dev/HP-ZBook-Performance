$p=Join-Path $PSScriptRoot 'Invoke-Exp131HpCommRecovery.ps1'
Describe 'EXP-131 HP Comm Recovery controller contract' {
 BeforeAll {$t=Get-Content $p -Raw}
 It 'supports ShouldProcess' {$t|Should -Match 'SupportsShouldProcess=\$true';$t|Should -Match 'ShouldProcess'}
 It 'discovers exact HP Comm Recovery identity' {$t|Should -Match 'HPCommRecovery\\\.exe';$t|Should -Match 'Get-AuthenticodeSignature';$t|Should -Match 'HP Inc\|Hewlett-Packard'}
 It 'requires HP Windows 11 and refuses enterprise management' {$t|Should -Match 'Windows 11';$t|Should -Match 'PartOfDomain';$t|Should -Match 'Microsoft\\Enrollments'}
 It 'captures hash dependencies and original state' {$t|Should -Match 'Get-FileHash';$t|Should -Match 'dependencies';$t|Should -Match 'startMode';$t|Should -Match 'delayed'}
 It 'applies delayed automatic without stopping the running service' {$a=[regex]::Match($t,"'Apply' \{(?<b>[\s\S]*?)\n 'Verify'").Groups['b'].Value;$a|Should -Match 'SetMode Automatic 1';$a|Should -Not -Match 'Stop-Service'}
 It 'verifies reboot persistence' {$t|Should -Match "'VerifyReboot'";$t|Should -Match 'Reboot persistence failed'}
 It 'logs structured JSONL-compatible events' {$t|Should -Match 'ConvertTo-Json -Compress';$t|Should -Match "experiment='EXP-131'"}
 It 'uses drift-aware exact rollback' {$t|Should -Match 'function Drift';$t|Should -Match 'Restore exact captured startup state';$t|Should -Match 'Rollback verification failed'}
 It 'preserves protected networking dependencies' {$t|Should -Match 'Tailscale';$t|Should -Match 'TermService';$t|Should -Match 'Dhcp';$t|Should -Match 'Dnscache'}
 It 'contains no adapter driver firewall or package mutation' {$t|Should -Not -Match 'Disable-NetAdapter|Remove-NetAdapter|pnputil|Remove-AppxPackage|Set-NetFirewall'}
}

Describe 'EXP-131 lab harness contract' {
 $p=Join-Path $PSScriptRoot 'Invoke-Exp131LabHarness.ps1'
 $text=Get-Content $p -Raw
 It 'parses as PowerShell' { $e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$e);$e.Count|Should -Be 0 }
 It 'defaults to five runs per arm' { $text|Should -Match '\[int\]\$RunsPerArm=5' }
 It 'requires distinct boots' { $text|Should -Match 'Duplicate collection from same boot refused' }
 It 'uses the EXP-131 provider as the sole service mutation surface' { $text|Should -Match "Invoke-Exp131HpCommRecovery.ps1";$text|Should -Not -Match 'Set-Service' }
 It 'captures protected remote access state' { foreach($n in 'Tailscale','TermService','Omnissa','WindowsApp'){$text|Should -Match $n} }
 It 'reports medians and MAD' { $text|Should -Match 'function Median';$text|Should -Match 'function Mad' }
 It 'gates automatic reboot' { $text|Should -Match 'AllowAutomaticReboot' }
 It 'performs rollback before completion' { $text|Should -Match 'Provider Rollback' }
}

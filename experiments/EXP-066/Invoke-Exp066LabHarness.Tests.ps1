Describe 'EXP-066 lab harness contract' {
 $path=Join-Path $PSScriptRoot 'Invoke-Exp066LabHarness.ps1'
 $text=Get-Content $path -Raw
 It 'defaults to five matched runs per arm' { $text | Should -Match '\[int\]\$RunsPerArm=5' }
 It 'uses the EXP-066 provider' { $text | Should -Match 'HPNetworkHsaService\.ps1' }
 It 'rejects duplicate boot collection' { $text | Should -Match 'Duplicate boot refused' }
 It 'captures DNS HTTPS and protected service state' { $text | Should -Match 'Resolve-DnsName'; $text | Should -Match 'Invoke-WebRequest'; $text | Should -Match 'Tailscale'; $text | Should -Match 'TermService' }
 It 'records medians and MAD' { $text | Should -Match 'function Med'; $text | Should -Match 'function Mad' }
 It 'rolls back after treatment and on stop' { ([regex]::Matches($text,'Ctrl Rollback')).Count | Should -BeGreaterThan 1 }
 It 'requires explicit automatic reboot opt in' { $text | Should -Match 'AllowAutomaticReboot' }
 It 'preserves unresolved functional observations as needs-evidence' { $text | Should -Match "hpNetworkDemandStart='needs-evidence'" }
}
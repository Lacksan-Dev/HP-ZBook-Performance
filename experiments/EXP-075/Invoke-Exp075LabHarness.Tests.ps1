$p=Join-Path $PSScriptRoot 'Invoke-Exp075LabHarness.ps1';$s=Get-Content $p -Raw
Describe 'EXP-075 lab harness contract' {
 It 'uses five runs per arm by default' { $s | Should -Match "RunsPerArm=5" }
 It 'requires explicit automatic reboot opt in' { $s | Should -Match 'AllowAutomaticReboot' }
 It 'refuses duplicate boot collection' { $s | Should -Match 'Duplicate collection from same boot refused' }
 It 'samples first 120 seconds by default' { $s | Should -Match 'SampleSeconds=120' }
 It 'captures protected services and remote access processes' { $s | Should -Match 'Tailscale';$s|Should -Match 'TermService';$s|Should -Match 'WinDefend';$s|Should -Match 'omnissa' }
 It 'attributes the exact SmartHealth executable' { $s | Should -Match 'hptpsmarthealth';$s|Should -Match 'HP TechPulse SmartHealth' }
 It 'preserves raw run evidence and summary' { $s | Should -Match 'run-\{0\}-\{1:D2\}\.json';$s|Should -Match 'summary.json' }
 It 'calculates median and MAD' { $s | Should -Match 'function Med';$s|Should -Match 'function Mad' }
 It 'records physical functional evidence fields' { $s | Should -Match 'hpServiceScanDemandStart';$s|Should -Match 'hpInsightsHealth' }
 It 'verifies treatment after reboot and rolls back exactly through provider' { $s | Should -Match 'VerifyReboot';$s|Should -Match 'Prov Rollback' }
 It 'keeps classification conservative pending physical evidence' { $s | Should -Match "classification='inconclusive'" }
}
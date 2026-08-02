$here=Split-Path -Parent $MyInvocation.MyCommand.Path
$script=Join-Path $here 'Invoke-Exp067LabHarness.ps1'
Describe 'EXP-067 reboot validation harness contract' {
 BeforeAll {$text=Get-Content $script -Raw}
 It 'defaults to five matched runs per arm' {$text|Should -Match '\[int\]\$RunsPerArm=5'}
 It 'samples the first 120 seconds by default' {$text|Should -Match '\[int\]\$SampleSeconds=120'}
 It 'targets HPDiagsCap only' {$text|Should -Match "\$ServiceName='HPDiagsCap'"}
 It 'rejects duplicate boot collection' {$text|Should -Match 'Duplicate collection from same boot refused'}
 It 'verifies treatment after reboot' {$text|Should -Match "Provider 'VerifyReboot'"}
 It 'executes exact provider rollback' {$text|Should -Match "Provider 'Rollback'"}
 It 'retains raw run JSON and summary JSON' {$text|Should -Match 'run-\{0\}-\{1:D2\}\.json';$text|Should -Match 'summary.json'}
 It 'computes median and MAD' {$text|Should -Match 'function Median';$text|Should -Match 'function Mad'}
 It 'captures protected remote access state' {$text|Should -Match 'Tailscale';$text|Should -Match 'TermService';$text|Should -Match 'omnissa'}
 It 'requires explicit automatic reboot opt in' {$text|Should -Match '\[switch\]\$AllowAutomaticReboot'}
 It 'classifies unreviewed machine evidence conservatively' {$text|Should -Match "classification='inconclusive'"}
}

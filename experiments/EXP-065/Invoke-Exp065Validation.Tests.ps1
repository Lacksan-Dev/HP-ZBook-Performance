$Path=Join-Path $PSScriptRoot 'Invoke-Exp065Validation.ps1'
Describe 'EXP-065 validation harness contract' {
 BeforeAll {$Text=Get-Content -LiteralPath $Path -Raw}
 It 'binds the hardened EXP-065 provider' {$Text|Should -Match 'HpSystemInfoHsaManualDemandStart\.ps1'}
 It 'defaults to five matched runs and 120 second sampling' {$Text|Should -Match "RunsPerArm=5";$Text|Should -Match "SampleSeconds=120"}
 It 'preserves raw per-boot evidence and rejects duplicate boots' {$Text|Should -Match 'run-\{0\}-\{1:D2\}\.json';$Text|Should -Match 'Duplicate boot refused'}
 It 'uses the reversible provider lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$Text|Should -Match $a}}
 It 'calculates medians and dispersion' {$Text|Should -Match 'function Median';$Text|Should -Match 'function Mad'}
 It 'classifies evidence outcomes' {foreach($c in 'favorable','zero-benefit','failed','inconclusive'){$Text|Should -Match $c}}
 It 'keeps functional evidence explicit' {$Text|Should -Match "hpSystemInfoDemandStart='needs-evidence'";$Text|Should -Match "hpSystemInfoWorkflow='needs-evidence'"}
 It 'observes protected services and remote access' {foreach($n in 'WinDefend','mpssvc','wuauserv','TermService','Tailscale','Omnissa','WindowsApp'){$Text|Should -Match $n}}
 It 'requires explicit automatic reboot opt in' {$Text|Should -Match 'AllowAutomaticReboot';$Text|Should -Match 'ShouldProcess'}
}

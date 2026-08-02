$p=Join-Path $PSScriptRoot 'Invoke-Exp099LabHarness.ps1';$c=Get-Content $p -Raw
Describe 'EXP-099 reboot-aware validation harness contract' {
 It 'uses the existing reversible provider' { $c | Should -Match 'LogiOptionsPlusSigninTask\.ps1'; $c | Should -Match 'Provider Apply'; $c | Should -Match 'Provider Rollback' }
 It 'requires matched repeated boots and rejects duplicates' { $c | Should -Match 'RunsPerArm=5'; $c | Should -Match 'Duplicate same-boot collection refused' }
 It 'retains raw runs and robust summaries' { $c | Should -Match 'run-'; $c | Should -Match 'function Med'; $c | Should -Match 'function Mad'; $c | Should -Match "classification='inconclusive'" }
 It 'captures protected and functional evidence boundaries' { $c | Should -Match 'WinDefend'; $c | Should -Match 'mpssvc'; $c | Should -Match 'wuauserv'; $c | Should -Match 'Tailscale'; $c | Should -Match 'TermService'; $c | Should -Match 'manualLogiOptionsPlusLaunch'; $c | Should -Match 'deviceSettingsReadiness' }
 It 'makes automatic reboot explicit and verifies reboot persistence' { $c | Should -Match 'AllowAutomaticReboot'; $c | Should -Match 'Provider VerifyReboot' }
 It 'supports dry run and exact provider restoration' { $c | Should -Match 'SupportsShouldProcess'; $c | Should -Match 'Provider DryRun'; $c | Should -Match "phase='RollbackVerify'" }
}
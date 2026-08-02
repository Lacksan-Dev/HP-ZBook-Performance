$harness=Join-Path $PSScriptRoot 'Invoke-Exp050LabHarness.ps1'
Describe 'EXP-050 reboot-aware lab harness contract' {
 BeforeAll {$text=Get-Content -LiteralPath $harness -Raw}
 It 'stays Experimental and retains missing physical evidence' {Test-Path $harness|Should -BeTrue;$text|Should -Match 'EXP-050';$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'status:stable|Stable='}
 It 'uses the merged Logi Options+ provider as sole treatment surface' {$text|Should -Match 'LogiOptionsPlusDemandLaunch.ps1';$text|Should -Match 'Provider Apply';$text|Should -Match 'Provider Rollback'}
 It 'runs support detection dry run and exact capture before treatment' {$text|Should -Match 'Provider Check';$text|Should -Match 'Provider DryRun';$text|Should -Match 'Provider Capture'}
 It 'requires five matched 120-second boot observations by default' {$text|Should -Match 'RunsPerArm=5';$text|Should -Match 'SampleSeconds=120';$text|Should -Match 'Duplicate same-boot collection refused'}
 It 'verifies treatment after reboot and exact rollback on a later boot' {$text|Should -Match 'Provider VerifyReboot';$text|Should -Match "phase='RollbackVerify'";$text|Should -Match 'rollbackRebootVerified'}
 It 'retains raw trials and robust summary statistics' {foreach($t in 'run-','cpuMedianPercent','diskMedianBytesPerSec','median=Med','mad=Mad','instrumentation'){$text|Should -Match $t}}
 It 'preserves security update and protected remote access observations' {foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService','omnissa','msrdc','mstsc','windowsapp'){$text|Should -Match $t}}
 It 'retains Logitech functionality as physical evidence' {foreach($t in 'manualLogiOptionsPlusLaunch','deviceSettingsReadiness','supportedUpdateReadiness','protectedApplicationReadiness'){$text|Should -Match $t}}
 It 'uses a reversible continuation task and explicit reboot opt in' {$text|Should -Match 'RegisterResume';$text|Should -Match 'RemoveResume';$text|Should -Match 'AllowAutomaticReboot';$text|Should -Match 'ShouldProcess'}
 It 'retains terminating failure evidence' {$text|Should -Match 'ErrorActionPreference';$text|Should -Match "'failure' 'failure'";$text|Should -Match 'throw'}
}

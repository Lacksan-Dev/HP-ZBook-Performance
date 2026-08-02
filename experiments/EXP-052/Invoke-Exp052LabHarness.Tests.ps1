$harness=Join-Path $PSScriptRoot 'Invoke-Exp052LabHarness.ps1'
Describe 'EXP-052 reboot-aware lab harness contract' {
 BeforeAll {$text=Get-Content -LiteralPath $harness -Raw}
 It 'retains Experimental evidence state' {Test-Path $harness|Should -BeTrue;$text|Should -Match 'EXP-052';$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'status:stable|Stable='}
 It 'uses the Logi Tune provider as sole treatment surface' {$text|Should -Match 'LogiTuneDemandLaunch.ps1';$text|Should -Match 'Provider Apply';$text|Should -Match 'Provider Rollback'}
 It 'runs detection dry run and capture before treatment' {$text|Should -Match 'Provider Check';$text|Should -Match 'Provider DryRun';$text|Should -Match 'Provider Capture'}
 It 'defaults to five matched 120 second boot observations' {$text|Should -Match 'RunsPerArm=5';$text|Should -Match 'SampleSeconds=120';$text|Should -Match 'Duplicate same-boot collection refused'}
 It 'verifies treatment after reboot and rollback on a later boot' {$text|Should -Match 'Provider VerifyReboot';$text|Should -Match "phase='RollbackVerify'";$text|Should -Match 'rollbackRebootVerified'}
 It 'retains raw trials and robust statistics' {foreach($t in 'run-','cpuMedianPercent','diskMedianBytesPerSec','median=Med','mad=Mad','instrumentation'){$text|Should -Match $t}}
 It 'preserves security update and remote access observations' {foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService','omnissa','msrdc','mstsc','windowsapp'){$text|Should -Match $t}}
 It 'retains Logi Tune functionality as physical evidence' {foreach($t in 'manualLogiTuneLaunch','cameraAndHeadsetReadiness','audioVideoDeviceReadiness','protectedApplicationReadiness'){$text|Should -Match $t}}
 It 'uses a reversible continuation task and explicit reboot opt in' {$text|Should -Match 'RegisterResume';$text|Should -Match 'RemoveResume';$text|Should -Match 'AllowAutomaticReboot';$text|Should -Match 'ShouldProcess'}
 It 'retains terminating failure evidence' {$text|Should -Match 'ErrorActionPreference';$text|Should -Match "'failure' 'failure'";$text|Should -Match 'throw'}
}

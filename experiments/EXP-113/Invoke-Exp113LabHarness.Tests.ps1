$harness=Join-Path $PSScriptRoot 'Invoke-Exp113LabHarness.ps1'
Describe 'EXP-113 reboot-aware lab harness contract' {
 BeforeAll {$text=Get-Content -LiteralPath $harness -Raw}
 It 'stays Experimental and retains missing physical evidence' {Test-Path $harness|Should -BeTrue;$text|Should -Match 'EXP-113';$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'status:stable|Stable='}
 It 'uses the merged Microsoft 365 sign-in task provider as sole treatment surface' {$text|Should -Match 'Microsoft365SigninTask.ps1';$text|Should -Match 'Provider Apply';$text|Should -Match 'Provider Rollback'}
 It 'requires matched repeated boots and rejects duplicate same-boot collection' {$text|Should -Match 'RunsPerArm=5';$text|Should -Match 'SampleSeconds=120';$text|Should -Match 'Duplicate same-boot collection refused'}
 It 'verifies treatment after reboot and exact rollback on a separate boot' {$text|Should -Match 'Provider VerifyReboot';$text|Should -Match "phase='RollbackVerify'";$text|Should -Match 'rollbackRebootVerified'}
 It 'preserves raw evidence and reports robust summary statistics' {foreach($t in 'run-','cpuMedianPercent','diskMedianBytesPerSec','median=Med','mad=Mad','instrumentation'){$text|Should -Match $t}}
 It 'tracks preserved security update and remote-access state' {foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService','omnissa','msrdc','mstsc','windowsapp'){$text|Should -Match $t}}
 It 'retains Office and servicing functional checks as physical evidence' {foreach($t in 'manualOfficeLaunch','clickToRunServicing','activationDocumentsAddins','protectedApplicationReadiness'){$text|Should -Match $t}}
 It 'uses a reversible continuation task and explicit automatic reboot opt-in' {$text|Should -Match 'RegisterResume';$text|Should -Match 'RemoveResume';$text|Should -Match 'AllowAutomaticReboot';$text|Should -Match 'ShouldProcess'}
 It 'retains terminating failure evidence' {$text|Should -Match 'ErrorActionPreference';$text|Should -Match "'failure' 'failure'";$text|Should -Match 'throw'}
}

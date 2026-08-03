$here=Split-Path -Parent $MyInvocation.MyCommand.Path
$path=Join-Path $here 'Invoke-Exp091LabHarness.ps1'
Describe 'EXP-091 reboot-aware lab harness contract' {
 BeforeAll {$text=Get-Content -LiteralPath $path -Raw}
 It 'targets EXP-091 and the focused G Hub provider' {$text|Should -Match "EXP-091";$text|Should -Match 'LogitechGHubSigninTask.ps1'}
 It 'defaults to five matched runs and 120-second sampling' {$text|Should -Match "RunsPerArm=5";$text|Should -Match "SampleSeconds=120"}
 It 'refuses duplicate same-boot collection' {$text|Should -Match 'Duplicate same-boot collection refused'}
 It 'retains raw evidence and computes median plus MAD' {$text|Should -Match "run-";$text|Should -Match 'function Med';$text|Should -Match 'function Mad'}
 It 'captures protected remote-access and security state' {$text|Should -Match 'WinDefend';$text|Should -Match 'mpssvc';$text|Should -Match 'wuauserv';$text|Should -Match 'Tailscale';$text|Should -Match 'TermService';$text|Should -Match 'omnissa';$text|Should -Match 'windowsapp'}
 It 'records G Hub function evidence separately from performance evidence' {$text|Should -Match 'manualGHubLaunch';$text|Should -Match 'deviceAndProfileReadiness';$text|Should -Match 'supportedUpdateCheck'}
 It 'requires explicit opt-in for automatic reboot' {$text|Should -Match 'AllowAutomaticReboot';$text|Should -Match 'Restart-Computer -Force'}
 It 'delegates treatment and rollback to the provider' {$text|Should -Match 'Provider Apply';$text|Should -Match 'Provider VerifyReboot';$text|Should -Match 'Provider Rollback'}
 It 'keeps classification conservative pending physical evidence' {$text|Should -Match "classification='inconclusive'";$text|Should -Match 'needs-evidence'}
}

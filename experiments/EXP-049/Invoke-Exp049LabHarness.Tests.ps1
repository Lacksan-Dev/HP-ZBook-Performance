$harness=Join-Path $PSScriptRoot 'Invoke-Exp049LabHarness.ps1'
Describe 'EXP-049 reboot-aware validation harness contract' {
 BeforeAll {$text=Get-Content -LiteralPath $harness -Raw}
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($harness,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0}
 It 'uses the classic Teams provider as its sole production treatment surface' {$text|Should -Match 'ClassicTeamsDemandLaunch.ps1';$text|Should -Match 'Provider Apply';$text|Should -Match 'Provider Rollback'}
 It 'runs support detection dry run and exact capture before treatment' {$text|Should -Match 'Provider Check';$text|Should -Match 'Provider DryRun';$text|Should -Match 'Provider Capture'}
 It 'refuses new Teams MSIX coexistence' {$text|Should -Match 'Get-AppxPackage -Name MSTeams';$text|Should -Match 'New Teams MSIX coexistence refused'}
 It 'defaults to five matched 120 second boot observations' {$text|Should -Match 'RunsPerArm=5';$text|Should -Match 'SampleSeconds=120';$text|Should -Match 'Duplicate same-boot collection refused'}
 It 'verifies treatment after reboot and exact rollback on a later boot' {$text|Should -Match 'Provider VerifyReboot';$text|Should -Match "phase='RollbackVerify'";$text|Should -Match 'rollbackRebootVerified'}
 It 'retains raw trials medians MAD and instrumentation evidence' {foreach($t in 'run-','cpuMedianPercent','diskMedianBytesPerSec','median=Med','mad=Mad','instrumentation'){$text|Should -Match $t}}
 It 'captures classic Teams process and functional evidence' {foreach($t in 'entry.Teams.Path','manualTeamsLaunch','teamsSignInReadiness','teamsMeetingReadiness','teamsUpdateReadiness'){$text|Should -Match $t}}
 It 'preserves Windows safety and protected remote access observations' {foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService','omnissa','msrdc','mstsc','windowsapp'){$text|Should -Match $t}}
 It 'uses a reversible continuation task and explicit reboot opt in' {$text|Should -Match 'RegisterResume';$text|Should -Match 'RemoveResume';$text|Should -Match 'AllowAutomaticReboot';$text|Should -Match 'ShouldProcess'}
 It 'retains failed inconclusive and missing physical evidence' {$text|Should -Match "classification='inconclusive'";$text|Should -Match 'needs-evidence';$text|Should -Match "'failure' 'failure'"}
 It 'contains no broad application package service device driver or security mutation' {$text|Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Set-Service|Stop-Service|Disable-PnpDevice|Remove-PnpDevice|pnputil|Set-MpPreference|Disable-WindowsOptionalFeature'}
}

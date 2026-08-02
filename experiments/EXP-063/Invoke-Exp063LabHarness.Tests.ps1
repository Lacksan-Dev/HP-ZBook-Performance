$sut=Join-Path $PSScriptRoot 'Invoke-Exp063LabHarness.ps1'
Describe 'EXP-063 reboot-aware lab harness contract' {
 BeforeAll {$text=Get-Content -LiteralPath $sut -Raw}
 It 'targets only EXP-063 and HPAppHelperCap' {$text|Should -Match "experiment='EXP-063'";$text|Should -Match "ServiceName='HPAppHelperCap'"}
 It 'defaults to five matched runs per arm and 120 second sampling' {$text|Should -Match "RunsPerArm=5";$text|Should -Match "SampleSeconds=120";$text|Should -Match "'Baseline','Treatment'"}
 It 'supports persisted reboot continuation without stored credentials' {$text|Should -Match 'New-ScheduledTaskTrigger -AtLogOn';$text|Should -Match 'Interactive';$text|Should -Not -Match '(?i)password|autologon'}
 It 'requires explicit automatic reboot permission' {$text|Should -Match 'AllowAutomaticReboot';$text|Should -Match "if\(\$AllowAutomaticReboot\)"}
 It 'uses the provider lifecycle and exact rollback' {foreach($a in "'Check'","'Capture'","'Apply'","'VerifyReboot'","'Rollback'"){$text|Should -Match [regex]::Escape($a)}}
 It 'preserves raw runs and reports median plus MAD' {$text|Should -Match 'run-';$text|Should -Match 'Get-Median';$text|Should -Match 'Get-Mad';$text|Should -Match 'summary.json'}
 It 'captures service resource attribution and protected remote access state' {foreach($t in 'cpuDeltaMs','readDeltaBytes','writeDeltaBytes','Tailscale','TermService','windowsapp','omnissa'){$text|Should -Match $t}}
 It 'keeps physical HP application checks evidence-gated' {$text|Should -Match "hpApplicationDemandStart='needs-evidence'";$text|Should -Match "hpUpdateDiscovery='needs-evidence'"}
 It 'refuses duplicate collection from one boot' {$text|Should -Match 'Duplicate collection from same boot refused'}
}

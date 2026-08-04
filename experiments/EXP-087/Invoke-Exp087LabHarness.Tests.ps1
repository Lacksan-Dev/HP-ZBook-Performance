$sut=Join-Path $PSScriptRoot 'Invoke-Exp087LabHarness.ps1'
Describe 'EXP-087 lab harness contract' {
 BeforeAll {$text=Get-Content -LiteralPath $sut -Raw}
 It 'defaults to five matched runs and 120-second sampling' {$text|Should -Match "RunsPerArm=5";$text|Should -Match "SampleSeconds=120"}
 It 'supports baseline treatment reboot continuation and duplicate-boot refusal' {$text|Should -Match "phase='Baseline'";$text|Should -Match "phase='Treatment'";$text|Should -Match 'Duplicate collection from same boot refused';$text|Should -Match 'VerifyReboot'}
 It 'delegates treatment and exact rollback to the hardened EXP-087 provider' {$text|Should -Match 'HpSupportSolutionsFrameworkManualDemandStart.ps1';$text|Should -Match "Provider 'Apply'";$text|Should -Match "Provider 'Rollback'";$text|Should -Match 'AcknowledgeHpWorkflowValidation'}
 It 'captures state and executes provider dry run before registering the physical baseline' {$text|Should -Match "Provider 'Capture'.*Provider 'DryRun'.*WriteJson.*Harness"}
 It 'verifies treatment immediately after application before reboot continuation' {$text|Should -Match "Provider 'Apply'.*Provider 'Verify'"}
 It 'retains raw runs and reports median plus MAD' {$text|Should -Match 'run-\{0\}-\{1:D2\}\.json';$text|Should -Match 'function Median';$text|Should -Match 'function Mad';$text|Should -Match 'cpuMedianPercent';$text|Should -Match 'diskMedianBytesPerSec'}
 It 'captures protected remote-access and security observations' {$text|Should -Match 'WinDefend';$text|Should -Match 'mpssvc';$text|Should -Match 'TermService';$text|Should -Match 'Tailscale';$text|Should -Match 'windowsapp';$text|Should -Match 'omnissa'}
 It 'preserves unresolved HP workflow evidence explicitly' {$text|Should -Match 'hpProductDetection';$text|Should -Match 'hpDiagnostics';$text|Should -Match 'localhostEndpoint';$text|Should -Match 'demandOrManualStart';$text|Should -Match 'needs-evidence'}
 It 'requires explicit automatic reboot opt-in' {$text|Should -Match 'AllowAutomaticReboot';$text|Should -Match 'reboot-required'}
 It 'uses a Windows PowerShell compatible unattended continuation' {$text|Should -Match '\[switch\]\$Unattended';$text|Should -Match "if\(\$Unattended\)\{\$ConfirmPreference='None'\}";$text|Should -Match '-NonInteractive';$text|Should -Match '-Action Continue -Unattended'}
 It 'preserves explicit automatic reboot authorization in the scheduled continuation' {$text|Should -Match "if\(\$AllowAutomaticReboot\)\{\$arg\+=' -AllowAutomaticReboot'\}"}
 It 'suppresses nested provider confirmation prompts without widening provider scope' {$text|Should -Match 'AcknowledgeHpWorkflowValidation -Confirm:\$false';$text|Should -Match 'Set-Service' -Not}
}

$provider=Join-Path $PSScriptRoot '..\providers\EdgeTrueDemandLaunch.ps1'
Describe 'EXP-054 Edge true demand-launch provider contract' {
 BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)|Out-Null;@($errors).Count|Should -Be 0}
 It 'implements the full reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"}}
 It 'targets one recommended Startup Boost DWORD zero' {foreach($t in 'StartupBoostEnabled','Recommended','DWord','Treatment=0','MutationCount=1'){$text|Should -Match $t};$text|Should -Not -Match 'Stop-Service|Set-Service|Disable-ScheduledTask|Remove-AppxPackage'}
 It 'requires HP Windows 11 elevation and Microsoft-signed Edge 88 or later' {foreach($t in 'Windows 11 required','HP platform required','elevation required','Microsoft-signed Edge 88+ required','Get-AuthenticodeSignature','ValidMicrosoft'){$text|Should -Match ([regex]::Escape($t))}}
 It 'refuses existing policy ownership and Edge Startup-folder entries' {foreach($t in 'existing StartupBoostEnabled policy ownership detected','Edge Startup-folder registration detected','CandidateMandatory','CandidateRecommended'){$text|Should -Match ([regex]::Escape($t))}}
 It 'captures related Edge policy state and preserves it against drift' {foreach($t in 'BackgroundModeEnabled','SleepingTabsEnabled','EfficiencyModeEnabled','LaunchEdgeOnWindowsStartupEnabled','Related Edge policy drift detected'){$text|Should -Match ([regex]::Escape($t))}}
 It 'preserves security update Edge Update and protected remote-access services' {foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','edgeupdate','Protected security update or remote-access state drift detected'){$text|Should -Match ([regex]::Escape($t))}}
 It 'supports dry run WhatIf structured logging idempotence failure evidence and reboot verification' {foreach($t in 'SupportsShouldProcess','WhatIfPreference','ConvertTo-Json -Compress','idempotent','failureDetail','A later boot is required','Treatment failed reboot persistence'){$text|Should -Match ([regex]::Escape($t))}}
 It 'implements collision-safe exact rollback' {foreach($t in 'Rollback collision or policy drift detected','RegistryValueKind','Exact rollback verification failed','restoredExactOriginal'){$text|Should -Match ([regex]::Escape($t))}}
 It 'preserves Experimental evidence state' {$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'status:stable|Stable='}
}

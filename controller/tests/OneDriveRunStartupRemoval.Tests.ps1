$provider=Join-Path $PSScriptRoot '..\providers\OneDriveRunStartupRemoval.ps1'
$text=Get-Content -LiteralPath $provider -Raw
Describe 'EXP-092 OneDrive Run startup removal contract' {
 It 'uses the EXP-092 identity' { $text|Should -Match "\$Experiment='EXP-092'" }
 It 'supports the full reversible action surface' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"} }
 It 'targets only the current-user Run registration' { $text|Should -Match "\$RunPath='Software\\Microsoft\\Windows\\CurrentVersion\\Run'"; $text|Should -Match 'RegistryHive\]::CurrentUser' }
 It 'requires Windows 11 and HP support detection' { $text|Should -Match 'Windows 11 required';$text|Should -Match 'HP platform required' }
 It 'requires Microsoft signature and OneDrive executable identity' { $text|Should -Match 'MicrosoftSigned';$text|Should -Match 'OneDrive\\\.exe';$text|Should -Match '/background' }
 It 'refuses enterprise management and OneDrive policy ownership' { $text|Should -Match 'Enterprise management ownership detected';$text|Should -Match 'OneDrive policy ownership detected' }
 It 'captures sync-root identity and refuses drift' { $text|Should -Match 'Get-SyncRoots';$text|Should -Match 'OneDrive account or sync-root drift detected' }
 It 'captures exact registry type and unexpanded data' { $text|Should -Match 'DoNotExpandEnvironmentNames';$text|Should -Match 'RegistryValueKind' }
 It 'implements dry run and ShouldProcess WhatIf semantics' { $text|Should -Match "'DryRun'";$text|Should -Match 'ShouldProcess';$text|Should -Match "'whatif'" }
 It 'uses structured JSONL evidence logging' { $text|Should -Match 'ConvertTo-Json -Compress';$text|Should -Match 'Add-Content';$text|Should -Match "evidenceStatus='needs-evidence'" }
 It 'preserves protected security update and remote access services' { foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$text|Should -Match $n} }
 It 'is idempotent for apply and rollback' { $text|Should -Match 'already-applied';$text|Should -Match 'already-restored' }
 It 'requires a later boot for persistence verification' { $text|Should -Match 'A later boot is required for persistence verification' }
 It 'refuses rollback collisions' { $text|Should -Match 'Rollback collision detected; overwrite refused' }
 It 'retains terminating failures in the event log' { $text|Should -Match "\$ErrorActionPreference='Stop'";$text|Should -Match "Write-Event 'failure' 'fail'" }
 It 'does not contain destructive uninstall or service mutation commands' { $text|Should -Not -Match 'Uninstall-Package|Remove-AppxPackage|sc\.exe\s+(delete|config)|Set-Service|Stop-Service|Remove-Item\s+.*OneDrive' }
}

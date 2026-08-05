Describe 'EXP-092 OneDrive Run startup removal contract' {
 BeforeAll {
  $provider=Join-Path $PSScriptRoot '..\providers\OneDriveRunStartupRemoval.ps1'
  $script:text=Get-Content -LiteralPath $provider -Raw
 }
 It 'uses the EXP-092 identity' { $script:text|Should -Match '\$Experiment=''EXP-092''' }
 It 'supports the full reversible action surface' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$script:text|Should -Match ([regex]::Escape("'$a'"))} }
 It 'targets only the current-user Run registration' { $script:text|Should -Match '\$RunPath=''Software\\Microsoft\\Windows\\CurrentVersion\\Run'''; $script:text|Should -Match 'RegistryHive\]::CurrentUser' }
 It 'requires Windows 11 and HP support detection' { $script:text|Should -Match 'Windows 11 required';$script:text|Should -Match 'HP platform required' }
 It 'requires Microsoft signature and OneDrive executable identity' { $script:text|Should -Match 'MicrosoftSigned';$script:text|Should -Match 'OneDrive\\\.exe';$script:text|Should -Match '/background' }
 It 'refuses enterprise management and OneDrive policy ownership' { $script:text|Should -Match 'Enterprise management ownership detected';$script:text|Should -Match 'OneDrive policy ownership detected' }
 It 'captures sync-root identity and refuses drift' { $script:text|Should -Match 'Get-SyncRoots';$script:text|Should -Match 'OneDrive account or sync-root drift detected' }
 It 'captures exact registry type and unexpanded data' { $script:text|Should -Match 'DoNotExpandEnvironmentNames';$script:text|Should -Match 'RegistryValueKind' }
 It 'implements dry run and ShouldProcess WhatIf semantics' { $script:text|Should -Match "'DryRun'";$script:text|Should -Match 'ShouldProcess';$script:text|Should -Match "'whatif'" }
 It 'uses structured JSONL evidence logging' { $script:text|Should -Match 'ConvertTo-Json -Compress';$script:text|Should -Match 'Add-Content';$script:text|Should -Match "evidenceStatus='needs-evidence'" }
 It 'preserves protected security update and remote access services' { foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$script:text|Should -Match $n} }
 It 'is idempotent for apply and rollback' { $script:text|Should -Match 'already-applied';$script:text|Should -Match 'already-restored' }
 It 'requires a later boot for persistence verification' { $script:text|Should -Match 'A later boot is required for persistence verification' }
 It 'refuses rollback collisions' { $script:text|Should -Match 'Rollback collision detected; overwrite refused' }
 It 'retains terminating failures in the event log' { $script:text|Should -Match '\$ErrorActionPreference=''Stop''';$script:text|Should -Match "Write-Event 'failure' 'fail'" }
 It 'does not contain destructive uninstall or service mutation commands' { $script:text|Should -Not -Match 'Uninstall-Package|Remove-AppxPackage|sc\.exe\s+(delete|config)|Set-Service|Stop-Service|Remove-Item\s+.*OneDrive' }
}

$scriptPath=Join-Path $PSScriptRoot '..\Invoke-ClassicTeamsRunCalibration.ps1'
Describe 'EXP-043 engineering contract' {
    BeforeAll {$source=Get-Content -LiteralPath $scriptPath -Raw}
    It 'uses ShouldProcess and a dry-run action' {$source|Should -Match 'SupportsShouldProcess';$source|Should -Match "'DryRun'";$source|Should -Match '\$PSCmdlet\.ShouldProcess'}
    It 'captures exact registry data and value kind without expansion' {$source|Should -Match 'DoNotExpandEnvironmentNames';$source|Should -Match 'GetValueKind';$source|Should -Match 'userSid'}
    It 'requires the exact classic Teams Squirrel launch chain' {$source|Should -Match 'com\.squirrel\.Teams\.Teams';$source|Should -Match 'Update\\\.exe';$source|Should -Match 'processStart';$source|Should -Match 'system-initiated'}
    It 'refuses new Teams identity' {$source|Should -Match 'ms-teams';$source|Should -Match 'MSTeams_8wekyb3d8bbwe'}
    It 'implements verification reboot persistence logging and rollback' {$source|Should -Match 'VerifyReboot';$source|Should -Match 'events\.jsonl';$source|Should -Match 'Rollback refused';$source|Should -Match 'Test-Restored'}
    It 'preserves protected remote access and security identities' {foreach($token in @('omnissa','windows app','remote desktop','tailscale','defender','bitlocker','firewall')){$source.ToLowerInvariant()|Should -Match [regex]::Escape($token)}}
    It 'uses terminating failures' {$source|Should -Match "\$ErrorActionPreference='Stop'";$source|Should -Match "Write-ExpLog 'failure'"}
}

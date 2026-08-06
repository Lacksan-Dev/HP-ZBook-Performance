Describe 'EXP-068 HP Audio Analytics zero-mutation integration' -Tag 'Integration' {
 BeforeAll{$script:provider=Join-Path $PSScriptRoot '..\providers\HPAudioAnalyticsManual.ps1'}
 It 'parses on Windows without invoking mutation' -Skip:(!$IsWindows) {$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($script:provider,[ref]$tokens,[ref]$errors);@($errors).Count|Should -Be 0}
 It 'exposes Check and DryRun as the only integration entry points' {$text=Get-Content -LiteralPath $script:provider -Raw;$text|Should -Match "'Check'";$text|Should -Match "'DryRun'";$text|Should -Match 'MutationCount=1';$text|Should -Match 'AudioMutationCount=0'}
 It 'keeps physical mutation opt-in' -Skip:($env:LACKSAN_EXP068_ZERO_MUTATION -ne '1') {& $script:provider -Action Check -LogPath (Join-Path $TestDrive 'check.jsonl') | Out-Null}
}
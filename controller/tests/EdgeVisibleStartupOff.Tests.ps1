$provider = Join-Path $PSScriptRoot '..\providers\EdgeVisibleStartupOff.ps1'
Describe 'EdgeVisibleStartupOff contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw; $tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors) }
    It 'parses as PowerShell' { $errors.Count | Should -Be 0 }
    It 'declares the complete reversible lifecycle' { foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$action'" } }
    It 'targets one mandatory Edge 152 visible-startup policy value' { $text | Should -Match [regex]::Escape('HKLM:\SOFTWARE\Policies\Microsoft\Edge');$text | Should -Match 'LaunchEdgeOnWindowsStartupEnabled';$text | Should -Match 'Major-ge152';$text | Should -Match "Value=0" }
    It 'requires HP Windows 11 elevation Microsoft signature and unmanaged ownership' { foreach($token in 'Windows 11','Hewlett-Packard','Test-Elevated','ValidPublisher','Management ownership'){ $text | Should -Match $token } }
    It 'preserves the Startup folder and related demand-launch policy state' { foreach($token in 'Get-StartupFolderState','EdgeEntryCount','StartupBoostEnabled','BackgroundModeEnabled','Related Edge policy drift detected'){ $text | Should -Match $token } }
    It 'captures exact state and binds evidence to machine user boot Edge and protected scope' { foreach($token in 'schemaVersion','capturedBootTime','machine','userSid','original','edge','protectedScope','State overwrite refused'){ $text | Should -Match $token } }
    It 'supports dry run WhatIf structured logging idempotence failure retention and exact rollback' { foreach($token in 'DryRun','WhatIfPreference','ConvertTo-Json -Compress','idempotent','catch','failure','Policy drift detected','restoredExactOriginal'){ $text | Should -Match $token } }
    It 'requires browser restart and observed reboot persistence' { $text | Should -Match 'BrowserRestartRequired=\$true';$text | Should -Match 'A later boot is required';$text | Should -Match 'Reboot persistence failed' }
    It 'avoids protected mutation primitives and Stable assignment' { $text | Should -Not -Match 'Stop-Service|Set-Service|Disable-ScheduledTask|Remove-AppxPackage|Remove-Item.*User Data|Set-MpPreference|status:stable|Stable=' }
}

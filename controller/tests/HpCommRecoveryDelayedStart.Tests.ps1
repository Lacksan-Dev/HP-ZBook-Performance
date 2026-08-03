$provider=Join-Path $PSScriptRoot '..\providers\HpCommRecoveryDelayedStart.ps1'
Describe 'EXP-131 HP Comm Recovery delayed-start provider contract' {
 BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)|Out-Null;@($errors).Count|Should -Be 0}
 It 'supports the full reversible lifecycle' {@('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')|%{$text|Should -Match "'$_'"}}
 It 'discovers exact HP Comm Recovery identity rather than assuming a service name' {$text|Should -Match 'HPCommRecovery\\\.exe';$text|Should -Match 'rows.Count-ne1';$text|Should -Match 'ValidHp'}
 It 'implements Automatic Delayed Start without stopping application-time service state' {$text|Should -Match 'DelayedAutoStart';$text|Should -Match 'Set-Service.*StartupType Automatic';$text|Should -Not -Match "'Apply'.*Stop-Service"}
 It 'captures executable hash and publisher identity' {$text|Should -Match 'SHA256';$text|Should -Match 'Thumbprint';$text|Should -Match 'Get-AuthenticodeSignature'}
 It 'refuses enterprise management and dependency-sensitive candidates' {$text|Should -Match 'enterprise management ownership detected';$text|Should -Match 'dependency-sensitive service refused'}
 It 'preserves protected security update and remote-access observations' {$text|Should -Match 'WinDefend';$text|Should -Match 'mpssvc';$text|Should -Match 'wuauserv';$text|Should -Match 'TermService';$text|Should -Match 'Tailscale'}
 It 'has structured logging dry run idempotence reboot verification and exact rollback' {$text|Should -Match 'ConvertTo-Json -Compress';$text|Should -Match 'dry-run';$text|Should -Match 'idempotent';$text|Should -Match 'VerifyReboot';$text|Should -Match 'Exact rollback verification failed'}
 It 'retains physical evidence pending and avoids release promotion' {$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'Stable'}
 It 'contains no driver package security or destructive service commands' {$text|Should -Not -Match 'Disable-PnpDevice|pnputil|Remove-AppxPackage|sc\.exe\s+delete|Set-MpPreference|Disable-WindowsOptionalFeature'}
}

$provider=Join-Path $PSScriptRoot '..\providers\HpDiagnosticsHsaManualDemandStart.ps1'
Describe 'EXP-067 HP Diagnostics HSA Manual demand-start contract' {
 BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as PowerShell' {$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$t,[ref]$e)|Out-Null;@($e).Count|Should -Be 0}
 It 'implements the reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"}}
 It 'requires exact HP diagnostics identity' {foreach($x in 'HPDiagsCap','HP Diagnostics HSA Service','DiagsCap.exe','Get-AuthenticodeSignature','Get-FileHash','ValidHp'){$text|Should -Match ([regex]::Escape($x))}}
 It 'requires HP Windows 11 elevation unmanaged ownership and safe service boundaries' {foreach($x in 'Windows 11 required','HP platform required','elevation required','enterprise management ownership detected','driver-backed service refused','dependency-sensitive service refused'){$text|Should -Match ([regex]::Escape($x))}}
 It 'captures startup delayed running executable machine user and boot state' {foreach($x in 'StartMode','RegistryStart','DelayedAutoStart','State=','PathName','Sha256','Thumbprint','machine=','userSid=','capturedBootTime'){$text|Should -Match $x}}
 It 'changes only startup type to Manual while preserving running state' {$text|Should -Match 'Set-Service -Name \$c.Name -StartupType Manual';$text|Should -Match 'PreserveRunningState';$text|Should -Not -Match 'Remove-Service|sc\.exe\s+delete|Remove-AppxPackage|pnputil|Disable-PnpDevice'}
 It 'preserves security updates and remote access against drift' {foreach($x in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','Protected security update or remote-access state drift detected'){$text|Should -Match ([regex]::Escape($x))}}
 It 'supports dry run WhatIf structured logging idempotence and later-boot verification' {foreach($x in 'dry-run','WhatIfPreference','ConvertTo-Json -Compress','idempotent','Later boot required','Treatment failed reboot persistence'){$text|Should -Match ([regex]::Escape($x))}}
 It 'restores delayed-start existence type raw value and original running state' {foreach($x in 'RegistryValueKind','Remove-ItemProperty','Start-Service','Stop-Service','Exact rollback verification failed','restoredExactOriginal'){$text|Should -Match $x}}
 It 'retains physical validation as needs-evidence and avoids Stable assignment' {$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'status:stable|Stable='}
}

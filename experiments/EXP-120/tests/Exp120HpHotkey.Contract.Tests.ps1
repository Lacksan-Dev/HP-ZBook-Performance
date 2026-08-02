$sut=Join-Path $PSScriptRoot '..\Invoke-Exp120HpHotkey.ps1'
Describe 'EXP-120 HP Hotkey controller contract' {
 BeforeAll {$text=Get-Content $sut -Raw}
 It 'uses ShouldProcess and exposes dry run' {$text|Should -Match 'SupportsShouldProcess';$text|Should -Match 'WhatIfPreference';$text|Should -Match "'dry-run'"}
 It 'captures exact state before treatment' {$text|Should -Match "'Capture'";$text|Should -Match 'DelayedAutoStart';$text|Should -Match 'Get-FileHash';$text|Should -Match 'Get-AuthenticodeSignature'}
 It 'enforces HP security bulletin minimum' {$text|Should -Match '8\.10\.50\.393';$text|Should -Match 'HPSBHF04102'}
 It 'uses delayed automatic treatment' {$text|Should -Match 'Set Automatic Delayed Start';$text|Should -Match 'SetMode Automatic 1'}
 It 'preserves current running state during apply' {($text -split "'Rollback'")[0]|Should -Not -Match 'Stop-Service'}
 It 'has reboot verification and exact rollback' {$text|Should -Match "'VerifyReboot'";$text|Should -Match "'Rollback'";$text|Should -Match 'Drift'}
 It 'refuses enterprise management and protected dependencies' {$text|Should -Match 'PartOfDomain';$text|Should -Match 'Microsoft\\Enrollments';$text|Should -Match 'Tailscale';$text|Should -Match 'TermService'}
 It 'emits structured JSONL-compatible events' {$text|Should -Match 'ConvertTo-Json -Compress';$text|Should -Match 'experiment=.EXP-120.'}
}

$provider = Join-Path $PSScriptRoot '..\providers\EdgeHideFirstRunExperience.ps1'
Describe 'EdgeHideFirstRunExperience provider contract' {
 BeforeAll { $text=Get-Content -LiteralPath $provider -Raw }
 It 'stays Experimental and avoids forbidden labels' { Test-Path $provider|Should -BeTrue; $text|Should -Match 'EXP-138';$text|Should -Match 'EdgeHideFirstRunExperience';$text|Should -Not -Match 'status:stable|Stable=';$text|Should -Not -Match "'blocked'|\"blocked\"" }
 It 'implements complete reversible lifecycle' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"} }
 It 'targets only HideFirstRunExperience DWORD 1' { foreach($t in 'HideFirstRunExperience','DWord','Value=1','MutationCount=1'){$text|Should -Match $t};$text|Should -Not -Match 'Set-Service|Stop-Service|Disable-ScheduledTask|Remove-AppxPackage|Remove-Item .*User Data|Remove-Item .*Profile' }
 It 'requires HP Windows 11 elevation Edge 80 Microsoft publisher and controlled pristine fixture' { foreach($t in 'Windows 11','Hewlett-Packard','Test-Elevated','-ge 80','Microsoft Corporation','controlledPristineProfile','firstRunComplete','ProfileFixturePath'){$text|Should -Match ([regex]::Escape($t))} }
 It 'captures Edge identity related policies management startup and protected scope' { foreach($t in 'Sha256','Thumbprint','StartupBoostEnabled','BackgroundModeEnabled','SleepingTabsEnabled','BrowserSignin','Get-Management','Get-StartupFolders','Get-Protected','capturedBootTime','userSid'){$text|Should -Match $t} }
 It 'has dry run WhatIf structured logs idempotence and terminating failure evidence' { foreach($t in 'DryRun','WhatIfPreference','Write-Log','ConvertTo-Json -Compress','idempotent','catch','failure'){$text|Should -Match $t} }
 It 'requires reboot persistence and exact drift-safe rollback' { foreach($t in 'A later boot is required','Reboot persistence failed','rollback overwrite refused','Exact rollback verification failed','restoredExactOriginal'){$text|Should -Match $t} }
 It 'preserves Windows security update Edge Update and Tailscale service configuration' { foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','edgeupdate','edgeupdatem','Protected service configuration drift detected'){$text|Should -Match $t} }
}

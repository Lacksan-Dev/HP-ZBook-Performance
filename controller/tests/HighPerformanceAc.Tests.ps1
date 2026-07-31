$provider=Join-Path $PSScriptRoot '..\providers\HighPerformanceAc.ps1'
Describe 'HighPerformanceAc contract' {
 BeforeAll{$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as PowerShell'{[scriptblock]::Create($text)|Should -Not -BeNullOrEmpty}
 It 'exposes the complete reversible lifecycle'{foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"}}
 It 'supports dry run WhatIf and ShouldProcess'{foreach($t in 'SupportsShouldProcess','WhatIfPreference','ShouldProcess','dry-run'){$text|Should -Match $t}}
 It 'requires HP Windows 11 elevation AC and unmanaged state'{foreach($t in 'Windows 11','Hewlett-Packard','Test-Elevated','AcConnected','DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr'){$text|Should -Match $t}}
 It 'uses only the canonical existing High performance scheme'{ $text|Should -Match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c';$text|Should -Match '/setactive';$text|Should -Not -Match '/duplicatescheme|/import|/delete|/setacvalueindex|/setdcvalueindex' }
 It 'captures state and verifies reboot persistence'{foreach($t in 'capturedBootTime','schemeInventory','State overwrite refused','VerifyReboot','A later boot is required'){$text|Should -Match $t}}
 It 'logs failures and implements idempotence and exact rollback'{foreach($t in "'failure' 'fail'","'idempotent'",'Active-scheme drift','Rollback drift refusal','restoredExactOriginal'){$text|Should -Match $t}}
 It 'contains no security driver update or remote-access mutation commands'{ $text|Should -Not -Match 'Set-MpPreference|Disable-NetFirewall|manage-bde|pnputil|Remove-Service|sc\.exe\s+delete|Uninstall-Package|Remove-AppxPackage|Disable-ScheduledTask' }
}

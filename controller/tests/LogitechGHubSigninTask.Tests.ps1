$provider=Join-Path $PSScriptRoot '..\providers\LogitechGHubSigninTask.ps1'
Describe 'EXP-091 LogitechGHubSigninTask provider contract' {
 BeforeAll{$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as valid PowerShell'{[scriptblock]::Create($text)|Should -Not -BeNullOrEmpty}
 It 'declares Experimental scope only'{ $text|Should -Match 'EXP-091';$text|Should -Match 'LogitechGHubSigninTask';$text|Should -Not -Match 'status:stable|stage:stable|Stable=' }
 It 'implements the complete reversible lifecycle'{foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"}}
 It 'requires HP Windows 11 elevation and management refusal'{foreach($t in 'Windows 11','Hewlett-Packard','Test-Elevated','DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','Enterprise-management ownership detected'){$text|Should -Match [regex]::Escape($t)}}
 It 'matches one Logitech signed G Hub logon task only'{foreach($t in 'LogonTrigger','lghub','lghub_agent','lghub_updater','ValidPublisher','Exactly one eligible Logitech G Hub sign-in task'){$text|Should -Match [regex]::Escape($t)};$text|Should -Match 'firmware\|dfu\|driver\|uninstall\|repair'}
 It 'captures exact task and executable evidence'{foreach($t in 'Xml','XmlSha256','TaskName','TaskPath','Author','Principal','Arguments','WorkingDirectory','Sha256','FileVersion','Publisher','Thumbprint','LastRunTime','LastTaskResult','NextRunTime','capturedBootTime'){$text|Should -Match $t}}
 It 'supports dry run WhatIf ShouldProcess structured logs and idempotence'{foreach($t in 'SupportsShouldProcess','WhatIfPreference','ShouldProcess','WouldChange','ConvertTo-Json -Compress',"'idempotent'"){$text|Should -Match $t}}
 It 'limits mutation to task enabled state'{ $text|Should -Match 'Disable-ScheduledTask';$text|Should -Match 'Enable-ScheduledTask';$text|Should -Not -Match 'Unregister-ScheduledTask|Register-ScheduledTask|Remove-Item|Remove-AppxPackage|Uninstall-Package|pnputil|Set-Service|Stop-Service|Remove-Service' }
 It 'requires observed reboot persistence and exact drift-aware rollback'{foreach($t in 'A later boot is required','Task-definition drift detected','Task executable identity drift detected','Protected-scope drift detected','Exact rollback verification failed','restoredExactOriginal'){$text|Should -Match [regex]::Escape($t)}}
 It 'preserves protected Windows remote access and device scope'{foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','omnissa','windows app','remote desktop','bitlocker','credential','recovery','intune','sccm','mdm','PreserveDrivers'){$text|Should -Match $t}}
 It 'retains terminating failure evidence'{ $text|Should -Match "'failure' 'fail'";$text|Should -Match '\$ErrorActionPreference=''Stop''';$text|Should -Match 'throw' }
}

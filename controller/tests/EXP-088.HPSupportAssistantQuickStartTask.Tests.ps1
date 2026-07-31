BeforeAll{$script=Join-Path $PSScriptRoot '..\providers\HPSupportAssistantQuickStartTask.ps1';$text=Get-Content $script -Raw}
Describe 'EXP-088 HP Support Assistant Quick Start task provider contract'{
 It 'uses ShouldProcess and bounded actions'{$text|Should -Match 'SupportsShouldProcess';$text|Should -Match "ValidateSet\('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'\)"}
 It 'requires HP Windows 11 elevation and management refusal'{$text|Should -Match 'Windows 11';$text|Should -Match 'Manufacturer';$text|Should -Match 'Elevation is required';$text|Should -Match 'Enterprise-management signals'}
 It 'requires exactly one signed HP logon candidate'{$text|Should -Match 'Exactly one eligible';$text|Should -Match 'LogonTrigger';$text|Should -Match 'AuthenticodeSignature';$text|Should -Match 'HP Inc|Hewlett-Packard'}
 It 'rejects protected task purposes'{$text|Should -Match 'firmware\|bios\|driver\|security\|recovery';$text|Should -Match 'update service'}
 It 'captures exact task XML and identity'{$text|Should -Match 'Export-ScheduledTask';$text|Should -Match 'XmlHash';$text|Should -Match 'ExecutableHash';$text|Should -Match 'Publisher';$text|Should -Match 'LastTaskResult'}
 It 'mutates only task enabled state'{$text|Should -Match 'Disable-ScheduledTask';$text|Should -Match 'Enable-ScheduledTask';$text|Should -Not -Match 'Unregister-ScheduledTask|Register-ScheduledTask|Remove-Item|Stop-Service|Set-Service'}
 It 'provides structured logging idempotence persistence and drift refusal'{$text|Should -Match 'ConvertTo-Json -Compress';$text|Should -Match 'idempotent';$text|Should -Match 'VerifyReboot';$text|Should -Match 'Task-definition drift';$text|Should -Match 'Rollback refused'}
 It 'binds state to experiment machine and user'{$text|Should -Match 'schemaVersion';$text|Should -Match 'COMPUTERNAME';$text|Should -Match 'userSid';$text|Should -Match 'State identity validation failed'}
}

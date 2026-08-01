$provider=Join-Path $PSScriptRoot '..\providers\Microsoft365SigninTask.ps1'
Describe 'EXP-113 Microsoft365SigninTask provider contract' {
 BeforeAll{$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as valid PowerShell'{[scriptblock]::Create($text)|Should -Not -BeNullOrEmpty}
 It 'declares Experimental scope only'{ $text|Should -Match 'EXP-113';$text|Should -Match 'Microsoft365SigninTask';$text|Should -Not -Match 'status:stable|stage:stable|Stable=' }
 It 'implements the complete reversible lifecycle'{foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"}}
 It 'requires HP Windows 11 elevation and management refusal'{foreach($t in 'Windows 11','Hewlett-Packard','Test-Elevated','DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','Enterprise-management ownership detected'){$text|Should -Match [regex]::Escape($t)}}
 It 'limits eligibility to Microsoft signed Office user applications and excludes servicing'{foreach($t in 'OUTLOOK','WINWORD','EXCEL','POWERPNT','ONENOTE','MSACCESS','Microsoft Corporation','ClickToRunSvc','click.?to.?run','activation','licens','repair','update'){$text|Should -Match $t}}
 It 'captures exact task executable and product evidence'{foreach($t in 'XmlSha256','DefinitionSha256','TriggersXml','SettingsXml','RegistrationInfoXml','TaskName','TaskPath','Author','Principal','Arguments','WorkingDirectory','Sha256','FileVersion','ProductName','CompanyName','Publisher','Thumbprint','LastRunTime','LastTaskResult','NextRunTime','capturedBootTime'){$text|Should -Match $t}}
 It 'normalizes only enabled state for drift checks and retains raw XML for rollback'{ $text|Should -Match '<Enabled>__EXPERIMENT_STATE__</Enabled>';$text|Should -Match 'Task-definition drift detected';$text|Should -Match 'Rollback exact-XML verification failed' }
 It 'supports dry run WhatIf ShouldProcess structured logs and idempotence'{foreach($t in 'SupportsShouldProcess','WhatIfPreference','ShouldProcess','WouldChange','ConvertTo-Json -Compress',"'idempotent'"){$text|Should -Match $t}}
 It 'limits mutation to task enabled state'{ $text|Should -Match 'Disable-ScheduledTask';$text|Should -Match 'Enable-ScheduledTask';$text|Should -Not -Match 'Unregister-ScheduledTask|Register-ScheduledTask|Remove-AppxPackage|Uninstall-Package|pnputil|Set-Service|Stop-Service|Remove-Service' }
 It 'preserves Microsoft 365 servicing and customer data scope'{foreach($t in 'PreserveMicrosoft365','PreserveClickToRun','PreserveActivation','PreserveUpdates','PreserveDocuments','PreserveAddins'){$text|Should -Match $t}}
 It 'requires observed reboot persistence and exact drift-aware rollback'{foreach($t in 'A later boot is required','Microsoft 365 executable or product identity drift detected','Protected-scope drift detected','Exact rollback verification failed','restoredExactOriginal'){$text|Should -Match [regex]::Escape($t)}}
 It 'preserves protected Windows remote access and management scope'{foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','omnissa','windows app','remote desktop','bitlocker','credential','recovery','intune','sccm','mdm'){$text|Should -Match $t}}
 It 'retains terminating failure evidence'{ $text|Should -Match "'failure' 'fail'";$text|Should -Match '\$ErrorActionPreference=''Stop''';$text|Should -Match 'throw' }
}

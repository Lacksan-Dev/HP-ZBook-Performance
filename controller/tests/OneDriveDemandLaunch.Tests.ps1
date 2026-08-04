BeforeAll {
 $providerPath=Join-Path $PSScriptRoot '..\providers\OneDriveDemandLaunch.ps1'
 $source=Get-Content -LiteralPath $providerPath -Raw
 $tokens=$null;$parseErrors=$null
 [Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$parseErrors)|Out-Null
}
Describe 'EXP-092 OneDriveDemandLaunch provider contract' {
 It 'parses without PowerShell syntax errors' { $parseErrors | Should -BeNullOrEmpty }
 It 'retains Experimental identity and evidence state' { $source|Should -Match 'EXP-092';$source|Should -Match 'needs-evidence';$source|Should -Not -Match 'status:stable|stage:stable|Stable=' }
 It 'exposes the full reversible lifecycle' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $source|Should -Match "'$a'" } }
 It 'uses ShouldProcess and WhatIf' { foreach($t in 'SupportsShouldProcess','ShouldProcess','WhatIfPreference'){ $source|Should -Match $t } }
 It 'requires HP Windows 11 and refuses management or OneDrive policy ownership' { foreach($t in 'Windows 11','Hewlett-Packard','DomainJoined','MdmEnrollments','OmadmAccounts','PolicyManager','ConfigMgr','RunPolicy','OneDrive policy ownership detected','Known Folder Move policy detected'){ $source|Should -Match ([regex]::Escape($t)) } }
 It 'accepts only one Microsoft-signed OneDrive background Run registration' { foreach($t in 'HKCU:','OneDrive.exe','/background','Microsoft Corporation','Exactly one eligible OneDrive Run registration'){ $source|Should -Match ([regex]::Escape($t)) } }
 It 'captures exact registry ACL and executable identity' { foreach($t in 'DoNotExpandEnvironmentNames','GetValueKind','Get-Acl','KeyOwner','KeySddl','Get-AuthenticodeSignature','Get-FileHash','Thumbprint','FileVersion','ProductName','CompanyName'){ $source|Should -Match $t } }
 It 'captures bounded account Files On-Demand and sync-root state without sensitive identifiers' { foreach($t in 'AccountCount','AccountKeyHash','SyncRootHash','FilesOnDemandEnabled','SensitiveIdentifiersCaptured=$false'){ $source|Should -Match ([regex]::Escape($t)) };$source|Should -Not -Match 'UserEmail|TenantId|DisplayName|UserName=' }
 It 'holds protected Windows remote access and OneDrive task state against drift' { foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','Get-ScheduledTask','OneDriveTasks','Protected security update remote-access or OneDrive task state drift detected'){ $source|Should -Match ([regex]::Escape($t)) } }
 It 'refuses Run-key ACL drift and key recreation' { foreach($t in 'Assert-RunKey','Run-key drift detected','Run-key ACL drift detected'){ $source|Should -Match ([regex]::Escape($t)) };$source|Should -Not -Match "New-Item -Path \$State\.entry\.Path" }
 It 'uses an experiment-owned marker to distinguish idempotence from outside deletion' { foreach($t in 'Write-AppliedMarker','Test-AppliedMarker','disappeared outside this experiment','Applied marker is missing','experiment applied marker is missing'){ $source|Should -Match ([regex]::Escape($t)) } }
 It 'uses structured schema-v3 logging and terminating failure retention' { foreach($t in 'schemaVersion=3','ConvertTo-Json -Compress',"'failure' 'fail'",'evidenceStatus'){ $source|Should -Match $t } }
 It 'requires a later boot for persistence' { foreach($t in 'capturedBootTime','A later boot is required','Reboot persistence failed'){ $source|Should -Match ([regex]::Escape($t)) } }
 It 'limits production mutation to one Run value and exact restore' { $source|Should -Match 'Remove-ItemProperty';$source|Should -Match '\.SetValue\('; $source|Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Stop-Process|Set-Service|Stop-Service|Remove-Service|Disable-PnpDevice|Remove-PnpDevice|pnputil|Disable-ScheduledTask|Unregister-ScheduledTask|Set-MpPreference|Disable-WindowsOptionalFeature' }
 It 'performs collision-safe exact rollback' { foreach($t in 'Rollback overwrite refused','Enum]::Parse','Exact rollback verification failed','restoredExactOriginal'){ $source|Should -Match ([regex]::Escape($t)) } }
}

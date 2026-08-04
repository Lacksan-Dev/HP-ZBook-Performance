BeforeAll {
 $providerPath = Join-Path $PSScriptRoot '..\providers\ClassicTeamsDemandLaunch.ps1'
 $source = Get-Content -LiteralPath $providerPath -Raw
 $tokens=$null;$parseErrors=$null
 [System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$parseErrors)|Out-Null
}
Describe 'EXP-049 ClassicTeamsDemandLaunch provider contract' {
 It 'parses without PowerShell syntax errors' { $parseErrors | Should -BeNullOrEmpty }
 It 'retains Experimental identity and evidence state' { $source | Should -Match 'EXP-049'; $source | Should -Match 'needs-evidence'; $source | Should -Not -Match 'status:stable|stage:stable|Stable=' }
 It 'exposes the full reversible lifecycle' { foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $source | Should -Match "'$a'" } }
 It 'requires HP Windows 11 elevation and self-managed ownership' { foreach($t in 'Windows 11','Hewlett-Packard','Test-Elevated','Elevated','Managed','ManagementSignals','Elevation required','Enterprise-management ownership detected','Management ownership appeared'){ $source | Should -Match ([regex]::Escape($t)) } }
 It 'uses ShouldProcess and supports WhatIf' { $source | Should -Match 'SupportsShouldProcess'; $source | Should -Match 'ShouldProcess'; $source | Should -Match 'WhatIfPreference' }
 It 'uses the exact current-user classic Teams Squirrel boundary' { foreach($t in 'HKCU:','com.squirrel.Teams.Teams','--processStart','Teams.exe','--process-start-args','--system-initiated'){ $source | Should -Match $t }; $source | Should -Match ([regex]::Escape('\\Microsoft\\Teams\\Update')); $source | Should -Match 'ms-teams\\.exe' }
 It 'captures exact registry ACL and signed binary identity' { foreach($t in 'DoNotExpandEnvironmentNames','GetValueKind','Get-Acl','KeyOwner','KeySddl','Get-AuthenticodeSignature','Get-FileHash','Thumbprint','FileVersion','ProductName','CompanyName','Microsoft Corporation'){ $source | Should -Match $t } }
 It 'captures bounded management ownership' { foreach($t in 'DomainJoined','MdmEnrollments','OmadmAccounts','PolicyManager','ConfigMgr','RunPolicy'){ $source | Should -Match $t }; $source | Should -Match 'Exactly one eligible classic Teams' }
 It 'holds protected Windows remote access and new Teams state against drift' { foreach($t in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','MSTeams','Assert-Protected'){ $source | Should -Match $t } }
 It 'refuses Run-key ACL drift and unsafe key recreation' { foreach($t in 'Assert-RunKey','Run-key drift detected','Run-key ACL drift detected','PreserveRunKeyAcl'){ $source | Should -Match ([regex]::Escape($t)) }; $source | Should -Not -Match "New-Item -Path \$s\.entry\.Path" }
 It 'supports structured logging idempotence failure retention and evidence state' { foreach($t in 'schemaVersion=3','ConvertTo-Json -Compress','idempotent','failure','needs-evidence'){ $source | Should -Match $t } }
 It 'requires a later boot for persistence' { $source | Should -Match 'capturedBootTime'; $source | Should -Match 'A later boot is required'; $source | Should -Match 'Reboot persistence failed' }
 It 'limits production mutation to one Run value' { $source | Should -Match 'Remove-ItemProperty'; $source | Should -Match '\.SetValue\('; $source | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Set-Service|Stop-Service|Remove-Service|Disable-PnpDevice|Remove-PnpDevice|pnputil|Disable-ScheduledTask|Unregister-ScheduledTask|Set-MpPreference|Disable-WindowsOptionalFeature' }
 It 'performs collision-safe exact rollback' { $source | Should -Match 'Rollback overwrite refused'; $source | Should -Match 'Enum]::Parse'; $source | Should -Match 'Exact rollback verification failed'; $source | Should -Match 'restoredExactOriginal' }
}

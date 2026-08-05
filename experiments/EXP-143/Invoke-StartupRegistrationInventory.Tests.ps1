$sut=Join-Path $PSScriptRoot 'Invoke-StartupRegistrationInventory.ps1'
Describe 'EXP-143 startup inventory classification contract' {
 BeforeAll {$text=Get-Content -LiteralPath $sut -Raw}
 It 'keeps inventory read only' {$text|Should -Not -Match 'Remove-ItemProperty|Remove-Item\s|Disable-ScheduledTask|Unregister-ScheduledTask|Remove-AppxPackage|Set-Service|Stop-Service|Disable-PnpDevice|pnputil'}
 It 'classifies with original registration metadata' {$text|Should -Match '\$State \| ConvertTo-Json -Compress';$text|Should -Match '\$Identity \$Command \$stateText'}
 It 'keeps protected identities ahead of priority identities' {$text.IndexOf("return @{ Class='protected'")|Should -BeLessThan $text.IndexOf("return @{ Class='priority-target'")}
 It 'recognizes protected remote access security accessibility driver update and management identities' {foreach($x in 'omnissa','horizon','windows app','remote desktop','mstsc','msrdc','tailscale','defender','credential','recovery','windows update','driver','hid','bluetooth','accessib','firmware','mdm','intune','configmgr'){$text|Should -Match $x}}
 It 'recognizes Teams Office Microsoft 365 Logitech telemetry and updater priority identities' {foreach($x in 'teams','msteams','office','microsoft 365','microsoft365','logi','logitech','lghub','telemetry','updat'){$text|Should -Match $x}}
 It 'retains all four EXP-002 startup surfaces' {foreach($x in "'StartupFolder'","'Registry'","'StartupTask'","'ScheduledTask'"){$text|Should -Match ([regex]::Escape($x))}}
 It 'captures byte-exact Startup-folder restore evidence' {foreach($x in 'ReadAllBytes','contentBase64','ToBase64String','sha256','creationTimeUtc','lastWriteTimeUtc','attributes'){$text|Should -Match $x}}
 It 'captures Startup-folder owner ACL and shortcut working directory evidence' {foreach($x in 'Get-Acl','Owner','GetSecurityDescriptorSddlForm','workingDirectory','WorkingDirectory','aclEvidenceStatus'){$text|Should -Match $x}}
 It 'marks unreadable ACL evidence for physical follow-up' {$text|Should -Match "aclEvidenceStatus = 'needs-evidence'"}
 It 'retains packaged metadata that can drive classification' {foreach($x in 'packageName','packageFamilyName','packageFullName','publisher','displayName','executable','entryPoint'){$text|Should -Match $x}}
 It 'keeps runtime StartupTask state and physical evidence unresolved' {$text|Should -Match "runtimeState='needs-evidence'";$text|Should -Match "evidenceStatus='needs-evidence'"}
 It 'uses a versioned deterministic evidence bundle' {$text|Should -Match "schemaVersion=6";$text|Should -Match 'snapshotSha256'}
}

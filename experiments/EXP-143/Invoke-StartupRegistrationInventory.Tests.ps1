Describe 'EXP-143 startup inventory classification contract' {
 BeforeAll {
  $script:sut=Join-Path $PSScriptRoot 'Invoke-StartupRegistrationInventory.ps1'
  $script:text=Get-Content -LiteralPath $script:sut -Raw
 }
 It 'keeps inventory read only' {$script:text|Should -Not -Match 'Remove-ItemProperty|Remove-Item\s|Disable-ScheduledTask|Unregister-ScheduledTask|Remove-AppxPackage|Set-Service|Stop-Service|Disable-PnpDevice|pnputil|Set-Acl'}
 It 'classifies with original registration metadata' {$script:text|Should -Match '\$State \| ConvertTo-Json -Compress';$script:text|Should -Match '\$Identity \$Command \$stateText'}
 It 'keeps protected identities ahead of priority identities' {$script:text.IndexOf("return @{ Class='protected'")|Should -BeLessThan $script:text.IndexOf("return @{ Class='priority-target'")}
 It 'recognizes protected remote access security accessibility driver update and management identities' {foreach($x in 'omnissa','horizon','windows app','remote desktop','mstsc','msrdc','tailscale','defender','credential','recovery','windows update','driver','hid','bluetooth','accessib','firmware','mdm','intune','configmgr'){$script:text|Should -Match $x}}
 It 'recognizes Teams Office Microsoft 365 Logitech telemetry and updater priority identities' {foreach($x in 'teams','msteams','office','microsoft 365','microsoft365','logi','logitech','lghub','telemetry','updat'){$script:text|Should -Match $x}}
 It 'retains all four EXP-002 startup surfaces' {foreach($x in "'StartupFolder'","'Registry'","'StartupTask'","'ScheduledTask'"){$script:text|Should -Match ([regex]::Escape($x))}}
 It 'captures byte-exact Startup-folder restore evidence' {foreach($x in 'ReadAllBytes','contentBase64','ToBase64String','sha256','creationTimeUtc','lastWriteTimeUtc','attributes'){$script:text|Should -Match $x}}
 It 'captures shortcut working-directory evidence' {$script:text|Should -Match '\$shortcut\.WorkingDirectory';$script:text|Should -Match 'workingDirectory=\$workingDirectory'}
 It 'captures Startup-folder owner and SDDL through read-only ACL APIs' {$script:text|Should -Match 'Get-Acl -LiteralPath';$script:text|Should -Match '\$acl\.Owner';$script:text|Should -Match 'GetSecurityDescriptorSddlForm';$script:text|Should -Match 'owner=\$owner';$script:text|Should -Match 'sddl=\$sddl'}
 It 'marks unreadable ACL evidence explicitly' {$script:text|Should -Match "\$aclEvidenceStatus = 'needs-evidence'";$script:text|Should -Match 'aclEvidenceErrorType'}
 It 'retains packaged metadata that can drive classification' {foreach($x in 'packageName','packageFamilyName','packageFullName','publisher','displayName','executable','entryPoint'){$script:text|Should -Match $x}}
 It 'keeps runtime StartupTask state and physical evidence unresolved' {$script:text|Should -Match "runtimeState='needs-evidence'";$script:text|Should -Match "evidenceStatus='needs-evidence'"}
 It 'uses schema version 6 deterministic evidence' {$script:text|Should -Match "schemaVersion=6";$script:text|Should -Match 'snapshotSha256'}
}

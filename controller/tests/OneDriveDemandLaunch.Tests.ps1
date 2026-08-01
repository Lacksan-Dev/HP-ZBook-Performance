$provider = Join-Path $PSScriptRoot '..\providers\OneDriveDemandLaunch.ps1'
Describe 'OneDriveDemandLaunch contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'parses as PowerShell' { [scriptblock]::Create($text) | Should -Not -BeNullOrEmpty }
    It 'exposes the full reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$action'" }
    }
    It 'uses ShouldProcess and supports WhatIf' { $text | Should -Match 'SupportsShouldProcess'; $text | Should -Match 'ShouldProcess'; $text | Should -Match 'WhatIfPreference' }
    It 'captures exact registry and executable identity' {
        foreach($token in 'RegistryValueOptions','GetValueKind','Get-AuthenticodeSignature','Get-FileHash','Thumbprint','KeySddl'){ $text | Should -Match $token }
    }
    It 'requires one Microsoft-signed OneDrive background registration' {
        foreach($token in 'OneDrive.exe','/background','Microsoft Corporation','Exactly one eligible OneDrive'){ $text | Should -Match [regex]::Escape($token) }
    }
    It 'captures account count, hashed sync-root identity, and Files On-Demand state without sensitive identifiers' {
        foreach($token in 'AccountCount','SyncRootHash','FilesOnDemandEnabled','SensitiveIdentifiersCaptured=$false'){ $text | Should -Match [regex]::Escape($token) }
        $text | Should -Not -Match 'UserEmail|UserName|TenantId|DisplayName'
    }
    It 'refuses enterprise and OneDrive policy ownership including Known Folder Move' {
        foreach($token in 'DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','KFMSilentOptIn','KFMOptInWithWizard','OneDrive policy ownership detected'){ $text | Should -Match $token }
    }
    It 'preserves installation, Files On-Demand, sync roots, shell integration, protected apps, and Windows controls' {
        foreach($token in 'PreserveInstallation','PreserveFilesOnDemand','PreserveSyncRoots','PreserveShellIntegration','omnissa','windows app','remote desktop','tailscale','defender','windows update','recovery'){ $text | Should -Match $token }
    }
    It 'limits application to one Run value' {
        $text | Should -Match 'Remove-ItemProperty'
        $text | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Stop-Process|Remove-Item\s+.*OneDrive|pnputil|sc\.exe\s+delete|Remove-Service|Disable-WindowsOptionalFeature'
    }
    It 'marks unsupported physical sync health as needs-evidence while retaining safe engineering' {
        $text | Should -Match "SyncHealth='needs-evidence'"
        $text | Should -Match 'SyncHealthEvidenceRequired'
    }
    It 'retains failed evidence in structured JSONL' { $text | Should -Match 'ConvertTo-Json -Compress'; $text | Should -Match "'failure' 'fail'" }
    It 'implements idempotence, reboot persistence, drift refusal, and exact rollback' {
        foreach($token in "'idempotent'",'A later boot is required','sync-root drift detected','Rollback overwrite refused','Exact rollback verification failed'){ $text | Should -Match [regex]::Escape($token) }
    }
}

$provider=Join-Path $PSScriptRoot '..\providers\EdgeMeasuredExtensionBlocklist.ps1'
Describe 'EXP-089 EdgeMeasuredExtensionBlocklist provider contract' {
    BeforeAll { $text=Get-Content -LiteralPath $provider -Raw }
    It 'parses as valid PowerShell' {
        $tokens=$null;$errors=$null
        [System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)|Out-Null
        $errors.Count | Should -Be 0
    }
    It 'remains Experimental and requires explicit extension selection' {
        $text | Should -Match "EXP-089"
        $text | Should -Match 'LACKSAN_EDGE_EXTENSION_ID'
        $text | Should -Match "\^\[a-p\]\{32\}\$"
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text | Should -Match "'$action'"}
    }
    It 'requires HP Windows 11 Edge 77 plus elevation and refuses management ownership' {
        $text | Should -Match 'Windows 11'
        $text | Should -Match 'Hewlett-Packard'
        $text | Should -Match 'Major -ge 77'
        $text | Should -Match 'Elevation is required'
        $text | Should -Match 'Enterprise-management signals are present'
    }
    It 'refuses force-installed managed and protected extension identities' {
        $text | Should -Match 'ExtensionInstallForcelist'
        $text | Should -Match 'ExtensionSettings'
        $text | Should -Match 'already blocklisted outside this experiment'
        $text | Should -Match 'ProtectedIdentity'
        $text | Should -Match 'user-installed from the Edge add-on store'
    }
    It 'captures extension manifest identity and exact blocklist destination' {
        foreach($needle in 'ManifestSha256','ProfileName','ProfilePath','ValueName','KeyExisted','capturedBootTime','userSid'){$text | Should -Match $needle}
    }
    It 'uses one string blocklist value as the only mutation' {
        $text | Should -Match 'New-ItemProperty -LiteralPath \$policyPath'
        $text | Should -Match '-PropertyType String'
        $text | Should -Match 'MutationCount=1'
        $text | Should -Match 'Remove-ItemProperty -LiteralPath \$policyPath'
    }
    It 'supports dry run WhatIf ShouldProcess structured logs and idempotence' {
        $text | Should -Match 'SupportsShouldProcess'
        $text | Should -Match '\$WhatIfPreference'
        $text | Should -Match 'WouldChange=\$true'
        $text | Should -Match 'Write-StructuredLog'
        $text | Should -Match "'idempotent'"
    }
    It 'requires observed reboot persistence' {
        $text | Should -Match 'A later boot is required for reboot-persistence verification'
        $text | Should -Match 'capturedBootTime'
    }
    It 'preserves failure evidence and refuses drift' {
        $text | Should -Match "'failure' 'fail'"
        $text | Should -Match 'State identity validation failed'
        $text | Should -Match 'manifest identity drift detected'
        $text | Should -Match 'Protected-scope drift detected'
        $text | Should -Match 'overwrite refused'
    }
    It 'implements exact rollback of only the experiment-created policy entry' {
        $text | Should -Match 'Rollback refused because the experiment-created policy value drifted'
        $text | Should -Match 'Remove experiment-created Edge extension blocklist value'
        $text | Should -Match 'restoredExactOriginal=\$true'
    }
    It 'contains no Stable assignment or broad extension deletion' {
        $text | Should -Not -Match 'status:stable|stage:stable'
        $text | Should -Not -Match 'Remove-Item.*Extensions'
        $text | Should -Not -Match 'Uninstall|Remove-AppxPackage'
    }
}

$provider = Join-Path $PSScriptRoot '..\providers\LogiBoltDemandLaunch.ps1'
Describe 'LogiBoltDemandLaunch contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'parses as PowerShell' { [scriptblock]::Create($text) | Should -Not -BeNullOrEmpty }
    It 'exposes the full reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$action'" }
    }
    It 'uses ShouldProcess and supports WhatIf' { $text | Should -Match 'SupportsShouldProcess'; $text | Should -Match 'ShouldProcess'; $text | Should -Match 'WhatIfPreference' }
    It 'captures exact registry and executable identity' {
        foreach($token in 'RegistryValueOptions','GetValueKind','Get-AuthenticodeSignature','Get-FileHash','Thumbprint','KeySddl'){ $text | Should -Match $token }
    }
    It 'matches only the bounded Logi Bolt identity' {
        foreach($token in 'LogiBolt','logi-bolt','Exactly one eligible Logi Bolt'){ $text | Should -Match $token }
        $text | Should -Match 'updat\|uninstall\|repair\|firmware'
    }
    It 'requires explicit background startup intent' {
        $text | Should -Match 'IsNullOrWhiteSpace\(\$args\)'
        foreach($token in 'background','minimi','startup','tray','silent'){ $text | Should -Match $token }
        $text | Should -Match 'Arguments=\$c\[0\]\.Arguments'
    }
    It 'refuses enterprise ownership and ambiguous candidates' {
        foreach($token in 'DomainJoined','MdmEnrollments','PolicyManager','ConfigMgr','Exactly one eligible'){ $text | Should -Match $token }
    }
    It 'preserves pairing, protected applications, and Windows controls' {
        foreach($token in 'PreservePairing','omnissa','windows app','remote desktop','tailscale','defender','windows update','recovery','TermService'){ $text | Should -Match $token }
    }
    It 'limits application to one Run value' {
        $text | Should -Match 'Remove-ItemProperty'
        $text | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|pnputil|sc\.exe\s+delete|Remove-Service|Disable-WindowsOptionalFeature'
    }
    It 'retains failed evidence in structured JSONL' { $text | Should -Match 'ConvertTo-Json -Compress'; $text | Should -Match "'failure' 'fail'"; $text | Should -Match 'needs-evidence' }
    It 'implements idempotent apply and exact rollback overwrite refusal' { $text | Should -Match "'idempotent'"; $text | Should -Match 'Rollback overwrite refused'; $text | Should -Match 'Enum]::Parse'; $text | Should -Match 'Exact rollback verification failed' }
}

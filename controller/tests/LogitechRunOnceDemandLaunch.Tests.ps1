$provider = Join-Path $PSScriptRoot '..\providers\LogitechRunOnceDemandLaunch.ps1'
Describe 'LogitechRunOnceDemandLaunch contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'parses as PowerShell' { [scriptblock]::Create($text) | Should -Not -BeNullOrEmpty }
    It 'implements the complete lifecycle' {
        foreach($token in "'Check'","'Capture'","'DryRun'","'Apply'","'Verify'","'VerifyReboot'","'Rollback'"){ $text | Should -Match [regex]::Escape($token) }
    }
    It 'uses ShouldProcess and WhatIf' {
        $text | Should -Match 'SupportsShouldProcess=\$true'
        $text | Should -Match '\$PSCmdlet\.ShouldProcess'
        $text | Should -Match '\$WhatIfPreference'
    }
    It 'limits discovery to approved RunOnce locations and refuses special semantics' {
        $text | Should -Match 'CurrentVersion\\RunOnce'
        $text | Should -Match "StartsWith\('!'\)"
        $text | Should -Match "StartsWith\('\*'\)"
    }
    It 'requires signed Logitech identity and excludes protected purposes' {
        $text | Should -Match 'ValidLogitechPublisher'
        foreach($token in 'omnissa','remote desktop','tailscale','firmware','dfu','driver','pair','receiver','repair'){ $text | Should -Match $token }
    }
    It 'captures exact registry and executable identity for rollback' {
        foreach($token in 'DoNotExpandEnvironmentNames','GetValueKind','Sha256','Thumbprint','FileVersion','KeySddl','Product'){ $text | Should -Match $token }
    }
    It 'enforces idempotence, reboot evidence, drift refusal, and exact rollback' {
        foreach($token in "'idempotent'",'A later boot is required','executable identity drift detected','product identity drift detected','Rollback overwrite refused','Exact rollback verification failed'){ $text | Should -Match [regex]::Escape($token) }
    }
    It 'retains missing physical evidence explicitly' {
        $text | Should -Match 'needs-evidence'
        $text | Should -Match 'oneShotAttribution'
    }
}

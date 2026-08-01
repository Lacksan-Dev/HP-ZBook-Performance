$provider = Join-Path $PSScriptRoot '..\providers\HPAppHelperDemandStart.ps1'
Describe 'HPAppHelperDemandStart provider contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'exists and declares the Experimental profile' {
        Test-Path -LiteralPath $provider | Should -BeTrue
        $text | Should -Match 'EXP-063'
        $text | Should -Match 'HPAppHelperDemandStart'
        $text | Should -Not -Match 'Stable'
        $text | Should -Not -Match 'blocked'
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') { $text | Should -Match "'$action'" }
        foreach($token in 'SupportsShouldProcess','WhatIfPreference','State overwrite refused','ConvertTo-Json -Compress','idempotent','failure','later boot','Exact rollback verification failed') { $text | Should -Match $token }
    }
    It 'limits mutation to one exact HP App Helper service startup configuration' {
        $text | Should -Match 'HPAppHelperCap'
        $text | Should -Match 'HP App Helper HSA Service'
        $text | Should -Match 'AppHelperCap'
        $text | Should -Match 'Set-Service -Name \$serviceName -StartupType Manual'
        $text | Should -Match 'PreserveRunningState'
        $text | Should -Not -Match 'Remove-Service|sc\.exe\s+delete|pnputil|Remove-PnpDevice|dism\.exe|Disable-WindowsOptionalFeature'
    }
    It 'captures identity, configuration, dependencies, state, and rollback evidence' {
        foreach($token in 'StartMode','DelayedAutoStart','State','PathName','ServiceAccount','Dependencies','Dependents','Sha256','FileVersion','SignatureStatus','Publisher','Thumbprint','capturedBootTime','protectedScopeHash') { $text | Should -Match $token }
    }
    It 'refuses unsafe, managed, ambiguous, unsigned, and dependency-sensitive states' {
        foreach($token in 'Enterprise-management ownership detected','Exactly one HPAppHelperCap identity is required','Valid HP publisher signature is required','dependencies or dependents detected','identity drift detected','Protected-scope drift detected') { $text | Should -Match [regex]::Escape($token) }
    }
    It 'preserves protected Windows and remote-access scope' {
        foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','omnissa','windows app','remote desktop','bitlocker','credential','recovery','intune','sccm','mdm') { $text | Should -Match $token }
    }
    It 'preserves failed and inconclusive evidence through terminating logs' {
        $text | Should -Match "Write-Log 'failure' 'fail'"
        $text | Should -Match '\$ErrorActionPreference=''Stop'''
        $text | Should -Match 'throw'
    }
}

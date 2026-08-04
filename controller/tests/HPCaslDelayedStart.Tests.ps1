$provider = Join-Path $PSScriptRoot '..\providers\HPCaslDelayedStart.ps1'
Describe 'HPCaslDelayedStart provider contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'exists and declares the Experimental profile' {
        Test-Path -LiteralPath $provider | Should -BeTrue
        $text | Should -Match 'EXP-095'
        $text | Should -Match 'HPCaslDelayedStart'
        $text | Should -Not -Match 'Stable'
        $text | Should -Not -Match 'blocked'
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') { $text | Should -Match "'$action'" }
        foreach($token in 'SupportsShouldProcess','WhatIfPreference','State overwrite refused','ConvertTo-Json -Compress','idempotent','failure','later boot','Exact rollback verification failed') { $text | Should -Match $token }
    }
    It 'limits mutation to one exact CASL service delayed-start configuration' {
        $text | Should -Match 'hpqcaslwmiex'
        $text | Should -Match 'HP CASL Framework Service'
        $text | Should -Match 'hpqcaslwmiex\.exe'
        $text | Should -Match 'Set-Service -Name \$serviceName -StartupType Automatic'
        $text | Should -Match 'DelayedAutoStart'
        $text | Should -Match 'PreserveRunningState'
        $text | Should -Not -Match 'Remove-Service|sc\.exe\s+delete|pnputil|Remove-PnpDevice|dism\.exe|Disable-WindowsOptionalFeature|winmgmt\s+/resetrepository|winmgmt\s+/salvagerepository'
    }
    It 'captures identity, package, dependencies, recovery, triggers, state, and rollback evidence' {
        foreach($token in 'StartMode','DelayedAutoStart','State','PathName','ServiceAccount','Dependencies','Dependents','RecoveryActions','Triggers','Packages','Sha256','FileVersion','SignatureStatus','Publisher','Thumbprint','capturedBootTime','protectedScopeHash','protectedRuntime','dependencyHash','BIOS') { $text | Should -Match $token }
    }
    It 'hashes protected configuration separately from reboot-varying runtime observations' {
        $text | Should -Match 'Configuration=\$configuration'
        $text | Should -Match 'Runtime=\$runtime'
        $text | Should -Match 'Hash=Get-Hash \$configuration'
        $text | Should -Match 'protectedRuntime'
        $text | Should -Not -Match 'Select-Object ProcessName,Id'
        $text | Should -Match 'Protected-scope configuration drift detected after reboot'
    }
    It 'refuses unsafe, managed, ambiguous, unsigned, trigger-sensitive, recovery-sensitive, and package-ambiguous states' {
        foreach($token in 'Enterprise-management ownership detected','Exactly one hpqcaslwmiex identity is required','Valid HP publisher signature is required','Trigger-sensitive service state detected','Recovery-sensitive service state detected','Exactly one associated HP CASL package identity is required','Dependency drift detected','Package identity drift detected','Protected-scope configuration drift detected') { $text | Should -Match [regex]::Escape($token) }
    }
    It 'preserves protected Windows and remote-access scope' {
        foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','omnissa','windows app','remote desktop','bitlocker','credential','recovery','intune','sccm','mdm','vpn','ndis') { $text | Should -Match $token }
    }
    It 'preserves failed and inconclusive evidence through terminating logs' {
        $text | Should -Match "Write-Log 'failure' 'fail'"
        $text | Should -Match '\$ErrorActionPreference=''Stop'''
        $text | Should -Match 'throw'
    }
}
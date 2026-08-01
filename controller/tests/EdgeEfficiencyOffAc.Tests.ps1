$provider = Join-Path $PSScriptRoot '..\providers\EdgeEfficiencyOffAc.ps1'
Describe 'EdgeEfficiencyOffAc provider contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'exists and stays Experimental' {
        Test-Path -LiteralPath $provider | Should -BeTrue
        $text | Should -Match 'EXP-097'
        $text | Should -Match 'EdgeEfficiencyOffAc'
        $text | Should -Not -Match 'status:stable|Stable='
        $text | Should -Not -Match 'blocked'
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') { $text | Should -Match "'$action'" }
    }
    It 'targets only the recommended EfficiencyModeEnabled DWORD' {
        $text | Should -Match 'Edge\\Recommended'
        $text | Should -Match 'EfficiencyModeEnabled'
        $text | Should -Match "Value=0"
        $text | Should -Match "MutationCount=1"
        $text | Should -Not -Match 'Set-Service|Stop-Service|Disable-ScheduledTask|Remove-AppxPackage|powercfg.exe /setactive|DiskCacheSize'
    }
    It 'requires HP Windows 11 elevation Edge 106 Microsoft signature and AC power' {
        foreach($token in 'Windows 11','Hewlett-Packard','Test-Elevated','Major-ge106','ValidPublisher','Microsoft Corporation','OnAc','AC power is required') { $text | Should -Match $token }
    }
    It 'captures main and related Edge efficiency policy state' {
        foreach($token in 'MandatoryMain','RecommendedMain','EfficiencyModeOnPowerEnabled','MandatoryRelated','RecommendedRelated','Related Edge policy drift detected') { $text | Should -Match $token }
    }
    It 'captures exact evidence and binds state to machine user boot executable and power state' {
        foreach($token in 'schemaVersion','capturedBootTime','machine','userSid','Sha256','Thumbprint','power','EnergySaverObservation','management','protectedScope','State overwrite refused') { $text | Should -Match $token }
    }
    It 'provides dry run WhatIf structured logging idempotence and terminating failure evidence' {
        foreach($token in 'DryRun','WhatIfPreference','Write-Log','ConvertTo-Json -Compress','idempotent','catch','failure') { $text | Should -Match $token }
    }
    It 'requires browser restart reboot persistence and exact drift-safe rollback' {
        foreach($token in 'BrowserRestartRequired','A later boot is required','Reboot persistence failed','Policy drift detected','restoredExactOriginal','Exact rollback verification failed') { $text | Should -Match $token }
    }
    It 'preserves security updates management drivers and protected remote access by bounded mutation' {
        foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','omnissa','horizon','msrdc','mstsc','tailscale','Protected-scope drift detected') { $text | Should -Match $token }
    }
}

$provider = Join-Path $PSScriptRoot '..\providers\EdgeDisableBackgroundMode.ps1'

Describe 'EdgeDisableBackgroundMode provider contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }

    It 'stays Experimental and avoids release promotion' {
        Test-Path $provider | Should -BeTrue
        $text | Should -Match 'EXP-130'
        $text | Should -Match 'EdgeDisableBackgroundMode'
        $text | Should -Match 'needs-evidence'
        $text | Should -Not -Match 'status:stable|Stable='
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){ $text | Should -Match "'$action'" }
    }
    It 'targets only the recommended BackgroundModeEnabled DWORD zero' {
        foreach($token in 'BackgroundModeEnabled','Recommended','DWord','Value=0','MutationCount=1'){ $text | Should -Match $token }
        $text | Should -Not -Match 'Set-Service|Stop-Service|Disable-ScheduledTask|Remove-AppxPackage|Remove-Item .*User Data|Remove-Item .*Profile'
    }
    It 'requires supported HP Windows 11 elevation Microsoft Edge and controlled background-app evidence' {
        foreach($token in 'Windows 11','Hewlett-Packard','Test-Elevated','Microsoft Corporation','Major -ge 77','controlledProfile','backgroundAppPresent','baselineBackgroundModeEnabled','ProfileFixturePath'){ $text | Should -Match ([regex]::Escape($token)) }
    }
    It 'refuses external management and existing policy ownership while holding adjacent Edge settings' {
        foreach($token in 'Get-Management','Mandatory','Recommended','StartupBoostEnabled','EfficiencyModeEnabled','SleepingTabsEnabled','NewTabPagePrerenderEnabled','HardwareAccelerationModeEnabled','NetworkPredictionOptions','Get-StartupFolders'){ $text | Should -Match $token }
    }
    It 'captures executable identity boot identity protected state and fixture identity' {
        foreach($token in 'Sha256','Thumbprint','capturedBootTime','userSid','MarkerSha256','Get-Protected','TermService','Tailscale','edgeupdate','edgeupdatem'){ $text | Should -Match $token }
    }
    It 'has dry run WhatIf structured logging idempotence and terminating failure evidence' {
        foreach($token in 'DryRun','WhatIfPreference','Write-Log','ConvertTo-Json -Compress','idempotent','catch','failure'){ $text | Should -Match $token }
    }
    It 'requires a later boot for persistence verification and uses drift-safe exact rollback' {
        foreach($token in 'A later boot is required','Reboot persistence failed','rollback overwrite refused','Exact rollback verification failed','RestoredExactOriginal'){ $text | Should -Match $token }
    }
    It 'preserves security update servicing and remote-access state' {
        foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService','WindowsApp|RemoteDesktop','Protected security, update, servicing, or remote-access state drift detected'){ $text | Should -Match $token }
    }
}

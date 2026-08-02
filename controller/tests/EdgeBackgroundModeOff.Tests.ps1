$provider = Join-Path $PSScriptRoot '..\providers\EdgeBackgroundModeOff.ps1'
Describe 'EdgeBackgroundModeOff provider contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'exists and stays Experimental' {
        Test-Path -LiteralPath $provider | Should -BeTrue
        $text | Should -Match 'EXP-071'
        $text | Should -Match 'EdgeBackgroundModeOff'
        $text | Should -Not -Match 'status:stable|Stable='
        $text | Should -Not -Match 'blocked'
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') { $text | Should -Match "'$action'" }
    }
    It 'targets only the recommended BackgroundModeEnabled DWORD' {
        $text | Should -Match 'Edge\\Recommended'
        $text | Should -Match 'BackgroundModeEnabled'
        $text | Should -Match 'Value=0'
        $text | Should -Match 'MutationCount=1'
        $text | Should -Not -Match 'Set-Service|Stop-Service|Disable-ScheduledTask|Remove-AppxPackage|Remove-Item .*Profile|DiskCacheSize|HardwareAccelerationModeEnabled|SleepingTabs'
    }
    It 'requires HP Windows 11 elevation Edge 77 and Microsoft signature' {
        foreach($token in 'Windows 11','Hewlett-Packard','Test-Elevated','Major','-ge 77','ValidPublisher','Microsoft Corporation') { $text | Should -Match ([regex]::Escape($token)) }
    }
    It 'captures and preserves Startup Boost separately' {
        foreach($token in 'StartupBoostEnabled','MandatoryRelated','RecommendedRelated','Related Edge policy drift detected') { $text | Should -Match $token }
    }
    It 'keeps Edge out of Startup folders' {
        foreach($token in 'Get-StartupFolderState','CommonStartup','CreateShortcut','EdgeEntryCount','Edge Startup-folder drift detected') { $text | Should -Match $token }
    }
    It 'distinguishes active correlated MDM from generic PolicyManager or historical enrollment containers' {
        foreach($token in 'ActiveCorrelatedMdmGuidCount','EnrollmentGuidCount','OmadmAccountGuidCount','EnterpriseMgmtGuidCount','PolicyManagerPresent','ConfigMgr') { $text | Should -Match $token }
        $text | Should -Match 'Managed=\(\$signals.DomainJoined -or \$signals.ConfigMgr -or \$signals.ActiveCorrelatedMdmGuidCount -gt 0\)'
    }
    It 'captures exact state bound to machine user boot and Edge executable identity' {
        foreach($token in 'schemaVersion','capturedBootTime','machine','userSid','Sha256','Thumbprint','management','startupFolderEdgeEntries','protectedScope','State overwrite refused') { $text | Should -Match $token }
    }
    It 'provides dry run WhatIf logging idempotence and failure evidence' {
        foreach($token in 'DryRun','WhatIfPreference','Write-Log','ConvertTo-Json -Compress','idempotent','catch','failure') { $text | Should -Match $token }
    }
    It 'requires reboot persistence and exact drift-safe rollback' {
        foreach($token in 'A later boot is required','Reboot persistence failed','Policy drift detected','restoredExactOriginal','Exact rollback verification failed') { $text | Should -Match $token }
    }
    It 'preserves security update Edge Update and Tailscale service configuration' {
        foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','edgeupdate','edgeupdatem','Protected service configuration drift detected') { $text | Should -Match $token }
    }
}

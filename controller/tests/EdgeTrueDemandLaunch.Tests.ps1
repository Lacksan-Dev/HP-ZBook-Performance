$provider = Join-Path $PSScriptRoot '..\providers\EdgeTrueDemandLaunch.ps1'
Describe 'EdgeTrueDemandLaunch contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'declares the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') { $text | Should -Match "'$action'" }
    }
    It 'targets only the recommended StartupBoostEnabled policy' {
        $text | Should -Match "Edge\\Recommended"
        $text | Should -Match "StartupBoostEnabled"
        $text | Should -Match "Value=0"
        $text | Should -Not -Match 'Startup folder|Remove-Item.*msedge|Stop-Service|Set-Service|Disable-ScheduledTask'
    }
    It 'requires HP Windows 11 elevation Edge 88 and unmanaged state' {
        $text | Should -Match 'Windows 11'
        $text | Should -Match 'Hewlett-Packard'
        $text | Should -Match 'Test-Elevated'
        $text | Should -Match 'Major-ge88'
        $text | Should -Match 'Management'
    }
    It 'refuses existing mandatory and recommended values' {
        $text | Should -Match 'Mandatory'
        $text | Should -Match 'Recommended'
        $text | Should -Match '!\$mandatory.ValueExists'
        $text | Should -Match '!\$recommended.ValueExists'
    }
    It 'captures exact state and binds evidence to machine user and boot' {
        foreach($token in 'schemaVersion','capturedBootTime','machine','userSid','original','edge','management','State overwrite refused') { $text | Should -Match $token }
    }
    It 'provides dry run WhatIf logging idempotence failure retention and exact rollback' {
        foreach($token in 'DryRun','WhatIfPreference','Write-Log','idempotent','catch','failure','Policy drift detected','restoredExactOriginal') { $text | Should -Match $token }
    }
    It 'requires reboot persistence and browser restart evidence' {
        $text | Should -Match 'BrowserRestartRequired'
        $text | Should -Match 'A later boot is required'
        $text | Should -Match 'Reboot persistence failed'
    }
    It 'never assigns Stable' { $text | Should -Not -Match 'status:stable|Stable=' }
}

$scriptPath = Join-Path $PSScriptRoot '..\experiments\EXP-019\Set-OfficeBackgroundTaskHandlerLogon.ps1'

Describe 'EXP-019 Office Background Task Handler Logon contract' {
    BeforeAll { $text = Get-Content $scriptPath -Raw }

    It 'uses ShouldProcess' {
        $text | Should -Match 'SupportsShouldProcess=\$true'
    }

    It 'targets only the exact Office task identity' {
        $text | Should -Match "TaskPath = '\\Microsoft\\Office\\'"
        $text | Should -Match "TaskName = 'Office Background Task Handler Logon'"
        $text | Should -Not -Match 'Office Automatic Updates'
    }

    It 'requires Office background task handler action identity' {
        $text | Should -Match 'OfficeBackgroundTaskHandler'
        $text | Should -Match 'Scheduled task action identity rejected'
    }

    It 'contains the complete reversible action set' {
        foreach ($action in @('Detect','Capture','Apply','Verify','VerifyReboot','Rollback','VerifyRollback')) {
            $text | Should -Match "'$action'"
        }
    }

    It 'captures exact XML and normalized identity hashes' {
        $text | Should -Match 'Export-ScheduledTask'
        $text | Should -Match 'xmlSha256'
        $text | Should -Match 'normalizedXmlSha256'
        $text | Should -Match '__CONTROLLED_ENABLED_STATE__'
    }

    It 'changes only task enabled state' {
        $text | Should -Match 'Disable-ScheduledTask'
        $text | Should -Match 'Enable-ScheduledTask'
        $text | Should -Not -Match 'Unregister-ScheduledTask'
        $text | Should -Not -Match 'Register-ScheduledTask'
        $text | Should -Not -Match 'Remove-Item'
    }

    It 'writes structured JSONL events' {
        $text | Should -Match 'ConvertTo-Json -Depth 8 -Compress'
        $text | Should -Match 'events.jsonl'
    }

    It 'refuses changed task definitions and invalid state files' {
        $text | Should -Match 'Current task definition diverged from captured state'
        $text | Should -Match 'State file identity rejected'
    }

    It 'detects HP Windows 11 support' {
        $text | Should -Match 'Win32_OperatingSystem'
        $text | Should -Match 'Win32_ComputerSystem'
        $text | Should -Match 'Build -ge 22000'
    }
}
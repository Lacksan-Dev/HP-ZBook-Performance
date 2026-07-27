$scriptPath = Join-Path $PSScriptRoot '..\experiments\EXP-018\Remove-OfficeSyncProcessStartup.ps1'

describe 'EXP-018 Office Sync Process startup calibration contract' {
    it 'uses ShouldProcess' {
        (Get-Content $scriptPath -Raw) | Should -Match 'SupportsShouldProcess=\$true'
    }

    it 'limits the registry surface to the current-user Run key' {
        $text = Get-Content $scriptPath -Raw
        $text | Should -Match 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run'
        $text | Should -Not -Match 'HKLM:'
    }

    it 'requires exact OfficeSyncProcess value identity' {
        (Get-Content $scriptPath -Raw) | Should -Match "\^OfficeSyncProcess\$"
    }

    it 'requires OfficeSyncProcess.exe command identity' {
        (Get-Content $scriptPath -Raw) | Should -Match 'OfficeSyncProcess\\\.exe'
    }

    it 'contains capture, apply, verify, reboot verification, rollback, and rollback verification actions' {
        $text = Get-Content $scriptPath -Raw
        foreach ($action in @('Capture','Apply','Verify','VerifyReboot','Rollback','VerifyRollback')) {
            $text | Should -Match "'$action'"
        }
    }

    it 'writes structured JSONL events' {
        $text = Get-Content $scriptPath -Raw
        $text | Should -Match 'ConvertTo-Json -Compress'
        $text | Should -Match 'events.jsonl'
    }

    it 'refuses divergent state before removal' {
        (Get-Content $scriptPath -Raw) | Should -Match 'Current value diverged from captured state'
    }

    it 'validates state-file identity before rollback' {
        (Get-Content $scriptPath -Raw) | Should -Match 'State file identity rejected'
    }
}

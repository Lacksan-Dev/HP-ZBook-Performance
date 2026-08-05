#requires -Version 5.1
BeforeAll {
    $ProviderPath = Join-Path $PSScriptRoot 'Invoke-Exp162ScheduledTaskRegistration.ps1'
    $TaskName = [string]$env:LACKSAN_EXP162_TASK_NAME
    $TaskPath = [string]$env:LACKSAN_EXP162_TASK_PATH
    $ExpectedHash = [string]$env:LACKSAN_EXP162_EXECUTABLE_SHA256
    $IsOptIn = $env:LACKSAN_EXP162_INTEGRATION -eq '1'
    $CanRun = $IsOptIn -and $PSVersionTable.Platform -eq 'Win32NT' -and -not [string]::IsNullOrWhiteSpace($TaskName) -and -not [string]::IsNullOrWhiteSpace($TaskPath) -and $ExpectedHash -match '^[A-Fa-f0-9]{64}$'
}

Describe 'EXP-162 zero-mutation integration' {
    It 'leaves the selected task XML unchanged through Check, DryRun, Capture, and Apply WhatIf' -Skip:(-not $CanRun) {
        $before = Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
        $root = Join-Path $env:TEMP ('Lacksan-EXP162-Integration-' + [guid]::NewGuid().ToString('N'))
        $state = Join-Path $root 'state.json'
        $log = Join-Path $root 'events.jsonl'
        try {
            & $ProviderPath -Action Check -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedHash -StatePath $state -LogPath $log -SelfManagedLab | Out-Null
            & $ProviderPath -Action DryRun -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedHash -StatePath $state -LogPath $log -SelfManagedLab | Out-Null
            & $ProviderPath -Action Capture -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedHash -StatePath $state -LogPath $log -SelfManagedLab | Out-Null
            & $ProviderPath -Action Apply -TaskName $TaskName -TaskPath $TaskPath -ExpectedExecutableSha256 $ExpectedHash -StatePath $state -LogPath $log -SelfManagedLab -WhatIf | Out-Null
            $after = Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
            $after | Should -BeExactly $before
        } finally {
            if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
        }
    }
}

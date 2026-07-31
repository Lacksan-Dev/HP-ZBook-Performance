BeforeAll {
    $script = Join-Path $PSScriptRoot '..\providers\HPSupportAssistantQuickStartTask.ps1'
    $enabled = $env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1' -and $IsWindows
}
Describe 'EXP-088 zero-mutation Windows integration' -Skip:(-not $enabled) {
    It 'keeps scheduled-task definitions and enabled states unchanged during Check, DryRun, and Apply WhatIf' {
        $before = @(Get-ScheduledTask | ForEach-Object {
            $xml = Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath
            [pscustomobject]@{ Identity = "$($_.TaskPath)$($_.TaskName)"; State = $_.State.ToString(); Xml = $xml }
        }) | ConvertTo-Json -Compress -Depth 8
        $state = Join-Path $TestDrive 'exp-088-state.json'
        $log = Join-Path $TestDrive 'exp-088.jsonl'
        & $script -Action Check -StatePath $state -LogPath $log | Out-Null
        try { & $script -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { $_.Exception.Message | Should -Match 'eligible|management|Elevation' }
        try { & $script -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { $_.Exception.Message | Should -Match 'eligible|management|Elevation' }
        $after = @(Get-ScheduledTask | ForEach-Object {
            $xml = Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath
            [pscustomobject]@{ Identity = "$($_.TaskPath)$($_.TaskName)"; State = $_.State.ToString(); Xml = $xml }
        }) | ConvertTo-Json -Compress -Depth 8
        $after | Should -BeExactly $before
    }
}

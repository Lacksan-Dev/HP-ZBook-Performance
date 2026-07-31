# Opt-in Windows integration contract. Execute only on an HP Windows 11 lab system
# with an eligible classic Teams Run value and a disposable state directory.
$runIntegration = $env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'

Describe 'ClassicTeamsDemandLaunch zero-mutation integration' -Skip:(-not $runIntegration) {
    BeforeAll {
        $provider = Join-Path $PSScriptRoot '..\providers\ClassicTeamsDemandLaunch.ps1'
        $stateRoot = Join-Path $env:TEMP ('Lacksan-EXP-049-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
        $state = Join-Path $stateRoot 'state.json'
        $log = Join-Path $stateRoot 'events.jsonl'
        $runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

        function Get-RunSnapshot {
            if (!(Test-Path -LiteralPath $runPath)) { return '<missing>' }
            $key = Get-Item -LiteralPath $runPath
            $values = foreach ($name in ($key.GetValueNames() | Sort-Object)) {
                [ordered]@{
                    Name = $name
                    Kind = $key.GetValueKind($name).ToString()
                    Data = [string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                }
            }
            @($values) | ConvertTo-Json -Compress -Depth 5
        }
    }

    AfterAll {
        Remove-Item -LiteralPath $stateRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'keeps the Run key unchanged during Check' {
        $before = Get-RunSnapshot
        & $provider -Action Check -LogPath $log | Out-Null
        Get-RunSnapshot | Should -BeExactly $before
    }

    It 'keeps the Run key unchanged during Capture' {
        $before = Get-RunSnapshot
        & $provider -Action Capture -StatePath $state -LogPath $log | Out-Null
        Get-RunSnapshot | Should -BeExactly $before
    }

    It 'keeps the Run key unchanged during DryRun' {
        $before = Get-RunSnapshot
        & $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null
        Get-RunSnapshot | Should -BeExactly $before
    }

    It 'keeps the Run key unchanged during Apply WhatIf' {
        $before = Get-RunSnapshot
        & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null
        Get-RunSnapshot | Should -BeExactly $before
    }

    It 'emits parseable structured log records without secret payloads' {
        $records = Get-Content -LiteralPath $log | ForEach-Object { $_ | ConvertFrom-Json }
        $records.Count | Should -BeGreaterThan 0
        $records[-1].schemaVersion | Should -Be 1
        (Get-Content -LiteralPath $log -Raw) | Should -Not -Match '(?i)password|access[_-]?token|refresh[_-]?token|credential|cookie|mailbox|meeting[_-]?url'
    }
}

$provider = Join-Path $PSScriptRoot '..\providers\LogitechDownloadAssistantRun.ps1'
$runPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)

function Get-RunSnapshot {
    $snapshot = foreach ($path in $runPaths) {
        if (!(Test-Path -LiteralPath $path)) {
            [ordered]@{ Path = $path; Exists = $false; Values = @() }
            continue
        }
        $key = Get-Item -LiteralPath $path
        $values = foreach ($name in ($key.GetValueNames() | Sort-Object)) {
            [ordered]@{
                Name = $name
                Kind = $key.GetValueKind($name).ToString()
                Data = [string]$key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
        }
        [ordered]@{ Path = $path; Exists = $true; Values = @($values) }
    }
    @($snapshot) | ConvertTo-Json -Compress -Depth 8
}

Describe 'EXP-080 zero-mutation Windows integration' -Tag 'Integration' {
    $eligible = $IsWindows -and $env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'

    It 'keeps all approved Run locations unchanged during Check DryRun and Apply WhatIf' -Skip:(!$eligible) {
        $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("EXP-080-{0}" -f [guid]::NewGuid())
        $statePath = Join-Path $temporaryRoot 'state.json'
        $logPath = Join-Path $temporaryRoot 'events.jsonl'
        New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
        try {
            $before = Get-RunSnapshot
            & $provider -Action Check -LogPath $logPath | Out-Null
            & $provider -Action Capture -StatePath $statePath -LogPath $logPath | Out-Null
            & $provider -Action DryRun -StatePath $statePath -LogPath $logPath | Out-Null
            $whatIfResult = & $provider -Action Apply -StatePath $statePath -LogPath $logPath -WhatIf
            $after = Get-RunSnapshot

            $after | Should -BeExactly $before
            $whatIfResult.WhatIf | Should -BeTrue
            $whatIfResult.MutationCount | Should -Be 0
            Test-Path -LiteralPath $statePath | Should -BeTrue
            Test-Path -LiteralPath $logPath | Should -BeTrue
        } finally {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

$provider = Join-Path $PSScriptRoot '..\providers\LogiTuneDemandLaunch.ps1'
Describe 'LogiTuneDemandLaunch integration' -Tag 'WindowsIntegration' {
    It 'keeps the Run key unchanged during Check Capture DryRun and Apply WhatIf' -Skip:(-not $env:LACKSAN_RUN_WINDOWS_INTEGRATION) {
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        function Get-RunSnapshot {
            if(Test-Path $path){
                (Get-Item $path).GetValueNames() | Sort-Object | ForEach-Object {
                    $k=Get-Item $path
                    [pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
                } | ConvertTo-Json -Compress
            } else { 'absent' }
        }
        $before = Get-RunSnapshot
        & $provider -Action Check | Out-Null
        $state = Join-Path $TestDrive 'state.json'; $log = Join-Path $TestDrive 'events.jsonl'
        try { & $provider -Action Capture -StatePath $state -LogPath $log | Out-Null } catch { }
        if(Test-Path $state){ Remove-Item -LiteralPath $state -Force }
        try { & $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { }
        try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { }
        $after = Get-RunSnapshot
        $after | Should -BeExactly $before
    }
}

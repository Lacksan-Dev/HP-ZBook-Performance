$provider = Join-Path $PSScriptRoot '..\providers\LogiOptionsPlusDemandLaunch.ps1'
Describe 'LogiOptionsPlusDemandLaunch integration' -Tag 'WindowsIntegration' {
    It 'keeps the Run key unchanged during Check and Apply WhatIf' -Skip:(-not $env:LACKSAN_RUN_WINDOWS_INTEGRATION) {
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
        $before = if(Test-Path $path){ (Get-Item $path).GetValueNames() | Sort-Object | ForEach-Object { $k=Get-Item $path; [pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)} } | ConvertTo-Json -Compress } else { 'absent' }
        & $provider -Action Check | Out-Null
        $state = Join-Path $TestDrive 'state.json'; $log = Join-Path $TestDrive 'events.jsonl'
        try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { }
        $after = if(Test-Path $path){ (Get-Item $path).GetValueNames() | Sort-Object | ForEach-Object { $k=Get-Item $path; [pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)} } | ConvertTo-Json -Compress } else { 'absent' }
        $after | Should -BeExactly $before
    }
}

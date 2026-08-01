$provider=Join-Path $PSScriptRoot '..\providers\HPOneAgentDelayedStart.ps1'
$runIntegration=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'
Describe 'EXP-101 HPOneAgentDelayedStart zero-mutation integration' -Skip:(-not $runIntegration) {
    function Get-ServiceSnapshot {
        Get-CimInstance Win32_Service | Sort-Object Name | Select-Object Name,State,StartMode,PathName | ConvertTo-Json -Compress -Depth 4
    }
    function Get-OneAgentTaskSnapshot {
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {$_.TaskName -match '(?i)HpOneAgent' -or $_.TaskPath -match '(?i)HP.*OneAgent'} | Sort-Object TaskPath,TaskName | ForEach-Object {
            [ordered]@{TaskPath=$_.TaskPath;TaskName=$_.TaskName;State=$_.State.ToString();Enabled=($_.Settings.Enabled-ne$false);XmlHash=([BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes((Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath)))).Replace('-',''))}
        } | ConvertTo-Json -Compress -Depth 6
    }
    function Get-DriverSnapshot {
        Get-CimInstance Win32_SystemDriver | Sort-Object Name | Select-Object Name,State,StartMode,PathName | ConvertTo-Json -Compress -Depth 4
    }
    function Get-DeviceSnapshot {
        Get-PnpDevice -ErrorAction SilentlyContinue | Sort-Object InstanceId | Select-Object InstanceId,Class,FriendlyName,Status | ConvertTo-Json -Compress -Depth 4
    }
    function Get-ProtectedProcessSnapshot {
        Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -match '(?i)omnissa|horizon|msrdc|mstsc|tailscale'} | Sort-Object ProcessName | Select-Object ProcessName,Id | ConvertTo-Json -Compress -Depth 4
    }
    It 'leaves services tasks drivers devices and protected processes unchanged during non-mutating actions' {
        $state=Join-Path $TestDrive 'exp101-state.json';$log=Join-Path $TestDrive 'exp101.jsonl'
        $before=[ordered]@{Services=Get-ServiceSnapshot;Tasks=Get-OneAgentTaskSnapshot;Drivers=Get-DriverSnapshot;Devices=Get-DeviceSnapshot;Protected=Get-ProtectedProcessSnapshot}
        & $provider -Action Check -LogPath $log | Out-Null
        try { & $provider -Action Capture -StatePath $state -LogPath $log | Out-Null } catch { }
        try { & $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { }
        try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { }
        $after=[ordered]@{Services=Get-ServiceSnapshot;Tasks=Get-OneAgentTaskSnapshot;Drivers=Get-DriverSnapshot;Devices=Get-DeviceSnapshot;Protected=Get-ProtectedProcessSnapshot}
        $after.Services | Should -BeExactly $before.Services
        $after.Tasks | Should -BeExactly $before.Tasks
        $after.Drivers | Should -BeExactly $before.Drivers
        $after.Devices | Should -BeExactly $before.Devices
        $after.Protected | Should -BeExactly $before.Protected
    }
}

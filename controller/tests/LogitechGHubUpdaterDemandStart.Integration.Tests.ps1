$provider = Join-Path $PSScriptRoot '..\providers\LogitechGHubUpdaterDemandStart.ps1'
Describe 'LogitechGHubUpdaterDemandStart integration' -Tag 'WindowsIntegration' {
    BeforeAll {
        if($env:RUN_LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT'){ Set-ItResult -Skipped -Because 'Opt-in Windows integration only.'; return }
        function Snapshot-State {
            $svc = Get-CimInstance Win32_Service | Sort-Object Name | Select-Object Name,State,StartMode,PathName
            $reg = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services' -ErrorAction SilentlyContinue | ForEach-Object {
                $p=Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
                [pscustomobject]@{Name=$_.PSChildName;Start=$p.Start;DelayedAutoStart=$p.DelayedAutoStart;ImagePath=$p.ImagePath}
            }
            $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Sort-Object TaskPath,TaskName | Select-Object TaskPath,TaskName,State
            $drivers = Get-CimInstance Win32_SystemDriver | Sort-Object Name | Select-Object Name,State,StartMode,PathName
            $devices = Get-PnpDevice -ErrorAction SilentlyContinue | Sort-Object InstanceId | Select-Object InstanceId,Status,Class
            $protected = Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -match '(?i)omnissa|horizon|msrdc|mstsc|tailscale'} | Select-Object ProcessName,Id
            [ordered]@{Services=$svc;Registry=$reg;Tasks=$tasks;Drivers=$drivers;Devices=$devices;ProtectedProcesses=$protected}|ConvertTo-Json -Compress -Depth 8
        }
    }
    It 'keeps service, registry, task, driver, device, and protected-process state unchanged during read-only paths' {
        if($env:RUN_LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT'){ Set-ItResult -Skipped -Because 'Opt-in Windows integration only.'; return }
        $before=Snapshot-State
        & $provider -Action Check | Out-Null
        $afterCheck=Snapshot-State
        $afterCheck | Should -BeExactly $before
        try { & $provider -Action DryRun | Out-Null } catch { }
        $afterDryRun=Snapshot-State
        $afterDryRun | Should -BeExactly $before
        $state=Join-Path $TestDrive 'exp055-state.json'
        try { & $provider -Action Apply -StatePath $state -WhatIf | Out-Null } catch { }
        $afterWhatIf=Snapshot-State
        $afterWhatIf | Should -BeExactly $before
    }
}

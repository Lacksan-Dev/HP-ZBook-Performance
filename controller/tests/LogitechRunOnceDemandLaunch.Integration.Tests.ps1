$provider = Join-Path $PSScriptRoot '..\providers\LogitechRunOnceDemandLaunch.ps1'
Describe 'LogitechRunOnceDemandLaunch integration' -Tag 'WindowsIntegration' {
    It 'keeps RunOnce and protected system state unchanged during Check, DryRun, and Apply WhatIf' -Skip:(-not $env:LACKSAN_RUN_WINDOWS_INTEGRATION) {
        function Snapshot-Boundary {
            $runOnce = foreach($path in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce') {
                if(Test-Path -LiteralPath $path){ $k=Get-Item -LiteralPath $path; foreach($n in $k.GetValueNames()){ [ordered]@{Path=$path;Name=$n;Kind=$k.GetValueKind($n).ToString();Data=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)} } }
            }
            $services = Get-Service | Sort-Object Name | ForEach-Object { [ordered]@{Name=$_.Name;Status=$_.Status.ToString();StartType=$_.StartType.ToString()} }
            $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Sort-Object TaskPath,TaskName | ForEach-Object { [ordered]@{Path=$_.TaskPath;Name=$_.TaskName;State=$_.State.ToString()} }
            $drivers = Get-CimInstance Win32_SystemDriver | Sort-Object Name | ForEach-Object { [ordered]@{Name=$_.Name;State=$_.State;StartMode=$_.StartMode} }
            $protected = Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -match '(?i)omnissa|vmware|mstsc|tailscale|windowsapp'} | Select-Object -ExpandProperty ProcessName | Sort-Object -Unique
            [ordered]@{RunOnce=@($runOnce);Services=@($services);Tasks=@($tasks);Drivers=@($drivers);Protected=@($protected)} | ConvertTo-Json -Compress -Depth 12
        }
        $before=Snapshot-Boundary
        & $provider -Action Check | Out-Null
        try { & $provider -Action DryRun | Out-Null } catch { }
        $state=Join-Path $TestDrive 'exp107-state.json'
        try { & $provider -Action Apply -StatePath $state -WhatIf | Out-Null } catch { }
        $after=Snapshot-Boundary
        $after | Should -BeExactly $before
    }
}

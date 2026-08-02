Describe 'EXP-121 LogiBoltStartupFolder zero-mutation integration' -Tag 'Integration' {
    BeforeAll {
        if ($env:LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') { Set-ItResult -Skipped -Because 'Set LACKSAN_WINDOWS_INTEGRATION=1 on a Windows lab host.'; return }
        $provider = Join-Path $PSScriptRoot '..\providers\LogiBoltStartupFolder.ps1'
        $script:state = Join-Path $TestDrive 'exp121-state.json'
        $script:log = Join-Path $TestDrive 'exp121-events.jsonl'
        function Snapshot-System {
            [ordered]@{
                Services = @(Get-Service | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.Status)|$($_.StartType)" })
                Tasks = @(Get-ScheduledTask | Sort-Object TaskPath,TaskName | ForEach-Object { "$($_.TaskPath)$($_.TaskName)|$($_.State)|$($_.Settings.Enabled)" })
                Drivers = @(Get-CimInstance Win32_SystemDriver | Sort-Object Name | ForEach-Object { "$($_.Name)|$($_.State)|$($_.StartMode)" })
                Devices = @(Get-PnpDevice -ErrorAction SilentlyContinue | Sort-Object InstanceId | ForEach-Object { "$($_.InstanceId)|$($_.Status)" })
                Protected = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '(?i)omnissa|vmware|mstsc|tailscale|windowsapp' } | Sort-Object ProcessName,Id | ForEach-Object { "$($_.ProcessName)|$($_.Id)" })
                CurrentStartup = @(if($p=[Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)){Get-ChildItem -LiteralPath $p -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.ToString('o'))" }})
                CommonStartup = @(if($p=[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartup)){Get-ChildItem -LiteralPath $p -File -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.ToString('o'))" }})
                RunState = @(
                    foreach($key in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce') {
                        if(Test-Path $key){$item=Get-ItemProperty $key; $item.PSObject.Properties | Where-Object {$_.Name -notmatch '^PS'} | Sort-Object Name | ForEach-Object { "$key|$($_.Name)|$($_.Value)" }}
                    }
                )
                BoltPackages = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { "$($_.Name) $($_.PackageFullName)" -match '(?i)logi.*bolt|logibolt' } | Sort-Object PackageFullName | ForEach-Object { "$($_.PackageFullName)|$($_.Status)" })
            } | ConvertTo-Json -Compress -Depth 8
        }
    }

    It 'keeps Check and DryRun mutation-free' {
        if ($env:LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') { Set-ItResult -Skipped -Because 'Windows integration opt-in required.'; return }
        $before = Snapshot-System
        & $provider -Action Check -StatePath $state -LogPath $log | Out-Null
        & $provider -Action DryRun -StatePath $state -LogPath $log -ErrorAction SilentlyContinue | Out-Null
        $after = Snapshot-System
        $after | Should -BeExactly $before
    }

    It 'keeps Apply WhatIf mutation-free' {
        if ($env:LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') { Set-ItResult -Skipped -Because 'Windows integration opt-in required.'; return }
        $before = Snapshot-System
        & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf -ErrorAction SilentlyContinue | Out-Null
        $after = Snapshot-System
        $after | Should -BeExactly $before
    }
}

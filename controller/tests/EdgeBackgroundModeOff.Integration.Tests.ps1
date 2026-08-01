$provider = Join-Path $PSScriptRoot '..\providers\EdgeBackgroundModeOff.ps1'
Describe 'EdgeBackgroundModeOff integration' -Tag 'WindowsIntegration' {
    BeforeAll {
        if($env:RUN_LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT'){ Set-ItResult -Skipped -Because 'Opt-in Windows integration only.'; return }
        function Snapshot-State {
            $edgePolicy = foreach($path in 'HKLM:\SOFTWARE\Policies\Microsoft\Edge','HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'){
                if(Test-Path -LiteralPath $path){
                    $k=Get-Item -LiteralPath $path
                    [pscustomobject]@{Path=$path;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}
                }else{[pscustomobject]@{Path=$path;Values=@()}}
            }
            $startup = foreach($path in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}|Select-Object -Unique){
                if(Test-Path -LiteralPath $path){Get-ChildItem -LiteralPath $path -File -ErrorAction SilentlyContinue|Sort-Object FullName|Select-Object FullName,Length,LastWriteTimeUtc}
            }
            $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
            $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
            $protected=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale'}|Select-Object -ExpandProperty ProcessName|Sort-Object -Unique)
            $security=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
            [ordered]@{EdgePolicy=$edgePolicy;StartupFolders=@($startup);Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices;ProtectedProcesses=$protected;SecurityServices=$security}|ConvertTo-Json -Compress -Depth 10
        }
    }
    It 'keeps policy startup service task driver device security and protected-process state unchanged during read-only paths' {
        if($env:RUN_LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT'){ Set-ItResult -Skipped -Because 'Opt-in Windows integration only.'; return }
        $before=Snapshot-State
        & $provider -Action Check | Out-Null
        (Snapshot-State) | Should -BeExactly $before
        try { & $provider -Action DryRun | Out-Null } catch { }
        (Snapshot-State) | Should -BeExactly $before
        $state=Join-Path $TestDrive 'exp071-state.json'
        try { & $provider -Action Apply -StatePath $state -WhatIf | Out-Null } catch { }
        (Snapshot-State) | Should -BeExactly $before
    }
}

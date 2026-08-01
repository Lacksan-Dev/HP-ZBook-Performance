$provider=Join-Path $PSScriptRoot '..\providers\HPSysInfoDemandStart.ps1'
Describe 'EXP-065 HPSysInfoDemandStart zero-mutation integration' -Tag 'WindowsIntegration' {
    BeforeAll {
        if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
        function Snapshot-State {
            $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $serviceRegistry=if(Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\HPSysInfoCap'){$k=Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Services\HPSysInfoCap';[ordered]@{Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[ordered]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}else{$null}
            $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
            $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
            $security=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
            $protected=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale'}|Select-Object -ExpandProperty ProcessName|Sort-Object -Unique)
            [ordered]@{Services=$services;TargetRegistry=$serviceRegistry;Tasks=$tasks;Drivers=$drivers;Devices=$devices;Security=$security;ProtectedProcesses=$protected}|ConvertTo-Json -Compress -Depth 10
        }
    }
    It 'keeps service registry task driver device security and protected process state unchanged during read-only paths' {
        if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
        $before=Snapshot-State;$state=Join-Path $TestDrive 'exp065-state.json';$log=Join-Path $TestDrive 'exp065.jsonl'
        & $provider -Action Check -LogPath $log|Out-Null;(Snapshot-State)|Should -BeExactly $before
        try{& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
        if(Test-Path -LiteralPath $state){Remove-Item -LiteralPath $state -Force}
        try{& $provider -Action DryRun -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
        try{& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
    }
}

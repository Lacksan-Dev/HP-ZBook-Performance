$provider=Join-Path $PSScriptRoot '..\providers\Microsoft365RunDemandLaunch.ps1'
Describe 'EXP-124 Microsoft365RunDemandLaunch zero-mutation integration' -Tag 'WindowsIntegration' {
    BeforeAll {
        if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
        function Snapshot-State {
            $run=foreach($path in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'){
                if(Test-Path -LiteralPath $path){$k=Get-Item -LiteralPath $path;foreach($n in $k.GetValueNames()|Sort-Object){[ordered]@{Path=$path;Name=$n;Kind=$k.GetValueKind($n).ToString();Data=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}}
            }
            $runOnce=foreach($path in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'){
                if(Test-Path -LiteralPath $path){$k=Get-Item -LiteralPath $path;foreach($n in $k.GetValueNames()|Sort-Object){[ordered]@{Path=$path;Name=$n;Kind=$k.GetValueKind($n).ToString();Data=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}}
            }
            $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
            $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
            $security=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,ClickToRunSvc -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
            $protected=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp'}|Select-Object -ExpandProperty ProcessName|Sort-Object -Unique)
            [ordered]@{Run=@($run);RunOnce=@($runOnce);Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices;Security=$security;ProtectedProcesses=$protected}|ConvertTo-Json -Compress -Depth 10
        }
    }
    It 'keeps registry service task driver device security and protected-process state unchanged during read-only paths' {
        if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
        $before=Snapshot-State;$state=Join-Path $TestDrive 'exp124-state.json';$log=Join-Path $TestDrive 'exp124-events.jsonl'
        & $provider -Action Check -LogPath $log|Out-Null;(Snapshot-State)|Should -BeExactly $before
        try{& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
        if(Test-Path -LiteralPath $state){Remove-Item -LiteralPath $state -Force}
        try{& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
        try{& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
    }
}

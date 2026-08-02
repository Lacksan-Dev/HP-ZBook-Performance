$provider=Join-Path $PSScriptRoot '..\providers\MicrosoftTeamsRunOnceDemandLaunch.ps1'
Describe 'EXP-133 issue 301 MicrosoftTeamsRunOnceDemandLaunch zero-mutation integration' -Tag 'WindowsIntegration' {
    BeforeAll {
        if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
        function Snapshot-State {
            $run=foreach($path in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'){
                if(Test-Path -LiteralPath $path){$k=Get-Item -LiteralPath $path;foreach($n in $k.GetValueNames()|Sort-Object){[ordered]@{Path=$path;Name=$n;Kind=$k.GetValueKind($n).ToString();Data=[string]$k.GetValue($n,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}}
            }
            $startup=@([Environment]::GetFolderPath([Environment+SpecialFolder]::Startup),[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartup))|ForEach-Object{if($_-and(Test-Path -LiteralPath $_)){Get-ChildItem -LiteralPath $_ -Force|Sort-Object FullName|ForEach-Object{[ordered]@{FullName=$_.FullName;Length=$_.Length;LastWriteTimeUtc=$_.LastWriteTimeUtc.ToString('o')}}}}
            $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|ForEach-Object{[ordered]@{TaskPath=$_.TaskPath;TaskName=$_.TaskName;Enabled=[bool]$_.Settings.Enabled;State=$_.State.ToString()}}
            $packages=Get-AppxPackage -Name MSTeams -ErrorAction SilentlyContinue|Sort-Object PackageFullName|Select-Object Name,PackageFamilyName,PackageFullName,Version,Publisher
            $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
            $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
            $security=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,Tailscale -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
            $protected=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp'}|Select-Object -ExpandProperty ProcessName|Sort-Object -Unique)
            [ordered]@{Run=@($run);Startup=@($startup);Tasks=@($tasks);TeamsPackages=@($packages);Services=@($services);Drivers=@($drivers);Devices=@($devices);Security=@($security);ProtectedProcesses=$protected}|ConvertTo-Json -Compress -Depth 12
        }
    }
    It 'keeps startup service task package driver device security and protected state unchanged during read-only and WhatIf paths' {
        if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
        $before=Snapshot-State;$state=Join-Path $TestDrive 'exp133-state.json';$log=Join-Path $TestDrive 'exp133-events.jsonl'
        & $provider -Action Check -LogPath $log|Out-Null;(Snapshot-State)|Should -BeExactly $before
        try{& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
        if(Test-Path -LiteralPath $state){Remove-Item -LiteralPath $state -Force}
        try{& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
        try{& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
    }
}

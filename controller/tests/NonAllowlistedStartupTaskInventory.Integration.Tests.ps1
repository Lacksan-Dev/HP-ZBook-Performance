$probe=Join-Path $PSScriptRoot '..\research\NonAllowlistedStartupTaskInventory.ps1'
Describe 'EXP-135 issue 305 NonAllowlistedStartupTaskInventory zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
  function Snapshot-State {
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|ForEach-Object{[ordered]@{TaskPath=$_.TaskPath;TaskName=$_.TaskName;Enabled=[bool]$_.Settings.Enabled;State=$_.State.ToString()}}
   $run=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce')|ForEach-Object{if(Test-Path $_){[ordered]@{Path=$_;Values=(Get-ItemProperty $_|Select-Object * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider)}}}
   $startup=@([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|ForEach-Object{if($_-and(Test-Path -LiteralPath $_)){Get-ChildItem -LiteralPath $_ -Force|Sort-Object FullName|ForEach-Object{[ordered]@{FullName=$_.FullName;Length=$_.Length;LastWriteTimeUtc=$_.LastWriteTimeUtc.ToString('o')}}}}
   $packages=Get-AppxPackage -ErrorAction SilentlyContinue|Sort-Object PackageFamilyName|Select-Object Name,PackageFamilyName,PackageFullName,Version,Publisher
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   $security=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,Tailscale -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
   $protected=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp'}|Sort-Object ProcessName,Id|Select-Object ProcessName,Id)
   [ordered]@{Tasks=$tasks;Run=$run;Startup=$startup;Packages=$packages;Services=$services;Drivers=$drivers;Devices=$devices;Security=$security;ProtectedProcesses=$protected}|ConvertTo-Json -Compress -Depth 12
  }
 }
 It 'keeps task startup package service driver device security and protected state unchanged during Check DryRun and Capture' {
  if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
  $before=Snapshot-State;$state=Join-Path $TestDrive 'exp135-issue305-state.json';$log=Join-Path $TestDrive 'exp135-issue305.jsonl'
  & $probe -Action Check -LogPath $log|Out-Null;(Snapshot-State)|Should -BeExactly $before
  $dry=& $probe -Action DryRun -LogPath $log;$dry.zeroMutation|Should -BeTrue;$dry.plannedMutation|Should -BeNullOrEmpty;(Snapshot-State)|Should -BeExactly $before
  & $probe -Action Capture -StatePath $state -LogPath $log|Out-Null;(Snapshot-State)|Should -BeExactly $before
 }
}

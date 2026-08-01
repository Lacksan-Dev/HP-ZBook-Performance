$provider=Join-Path $PSScriptRoot '..\providers\MicrosoftTeamsSigninTask.ps1'
Describe 'EXP-125 issue 289 MicrosoftTeamsSigninTask zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
  function Snapshot-State {
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|ForEach-Object{[pscustomobject]@{TaskPath=$_.TaskPath;TaskName=$_.TaskName;Enabled=$_.Settings.Enabled;State=$_.State.ToString();XmlHash=try{$x=Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath;$s=[Security.Cryptography.SHA256]::Create();try{($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($x))|ForEach-Object{$_.ToString('x2')})-join''}finally{$s.Dispose()}}catch{'error'}}}
   $run=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce')|ForEach-Object{if(Test-Path $_){[ordered]@{Path=$_;Values=(Get-ItemProperty $_|Select-Object * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider)}}}
   $startup=@([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|ForEach-Object{if($_ -and(Test-Path -LiteralPath $_)){Get-ChildItem -LiteralPath $_ -Force|Sort-Object FullName|ForEach-Object{[ordered]@{FullName=$_.FullName;Length=$_.Length;LastWriteTimeUtc=$_.LastWriteTimeUtc.ToString('o')}}}}
   $packages=Get-AppxPackage -Name MSTeams -ErrorAction SilentlyContinue|Select-Object Name,PackageFullName,PackageFamilyName,Version,Publisher
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   $protected=Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale'}|Select-Object ProcessName,Id
   [ordered]@{Tasks=$tasks;Run=$run;Startup=$startup;TeamsPackages=$packages;Services=$services;Drivers=$drivers;Devices=$devices;ProtectedProcesses=$protected}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps task startup package service driver device and protected-process state unchanged during Check Capture DryRun and Apply WhatIf' {
  if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
  $before=Snapshot-State;$state=Join-Path $TestDrive 'exp125-issue289-state.json';$log=Join-Path $TestDrive 'exp125-issue289.jsonl'
  & $provider -Action Check -LogPath $log|Out-Null;(Snapshot-State)|Should -BeExactly $before
  try{& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
  if(Test-Path -LiteralPath $state){Remove-Item -LiteralPath $state -Force}
  try{& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
  try{& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{};(Snapshot-State)|Should -BeExactly $before
 }
}

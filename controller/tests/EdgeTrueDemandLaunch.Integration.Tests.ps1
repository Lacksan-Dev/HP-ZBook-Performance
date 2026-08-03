$provider=Join-Path $PSScriptRoot '..\providers\EdgeTrueDemandLaunch.ps1'
Describe 'EXP-054 Edge true demand-launch zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){return}
  function Snapshot-State {
   $policy=foreach($path in 'HKLM:\SOFTWARE\Policies\Microsoft\Edge','HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'){if(Test-Path $path){$k=Get-Item $path;[pscustomobject]@{Path=$path;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}else{[pscustomobject]@{Path=$path;Values=@()}}}
   $startup=foreach($path in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}|Select-Object -Unique){if(Test-Path $path){Get-ChildItem $path -File -ErrorAction SilentlyContinue|Sort-Object FullName|Select-Object FullName,Length,LastWriteTimeUtc}}
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   $security=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,TermService,Tailscale,edgeupdate,edgeupdatem -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
   [ordered]@{EdgePolicy=$policy;Startup=@($startup);Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices;Security=$security}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps Check DryRun and Apply WhatIf production state unchanged' {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
  $before=Snapshot-State;$state=Join-Path $TestDrive 'exp054-state.json';$log=Join-Path $TestDrive 'exp054-events.jsonl'
  try{& $provider -Action Check -StatePath $state -LogPath $log|Out-Null}catch{}
  try{& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{}
  try{& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null;& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{}
  (Snapshot-State)|Should -BeExactly $before
 }
}

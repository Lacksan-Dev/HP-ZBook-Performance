$provider=Join-Path $PSScriptRoot '..\providers\HpAppHelperManualDemandStart.ps1'
Describe 'EXP-063 HP App Helper zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){return}
  function Snapshot-State {
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   $security=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,TermService,Tailscale -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
   $protected=@(Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName-match'(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp'}|Select-Object ProcessName,Id|Sort-Object ProcessName,Id)
   [ordered]@{Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices;Security=$security;ProtectedProcesses=$protected}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps Check DryRun and Apply WhatIf mutation-free' {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in HP Windows 11 integration only.';return}
  $before=Snapshot-State;$root=Join-Path $TestDrive 'exp063';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl'
  try{& $provider -Action Check -StatePath $state -LogPath $log|Out-Null}catch{}
  try{& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{}
  try{& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null;& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{}
  (Snapshot-State)|Should -BeExactly $before
 }
}

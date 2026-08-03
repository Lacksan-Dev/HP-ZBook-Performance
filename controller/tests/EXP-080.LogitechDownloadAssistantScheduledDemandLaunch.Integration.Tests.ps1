$Provider=Join-Path $PSScriptRoot '..\providers\LogitechDownloadAssistantScheduledDemandLaunch.ps1'
Describe 'EXP-080 Windows zero-mutation integration' -Tag 'WindowsIntegration' {
 It 'Check DryRun and Apply WhatIf preserve scheduled tasks services and Logitech drivers' {
  if($env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Windows integration only';return}
  if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1'){Set-ItResult -Skipped -Because 'Set LACKSAN_RUN_WINDOWS_INTEGRATION=1 to opt in';return}
  function Snapshot {
   $tasks=@(Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|ForEach-Object{[pscustomobject]@{TaskPath=$_.TaskPath;TaskName=$_.TaskName;State=$_.State.ToString();Enabled=[bool]$_.Settings.Enabled}})
   $services=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $drivers=@(Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue|Where-Object{$_.Name-match'(?i)logi|logitech'-or$_.PathName-match'(?i)logi|logitech'}|Sort-Object Name|Select-Object Name,State,StartMode,PathName)
   [ordered]@{Tasks=$tasks;Services=@($services);Drivers=$drivers}|ConvertTo-Json -Compress -Depth 12
  }
  $before=Snapshot;$state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  $check=& $Provider -Action Check -StatePath $state -LogPath $log
  try{& $Provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{}
  if($check.Supported){try{& $Provider -Action Capture -StatePath $state -LogPath $log|Out-Null;& $Provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{}}
  (Snapshot)|Should -BeExactly $before
 }
}

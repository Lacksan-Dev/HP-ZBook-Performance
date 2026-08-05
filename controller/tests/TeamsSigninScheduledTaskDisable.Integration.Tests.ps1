Describe 'EXP-125 Teams scheduled-task zero-mutation Windows integration' -Tag WindowsIntegration {
 BeforeAll{
  $script:provider=Join-Path $PSScriptRoot '..\providers\TeamsSigninScheduledTaskDisable.ps1'
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-State{
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|ForEach-Object{[pscustomobject]@{TaskPath=$_.TaskPath;TaskName=$_.TaskName;Enabled=[bool]$_.Settings.Enabled;Actions=@($_.Actions|ForEach-Object{"$($_.Execute)|$($_.Arguments)|$($_.WorkingDirectory)"})}}
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,StartName,PathName
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   [ordered]@{Tasks=$tasks;Services=$services;Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 12
  }
 }
 It 'keeps tasks services drivers and devices unchanged through Check and DryRun' -Skip:(-not$script:enabled) {
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl';$before=Snapshot-State
  $check=& $script:provider -Action Check -StatePath $state -LogPath $log
  (Snapshot-State)|Should -BeExactly $before
  if($check.Supported){& $script:provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}
  (Snapshot-State)|Should -BeExactly $before
  Test-Path -LiteralPath $state|Should -BeFalse
 }
 It 'keeps production state unchanged through Capture and Apply WhatIf when eligible' -Skip:(-not$script:enabled) {
  $state=Join-Path $TestDrive 'whatif-state.json';$log=Join-Path $TestDrive 'whatif-events.jsonl';$before=Snapshot-State
  $check=& $script:provider -Action Check -StatePath $state -LogPath $log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join' ');return}
  & $script:provider -Action Capture -StatePath $state -LogPath $log|Out-Null
  $result=& $script:provider -Action Apply -StatePath $state -LogPath $log -WhatIf
  $result.WhatIf|Should -BeTrue
  (Snapshot-State)|Should -BeExactly $before
 }
 It 'limits mutation commands to the selected task enabled state' {
  $text=Get-Content -LiteralPath $script:provider -Raw
  $text|Should -Match 'Disable-ScheduledTask';$text|Should -Match 'Enable-ScheduledTask'
  $text|Should -Not -Match 'Register-ScheduledTask|Unregister-ScheduledTask|Set-ScheduledTask|Set-Service|Stop-Service|Disable-PnpDevice|Remove-PnpDevice|Remove-AppxPackage|Uninstall-Package|Set-MpPreference|Set-NetFirewall'
 }
}

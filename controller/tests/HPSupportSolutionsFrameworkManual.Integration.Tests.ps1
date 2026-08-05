Describe 'EXP-087 zero-mutation Windows integration' -Tag 'WindowsIntegration' {
 BeforeAll{
  $script:providerPath=Join-Path $PSScriptRoot '..\providers\HPSupportSolutionsFrameworkManual.ps1'
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-State{
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,StartName,PathName
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   [ordered]@{Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps service task driver and device state unchanged through Check and DryRun' -Skip:(-not$script:enabled) {
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl';$before=Snapshot-State
  $check=& $script:providerPath -Action Check -StatePath $state -LogPath $log
  if($check.Supported){& $script:providerPath -Action DryRun -StatePath $state -LogPath $log|Out-Null}
  (Snapshot-State)|Should -BeExactly $before
  Test-Path $state|Should -BeFalse
 }
 It 'keeps production state unchanged through Capture and Apply WhatIf when eligible' -Skip:(-not$script:enabled) {
  $state=Join-Path $TestDrive 'whatif-state.json';$log=Join-Path $TestDrive 'whatif-events.jsonl';$before=Snapshot-State
  $check=& $script:providerPath -Action Check -StatePath $state -LogPath $log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join' ');return}
  & $script:providerPath -Action Capture -StatePath $state -LogPath $log|Out-Null;$captured=Get-Content $state -Raw
  $result=& $script:providerPath -Action Apply -StatePath $state -LogPath $log -WhatIf
  $result.WhatIf|Should -BeTrue;(Get-Content $state -Raw)|Should -BeExactly $captured;(Snapshot-State)|Should -BeExactly $before
 }
 It 'limits production mutation primitives to service startup configuration and rollback running-state restoration' {
  $text=Get-Content $script:providerPath -Raw
  $text|Should -Match 'sc\.exe config';$text|Should -Match 'Start-Service';$text|Should -Match 'Stop-Service'
  $text|Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Disable-PnpDevice|Remove-PnpDevice|pnputil|Set-MpPreference|Set-NetFirewall|Remove-Service|sc\.exe\s+delete'
 }
}

Describe 'EXP-079 Edge Startup Boost zero-mutation Windows integration' -Tag WindowsIntegration {
 BeforeAll{
  $script:provider=Join-Path $PSScriptRoot '..\providers\EdgeStartupBoostEnabledPolicy.ps1'
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-State{
   $recommended=if(Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'){Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'|Select-Object * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider}else{$null}
   $mandatory=if(Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'){Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'|Select-Object * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider}else{$null}
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   [ordered]@{Recommended=$recommended;Mandatory=$mandatory;Services=$services;Tasks=$tasks;Drivers=$drivers}|ConvertTo-Json -Compress -Depth 12
  }
 }
 It 'keeps policy service task and driver state unchanged through Check and DryRun' -Skip:(-not$script:enabled) {
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl';$before=Snapshot-State
  $check=& $script:provider -Action Check -StatePath $state -LogPath $log
  (Snapshot-State)|Should -BeExactly $before
  if($check.Supported){$dry=& $script:provider -Action DryRun -StatePath $state -LogPath $log;$dry.MutationCount|Should -Be 1}
  (Snapshot-State)|Should -BeExactly $before
  Test-Path -LiteralPath $state|Should -BeFalse
 }
 It 'keeps production state unchanged through Capture and Apply WhatIf when eligible' -Skip:(-not$script:enabled) {
  $state=Join-Path $TestDrive 'whatif-state.json';$log=Join-Path $TestDrive 'whatif-events.jsonl';$before=Snapshot-State
  $check=& $script:provider -Action Check -StatePath $state -LogPath $log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join' ');return}
  & $script:provider -Action Capture -StatePath $state -LogPath $log|Out-Null;$captured=Get-Content $state -Raw
  $result=& $script:provider -Action Apply -StatePath $state -LogPath $log -WhatIf
  $result.WhatIf|Should -BeTrue;(Get-Content $state -Raw)|Should -BeExactly $captured;(Snapshot-State)|Should -BeExactly $before
 }
 It 'limits production mutation to the selected Edge policy value' {
  $text=Get-Content -LiteralPath $script:provider -Raw
  $text|Should -Match 'New-ItemProperty';$text|Should -Match 'Remove-ItemProperty'
  $text|Should -Not -Match 'Set-Service|Stop-Service|Disable-ScheduledTask|Register-ScheduledTask|Remove-AppxPackage|Disable-PnpDevice|Remove-PnpDevice|Set-MpPreference|Set-NetFirewall'
 }
}

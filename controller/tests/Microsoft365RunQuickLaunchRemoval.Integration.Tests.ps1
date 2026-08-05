Describe 'EXP-124 zero-mutation Windows integration' -Tag 'WindowsIntegration' {
 BeforeAll{
  $script:providerPath=Join-Path $PSScriptRoot '..\providers\Microsoft365RunQuickLaunchRemoval.ps1'
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-State{
   $registry=@()
   foreach($root in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce')){if(Test-Path -LiteralPath $root){$k=Get-Item -LiteralPath $root;$registry+=[pscustomobject]@{Path=$root;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}}
   $startup=@();foreach($path in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}|Select-Object -Unique){if(Test-Path -LiteralPath $path){$startup+=@(Get-ChildItem -LiteralPath $path -File -Force -ErrorAction SilentlyContinue|Sort-Object FullName|Select-Object FullName,Length,LastWriteTimeUtc)}}
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   [ordered]@{Registry=$registry;StartupFolders=$startup;Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 12
  }
 }
 It 'keeps registry startup service task driver and device state unchanged through Check and DryRun' -Skip:(-not$script:enabled) {
  $before=Snapshot-State
  $check=& $script:providerPath -Action Check -StatePath (Join-Path $TestDrive 'state.json') -LogPath (Join-Path $TestDrive 'events.jsonl')
  if($check.Supported){& $script:providerPath -Action DryRun -StatePath (Join-Path $TestDrive 'state.json') -LogPath (Join-Path $TestDrive 'events.jsonl')|Out-Null}
  (Snapshot-State)|Should -BeExactly $before
  Test-Path (Join-Path $TestDrive 'state.json')|Should -BeFalse
 }
 It 'keeps production state unchanged through Capture and Apply WhatIf when eligible' -Skip:(-not$script:enabled) {
  $state=Join-Path $TestDrive 'whatif-state.json';$log=Join-Path $TestDrive 'whatif-events.jsonl';$before=Snapshot-State
  $check=& $script:providerPath -Action Check -StatePath $state -LogPath $log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join' ');return}
  & $script:providerPath -Action Capture -StatePath $state -LogPath $log|Out-Null
  $captured=Get-Content -LiteralPath $state -Raw
  $result=& $script:providerPath -Action Apply -StatePath $state -LogPath $log -WhatIf
  $result.WhatIf|Should -BeTrue
  (Get-Content -LiteralPath $state -Raw)|Should -BeExactly $captured
  (Get-Content -LiteralPath $log -Raw)|Should -Match '"result":"whatif"'
  (Snapshot-State)|Should -BeExactly $before
 }
 It 'contains no mutation primitive outside the selected Run value' {
  $text=Get-Content -LiteralPath $script:providerPath -Raw
  $text|Should -Not -Match 'Disable-ScheduledTask|Unregister-ScheduledTask|Set-Service|Stop-Service|Remove-Service|Remove-AppxPackage|Uninstall-Package|Disable-PnpDevice|Remove-PnpDevice|pnputil|Set-MpPreference|Set-NetFirewall'
  $text|Should -Match 'DeleteValue'
  $text|Should -Match 'SetValue'
 }
}

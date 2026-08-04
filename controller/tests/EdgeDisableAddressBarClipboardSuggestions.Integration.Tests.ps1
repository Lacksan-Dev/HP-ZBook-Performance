$provider=Join-Path $PSScriptRoot '..\providers\EdgeDisableAddressBarClipboardSuggestions.ps1'
Describe 'EdgeDisableAddressBarClipboardSuggestions integration' -Tag 'WindowsIntegration' {
 BeforeAll{
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in Windows integration only.';return}
  function Snapshot-State{
   $policy=foreach($path in 'HKLM:\SOFTWARE\Policies\Microsoft\Edge','HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'){if(Test-Path $path){$k=Get-Item $path;[pscustomobject]@{Path=$path;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}else{[pscustomobject]@{Path=$path;Values=@()}}}
   $startup=foreach($path in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}|Select-Object -Unique){if(Test-Path $path){Get-ChildItem $path -File -ErrorAction SilentlyContinue|Sort-Object FullName|Select-Object FullName,Length,LastWriteTimeUtc}}
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   [ordered]@{EdgePolicy=$policy;StartupFolders=@($startup);Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps policy startup service task driver and device state unchanged during read-only paths'{
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in Windows integration only.';return}
  $before=Snapshot-State
  & $provider -Action Check -ProfileFixturePath $TestDrive|Out-Null
  (Snapshot-State)|Should -BeExactly $before
  try{& $provider -Action DryRun -ProfileFixturePath $TestDrive|Out-Null}catch{}
  (Snapshot-State)|Should -BeExactly $before
  try{& $provider -Action Apply -ProfileFixturePath $TestDrive -StatePath (Join-Path $TestDrive 'exp151-state.json') -WhatIf|Out-Null}catch{}
  (Snapshot-State)|Should -BeExactly $before
 }
}

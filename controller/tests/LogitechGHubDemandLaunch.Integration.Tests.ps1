$provider=Join-Path $PSScriptRoot '..\providers\LogitechGHubDemandLaunch.ps1'
Describe 'EXP-053 Logitech G Hub zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-State {
   $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';$run=if(Test-Path $path){$k=Get-Item $path;@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}else{@()}
   $protected=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,TermService,Tailscale -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
   $drivers=Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue|Where-Object{$_.Name-match'(?i)logi|logitech'-or$_.PathName-match'(?i)logi|logitech'}|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Where-Object{$_.FriendlyName-match'(?i)logi|logitech'-or$_.Manufacturer-match'(?i)logi|logitech'}|Sort-Object InstanceId|Select-Object InstanceId,Status,Class,FriendlyName
   [ordered]@{Run=$run;Protected=$protected;LogitechDrivers=$drivers;LogitechDevices=$devices}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps Run protected-service driver and device state unchanged during Check and DryRun' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp053-readonly';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$before=Snapshot-State
  try{$check=& $provider -Action Check -StatePath $state -LogPath $log;if(!$check.Support.Supported){Set-ItResult -Skipped -Because 'EXP-053 support gate refused this machine.';return};& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-State)|Should -BeExactly $before
 }
 It 'keeps production state unchanged during Capture and Apply WhatIf' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp053-whatif';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$before=Snapshot-State
  try{$check=& $provider -Action Check -StatePath $state -LogPath $log;if(!$check.Support.Supported-or@($check.Candidates).Count-ne1){Set-ItResult -Skipped -Because 'Exactly one eligible EXP-053 candidate is required.';return};& $provider -Action Capture -StatePath $state -LogPath $log|Out-Null;& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-State)|Should -BeExactly $before
 }
}

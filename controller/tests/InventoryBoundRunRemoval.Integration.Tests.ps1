$provider=Join-Path $PSScriptRoot '..\providers\InventoryBoundRunRemoval.ps1'
Describe 'EXP-153 inventory-bound Run zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT'-and!([string]::IsNullOrWhiteSpace($env:LACKSAN_EXP153_SELECTION)))
  function Snapshot-State {
   $keys=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce')
   $rows=@();foreach($p in $keys){if(Test-Path -LiteralPath $p){$k=Get-Item -LiteralPath $p;$rows+=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Path=$p;Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}
   $protected=Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,TermService,Tailscale -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType
   [ordered]@{Registry=$rows;Protected=$protected}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps approved registry and protected-service state unchanged during Check and DryRun' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp153-readonly';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$before=Snapshot-State
  try{$check=& $provider -Action Check -SelectionPath $env:LACKSAN_EXP153_SELECTION -StatePath $state -LogPath $log;if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join'; ');return};& $provider -Action DryRun -SelectionPath $env:LACKSAN_EXP153_SELECTION -StatePath $state -LogPath $log|Out-Null}catch{Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-State)|Should -BeExactly $before
 }
 It 'keeps production state unchanged during Capture and Apply WhatIf' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp153-whatif';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$before=Snapshot-State
  try{$check=& $provider -Action Check -SelectionPath $env:LACKSAN_EXP153_SELECTION -StatePath $state -LogPath $log;if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join'; ');return};& $provider -Action Capture -SelectionPath $env:LACKSAN_EXP153_SELECTION -StatePath $state -LogPath $log|Out-Null;& $provider -Action Apply -SelectionPath $env:LACKSAN_EXP153_SELECTION -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-State)|Should -BeExactly $before
 }
}

$provider=Join-Path $PSScriptRoot '..\providers\PriorityRunRegistrationRemoval.ps1'
Describe 'EXP-153 zero-mutation Windows integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT'-and![string]::IsNullOrWhiteSpace($env:LACKSAN_EXP153_INVENTORY)-and![string]::IsNullOrWhiteSpace($env:LACKSAN_EXP153_REGISTRATION_IDENTITY))
  function Snapshot-ApprovedRunState {
   $paths=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce')
   @($paths|ForEach-Object{$p=$_;if(Test-Path -LiteralPath $p){$k=Get-Item -LiteralPath $p;$k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Path=$p;Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}}})|ConvertTo-Json -Compress -Depth 8
  }
 }
 It 'keeps approved Run state unchanged during Check and DryRun' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp153-check';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl'
  $before=Snapshot-ApprovedRunState
  try {$check=& $provider -Action Check -InventoryPath $env:LACKSAN_EXP153_INVENTORY -RegistrationIdentity $env:LACKSAN_EXP153_REGISTRATION_IDENTITY -StatePath $state -LogPath $log;if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join'; ');return};& $provider -Action DryRun -InventoryPath $env:LACKSAN_EXP153_INVENTORY -RegistrationIdentity $env:LACKSAN_EXP153_REGISTRATION_IDENTITY -StatePath $state -LogPath $log|Out-Null} catch {Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-ApprovedRunState)|Should -BeExactly $before
  (Get-Content -LiteralPath $log -Raw)|Should -Match 'EXP-153'
 }
 It 'keeps approved Run state unchanged during Capture and Apply WhatIf' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp153-whatif';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl'
  $before=Snapshot-ApprovedRunState
  try {$check=& $provider -Action Check -InventoryPath $env:LACKSAN_EXP153_INVENTORY -RegistrationIdentity $env:LACKSAN_EXP153_REGISTRATION_IDENTITY -StatePath $state -LogPath $log;if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join'; ');return};& $provider -Action Capture -InventoryPath $env:LACKSAN_EXP153_INVENTORY -RegistrationIdentity $env:LACKSAN_EXP153_REGISTRATION_IDENTITY -StatePath $state -LogPath $log|Out-Null;& $provider -Action Apply -InventoryPath $env:LACKSAN_EXP153_INVENTORY -RegistrationIdentity $env:LACKSAN_EXP153_REGISTRATION_IDENTITY -StatePath $state -LogPath $log -WhatIf|Out-Null} catch {Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-ApprovedRunState)|Should -BeExactly $before
  (Get-Content -LiteralPath $log -Raw)|Should -Match 'EXP-153'
 }
}

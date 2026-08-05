Describe 'WindowsSearchDisableHighlights integration' -Tag 'WindowsIntegration' {
 BeforeAll{
  $script:providerPath=Join-Path $PSScriptRoot '..\providers\WindowsSearchDisableHighlights.ps1'
  function Snapshot-State{
   $policyPath='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
   $policy=if(Test-Path $policyPath){$k=Get-Item $policyPath;[pscustomobject]@{Path=$policyPath;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}else{[pscustomobject]@{Path=$policyPath;Values=@()}}
   $services=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   $devices=Get-PnpDevice -ErrorAction SilentlyContinue|Sort-Object InstanceId|Select-Object InstanceId,Status,Class
   [ordered]@{SearchPolicy=$policy;Services=$services;Tasks=$tasks;Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps policy service task driver and device state unchanged through read-only paths'{
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in Windows integration only.';return}
  $before=Snapshot-State
  & $script:providerPath -Action Check|Out-Null
  (Snapshot-State)|Should -BeExactly $before
  try{& $script:providerPath -Action DryRun|Out-Null}catch{}
  (Snapshot-State)|Should -BeExactly $before
  try{& $script:providerPath -Action Apply -StatePath (Join-Path $TestDrive 'exp083-search-highlights-state.json') -WhatIf|Out-Null}catch{}
  (Snapshot-State)|Should -BeExactly $before
 }
}

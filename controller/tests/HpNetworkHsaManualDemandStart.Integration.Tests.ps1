$provider=Join-Path $PSScriptRoot '..\providers\HpNetworkHsaManualDemandStart.ps1'
Describe 'EXP-066 HP Network HSA zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){return}
  $script:enabled=$true
  $script:state=Join-Path $env:TEMP 'lacksan-exp066-integration-state.json'
  $script:log=Join-Path $env:TEMP 'lacksan-exp066-integration.jsonl'
  Remove-Item $script:state,$script:log -Force -ErrorAction SilentlyContinue
  function Snapshot-Network {
   [ordered]@{
    Service=Get-CimInstance Win32_Service -Filter "Name='HPNetworkCap'" -ErrorAction SilentlyContinue|Select-Object Name,State,StartMode,PathName
    Adapters=@(Get-NetAdapter -ErrorAction SilentlyContinue|Sort-Object InterfaceGuid|Select-Object Name,InterfaceDescription,InterfaceGuid,Status,MacAddress,DriverInformation)
    Bindings=@(Get-NetAdapterBinding -ErrorAction SilentlyContinue|Sort-Object Name,ComponentID|Select-Object Name,ComponentID,DisplayName,Enabled)
    Protected=@(Get-Service WinDefend,mpssvc,wuauserv,UsoSvc,BITS,TermService,Tailscale,Dhcp,Dnscache,NlaSvc,netprofm -ErrorAction SilentlyContinue|Sort-Object Name|Select-Object Name,Status,StartType)
   }|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'runs Check without mutation' -Skip:(-not $script:enabled) {
  $before=Snapshot-Network
  & $provider -Action Check -StatePath $script:state -LogPath $script:log|Out-Null
  (Snapshot-Network)|Should -BeExactly $before
 }
 It 'runs DryRun without mutation when supported' -Skip:(-not $script:enabled) {
  $check=& $provider -Action Check -StatePath $script:state -LogPath $script:log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
  $before=Snapshot-Network
  & $provider -Action DryRun -StatePath $script:state -LogPath $script:log|Out-Null
  (Snapshot-Network)|Should -BeExactly $before
 }
 It 'simulates Apply with WhatIf after capture and preserves network state' -Skip:(-not $script:enabled) {
  $check=& $provider -Action Check -StatePath $script:state -LogPath $script:log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
  & $provider -Action Capture -StatePath $script:state -LogPath $script:log|Out-Null
  $before=Snapshot-Network
  & $provider -Action Apply -WhatIf -StatePath $script:state -LogPath $script:log|Out-Null
  (Snapshot-Network)|Should -BeExactly $before
 }
 AfterAll {if($script:enabled){Remove-Item $script:state,$script:log -Force -ErrorAction SilentlyContinue}}
}

Describe 'EXP-066 HP Network HSA zero-mutation Windows integration' -Tag WindowsIntegration {
 BeforeAll{
  $script:provider=Join-Path $PSScriptRoot '..\providers\HPNetworkCapManual.ps1'
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-State{
   $svc=Get-CimInstance Win32_Service|Sort-Object Name|Select-Object Name,State,StartMode,StartName,PathName
   $adapter=Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue|Sort-Object InterfaceGuid,Name|Select-Object Name,InterfaceGuid,InterfaceIndex,Status,MacAddress
   $binding=Get-NetAdapterBinding -AllBindings -ErrorAction SilentlyContinue|Sort-Object InterfaceDescription,ComponentID|Select-Object InterfaceDescription,ComponentID,Enabled
   $ip=Get-NetIPAddress -ErrorAction SilentlyContinue|Sort-Object InterfaceIndex,AddressFamily,IPAddress|Select-Object InterfaceIndex,AddressFamily,IPAddress,PrefixLength
   $route=Get-NetRoute -ErrorAction SilentlyContinue|Sort-Object InterfaceIndex,AddressFamily,DestinationPrefix,NextHop|Select-Object InterfaceIndex,AddressFamily,DestinationPrefix,NextHop,RouteMetric
   $dns=Get-DnsClientServerAddress -ErrorAction SilentlyContinue|Sort-Object InterfaceIndex,AddressFamily|Select-Object InterfaceIndex,AddressFamily,ServerAddresses
   $drivers=Get-CimInstance Win32_SystemDriver|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   [ordered]@{Services=$svc;Adapters=$adapter;Bindings=$binding;IP=$ip;Routes=$route;Dns=$dns;Drivers=$drivers}|ConvertTo-Json -Compress -Depth 14
  }
 }
 It 'keeps service network and driver state unchanged through Check and DryRun' -Skip:(-not$script:enabled) {
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
  & $script:provider -Action Capture -StatePath $state -LogPath $log|Out-Null;$captured=Get-Content $state -Raw
  $result=& $script:provider -Action Apply -StatePath $state -LogPath $log -WhatIf
  $result.WhatIf|Should -BeTrue;(Get-Content $state -Raw)|Should -BeExactly $captured;(Snapshot-State)|Should -BeExactly $before
 }
 It 'limits production mutation primitives to service startup configuration and exact running-state restoration' {
  $text=Get-Content -LiteralPath $script:provider -Raw
  $text|Should -Match 'sc\.exe config';$text|Should -Match 'Start-Service';$text|Should -Match 'Stop-Service'
  $text|Should -Not -Match 'Set-Net|New-Net|Remove-Net|Disable-Net|Enable-Net|Remove-AppxPackage|Disable-PnpDevice|Remove-PnpDevice|pnputil|Set-MpPreference|Set-NetFirewall'
 }
}

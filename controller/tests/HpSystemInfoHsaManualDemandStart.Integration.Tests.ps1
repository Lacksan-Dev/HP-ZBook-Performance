$provider=Join-Path $PSScriptRoot '..\providers\HpSystemInfoHsaManualDemandStart.ps1'
Describe 'EXP-065 HP System Info HSA zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){return}
  $script:enabled=$true
  $script:state=Join-Path $env:TEMP 'lacksan-exp065-integration-state.json'
  $script:log=Join-Path $env:TEMP 'lacksan-exp065-integration.jsonl'
  Remove-Item $script:state,$script:log -Force -ErrorAction SilentlyContinue
 }
 It 'runs Check without mutation' -Skip:(-not $script:enabled) {
  $before=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'" -ErrorAction SilentlyContinue
  & $provider -Action Check -StatePath $script:state -LogPath $script:log | Out-Null
  $after=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'" -ErrorAction SilentlyContinue
  if($before-and$after){$after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State}
 }
 It 'runs DryRun without mutation when supported' -Skip:(-not $script:enabled) {
  $check=& $provider -Action Check -StatePath $script:state -LogPath $script:log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
  $before=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'"
  & $provider -Action DryRun -StatePath $script:state -LogPath $script:log | Out-Null
  $after=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'"
  $after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State
 }
 It 'captures protected configuration and runtime separately then simulates Apply with WhatIf' -Skip:(-not $script:enabled) {
  $check=& $provider -Action Check -StatePath $script:state -LogPath $script:log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
  & $provider -Action Capture -StatePath $script:state -LogPath $script:log | Out-Null
  $captured=Get-Content -LiteralPath $script:state -Raw|ConvertFrom-Json
  @($captured.protected.Configuration).Count|Should -BeGreaterThan 0
  @($captured.protected.Runtime).Count|Should -BeGreaterThan 0
  foreach($row in @($captured.protected.Configuration)){$row.PSObject.Properties.Name|Should -Contain 'Name';$row.PSObject.Properties.Name|Should -Contain 'StartMode';$row.PSObject.Properties.Name|Should -Contain 'PathName';$row.PSObject.Properties.Name|Should -Not -Contain 'State'}
  foreach($row in @($captured.protected.Runtime)){$row.PSObject.Properties.Name|Should -Contain 'Name';$row.PSObject.Properties.Name|Should -Contain 'State';$row.PSObject.Properties.Name|Should -Not -Contain 'StartMode'}
  $before=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'"
  & $provider -Action Apply -WhatIf -StatePath $script:state -LogPath $script:log | Out-Null
  $after=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'"
  $after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State
 }
 AfterAll {if($script:enabled){Remove-Item $script:state,$script:log -Force -ErrorAction SilentlyContinue}}
}

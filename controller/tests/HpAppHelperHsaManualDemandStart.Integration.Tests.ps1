$provider=Join-Path $PSScriptRoot '..\providers\HpAppHelperHsaManualDemandStart.ps1'
Describe 'EXP-063 HP App Helper HSA zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){return}
  $script:enabled=$true
  $script:state=Join-Path $env:TEMP 'lacksan-exp063-integration-state.json'
  $script:log=Join-Path $env:TEMP 'lacksan-exp063-integration.jsonl'
  Remove-Item $script:state,$script:log -Force -ErrorAction SilentlyContinue
 }
 It 'runs Check without mutation' -Skip:(-not $script:enabled) {
  $before=Get-CimInstance Win32_Service -Filter "Name='HPAppHelperCap'" -ErrorAction SilentlyContinue
  & $provider -Action Check -StatePath $script:state -LogPath $script:log | Out-Null
  $after=Get-CimInstance Win32_Service -Filter "Name='HPAppHelperCap'" -ErrorAction SilentlyContinue
  if($before-and$after){$after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State}
 }
 It 'runs DryRun without mutation when supported' -Skip:(-not $script:enabled) {
  $check=& $provider -Action Check -StatePath $script:state -LogPath $script:log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
  $before=Get-CimInstance Win32_Service -Filter "Name='HPAppHelperCap'"
  & $provider -Action DryRun -StatePath $script:state -LogPath $script:log | Out-Null
  $after=Get-CimInstance Win32_Service -Filter "Name='HPAppHelperCap'"
  $after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State
 }
 It 'simulates Apply with WhatIf after capture and leaves service unchanged' -Skip:(-not $script:enabled) {
  $check=& $provider -Action Check -StatePath $script:state -LogPath $script:log
  if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
  & $provider -Action Capture -StatePath $script:state -LogPath $script:log | Out-Null
  $before=Get-CimInstance Win32_Service -Filter "Name='HPAppHelperCap'"
  & $provider -Action Apply -WhatIf -StatePath $script:state -LogPath $script:log | Out-Null
  $after=Get-CimInstance Win32_Service -Filter "Name='HPAppHelperCap'"
  $after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State
 }
 AfterAll {if($script:enabled){Remove-Item $script:state,$script:log -Force -ErrorAction SilentlyContinue}}
}

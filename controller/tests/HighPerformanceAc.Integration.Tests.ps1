$provider=Join-Path $PSScriptRoot '..\providers\HighPerformanceAc.ps1'
Describe 'HighPerformanceAc integration' -Tag 'WindowsIntegration' {
 It 'keeps active scheme and scheme inventory unchanged during Check and Apply WhatIf' -Skip:(-not $env:LACKSAN_RUN_WINDOWS_INTEGRATION) {
  $before=(& powercfg.exe /list 2>&1|Out-String)
  & $provider -Action Check|Out-Null
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  try{& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{}
  $after=(& powercfg.exe /list 2>&1|Out-String)
  $after|Should -BeExactly $before
 }
}

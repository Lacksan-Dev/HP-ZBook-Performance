Describe 'EXP-086 HighPerformancePowerScheme integration' {
 It 'runs Check and DryRun only when explicitly enabled' -Skip:($env:LACKSAN_EXP086_INTEGRATION -ne '1') {
  $p=Join-Path $PSScriptRoot '..\providers\HighPerformancePowerScheme.ps1'
  & $p -Action Check -StatePath "$env:TEMP\exp086-state.json" -LogPath "$env:TEMP\exp086-log.jsonl" | Out-Null
  & $p -Action DryRun -StatePath "$env:TEMP\exp086-state.json" -LogPath "$env:TEMP\exp086-log.jsonl" | Out-Null
 }
}

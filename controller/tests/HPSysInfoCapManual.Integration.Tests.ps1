Describe 'EXP-065 HP System Info HSA zero-mutation integration' -Tag 'Integration' {
 BeforeAll{$script:provider=Join-Path $PSScriptRoot '..\providers\HPSysInfoCapManual.ps1'}
 It 'supports Check without mutating service state' -Skip:($env:LACKSAN_EXP065_INTEGRATION -ne '1') {
  $before=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'" -ErrorAction SilentlyContinue
  & $script:provider -Action Check -LogPath '' | Out-Null
  $after=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'" -ErrorAction SilentlyContinue
  if($before -and $after){$after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State}
 }
 It 'supports DryRun without changing startup state' -Skip:($env:LACKSAN_EXP065_INTEGRATION -ne '1') {
  $before=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'" -ErrorAction SilentlyContinue
  try{& $script:provider -Action DryRun -LogPath '' | Out-Null}catch{}
  $after=Get-CimInstance Win32_Service -Filter "Name='HPSysInfoCap'" -ErrorAction SilentlyContinue
  if($before -and $after){$after.StartMode|Should -Be $before.StartMode;$after.State|Should -Be $before.State}
 }
}
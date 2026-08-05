$provider=Join-Path $PSScriptRoot '..\providers\OneDriveRunStartupRemoval.ps1'
Describe 'EXP-092 Windows integration' -Tag 'Integration' {
 It 'runs Check without mutation when explicitly enabled' -Skip:($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1') {
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  { & $provider -Action Check -StatePath $state -LogPath $log | Out-Null } | Should -Not -Throw
  Test-Path -LiteralPath $state | Should -BeFalse
  Test-Path -LiteralPath $log | Should -BeTrue
 }
 It 'keeps DryRun mutation-free when a supported fixture exists' -Skip:($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1'-or$env:LACKSAN_EXP092_SUPPORTED_FIXTURE-ne'1') {
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  $before=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction Stop).OneDrive
  $result=& $provider -Action DryRun -StatePath $state -LogPath $log
  $after=(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction Stop).OneDrive
  $result.WouldChange | Should -BeTrue
  $result.MutationCount | Should -Be 1
  $after | Should -BeExactly $before
  Test-Path -LiteralPath $state | Should -BeFalse
 }
}

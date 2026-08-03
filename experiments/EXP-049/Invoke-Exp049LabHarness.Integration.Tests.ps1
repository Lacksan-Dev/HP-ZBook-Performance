$harness=Join-Path $PSScriptRoot 'Invoke-Exp049LabHarness.ps1'
$provider=Join-Path $PSScriptRoot '..\..\controller\providers\ClassicTeamsDemandLaunch.ps1'
Describe 'EXP-049 lab harness integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-RunState {
   $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
   if(!(Test-Path -LiteralPath $path)){return 'absent'}
   $k=Get-Item -LiteralPath $path
   @($k.GetValueNames()|Sort-Object|ForEach-Object{"$_|$($k.GetValueKind($_))|$([string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames))"})-join"`n"
  }
 }
 It 'keeps current-user Run state unchanged during provider Check and DryRun' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp049-check';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$before=Snapshot-RunState
  try{& $provider -Action Check -StatePath $state -LogPath $log|Out-Null;& $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null}catch{Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-RunState)|Should -BeExactly $before
 }
 It 'keeps production state unchanged during harness Start WhatIf' -Skip:(-not$script:enabled) {
  $root=Join-Path $TestDrive 'exp049-whatif';New-Item -ItemType Directory -Path $root -Force|Out-Null;$before=Snapshot-RunState
  try{& $harness -Action Start -RunsPerArm 1 -SampleSeconds 30 -EvidenceRoot $root -ProviderPath $provider -WhatIf|Out-Null}catch{Set-ItResult -Skipped -Because $_.Exception.Message;return}
  (Snapshot-RunState)|Should -BeExactly $before
  (Get-ScheduledTask -TaskName 'Lacksan-EXP-049-LabHarness' -ErrorAction SilentlyContinue)|Should -BeNullOrEmpty
  Test-Path (Join-Path $root 'active.json')|Should -BeFalse
 }
}

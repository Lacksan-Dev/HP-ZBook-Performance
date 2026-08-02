$harness=Join-Path $PSScriptRoot 'Invoke-Exp050LabHarness.ps1'
$provider=Join-Path $PSScriptRoot '..\..\controller\providers\LogiOptionsPlusDemandLaunch.ps1'
Describe 'EXP-050 lab harness integration' -Tag 'WindowsIntegration' {
 It 'keeps production Run state unchanged during provider Check' -Skip:($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT') {
  $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  $before=if(Test-Path $path){$k=Get-Item $path;@($k.GetValueNames()|Sort-Object|%{"$_|$($k.GetValueKind($_))|$([string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames))"})-join"`n"}else{'absent'}
  try{& $provider -Action Check|Out-Null}catch{}
  $after=if(Test-Path $path){$k=Get-Item $path;@($k.GetValueNames()|Sort-Object|%{"$_|$($k.GetValueKind($_))|$([string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames))"})-join"`n"}else{'absent'}
  $after|Should -BeExactly $before
 }
 It 'exposes WhatIf start without creating continuation state' -Skip:($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT') {
  $root=Join-Path $TestDrive 'exp050';New-Item -ItemType Directory -Path $root -Force|Out-Null
  try{& $harness -Action Start -RunsPerArm 1 -SampleSeconds 30 -EvidenceRoot $root -ProviderPath $provider -WhatIf|Out-Null}catch{}
  (Get-ScheduledTask -TaskName 'Lacksan-EXP-050-LabHarness' -ErrorAction SilentlyContinue)|Should -BeNullOrEmpty
  Test-Path (Join-Path $root 'active.json')|Should -BeFalse
 }
}

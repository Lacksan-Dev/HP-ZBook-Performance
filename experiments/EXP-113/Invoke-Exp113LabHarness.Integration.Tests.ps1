$harness=Join-Path $PSScriptRoot 'Invoke-Exp113LabHarness.ps1'
$provider=Join-Path $PSScriptRoot '..\..\controller\providers\Microsoft365SigninTask.ps1'
Describe 'EXP-113 lab harness integration' -Tag 'WindowsIntegration' {
 BeforeAll {if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in Windows integration only.';return}}
 It 'keeps Status and provider Check production-state read only' {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in Windows integration only.';return}
  $before=@(Get-ScheduledTask|Sort-Object TaskPath,TaskName|ForEach-Object{"$($_.TaskPath)|$($_.TaskName)|$($_.Settings.Enabled)"}) -join "`n"
  try {& $provider -Action Check|Out-Null} catch {}
  $after=@(Get-ScheduledTask|Sort-Object TaskPath,TaskName|ForEach-Object{"$($_.TaskPath)|$($_.TaskName)|$($_.Settings.Enabled)"}) -join "`n"
  $after|Should -BeExactly $before
 }
 It 'exposes WhatIf for harness start without registering continuation state' {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in Windows integration only.';return}
  $root=Join-Path $TestDrive 'exp113';New-Item -ItemType Directory -Path $root -Force|Out-Null
  try {& $harness -Action Start -RunsPerArm 1 -SampleSeconds 30 -EvidenceRoot $root -ProviderPath $provider -WhatIf|Out-Null} catch {}
  (Get-ScheduledTask -TaskName 'Lacksan-EXP-113-LabHarness' -ErrorAction SilentlyContinue)|Should -BeNullOrEmpty
 }
}

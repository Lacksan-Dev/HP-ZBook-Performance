Describe 'EXP-156 lab harness Windows integration' -Tag 'Integration' {
 BeforeAll {
  $script:sut=Join-Path $PSScriptRoot 'Invoke-Exp156LabHarness.ps1'
  $script:enabled=($IsWindows -and $env:LACKSAN_EXP156_HARNESS_INTEGRATION -eq '1')
 }
 It 'reports inactive state without creating evidence or scheduled continuation' -Skip:(-not $script:enabled) {
  $root=Join-Path $TestDrive 'exp156-integration'
  $provider=Join-Path $TestDrive 'provider-placeholder.ps1'
  Set-Content -LiteralPath $provider -Value '# zero-mutation placeholder' -Encoding UTF8
  $beforeTask=Get-ScheduledTask -TaskName 'Lacksan-EXP-156-LabHarness' -ErrorAction SilentlyContinue
  $result=& $script:sut -Action Status -EvidenceRoot $root -ProviderPath $provider
  $afterTask=Get-ScheduledTask -TaskName 'Lacksan-EXP-156-LabHarness' -ErrorAction SilentlyContinue
  $result.active|Should -BeFalse
  (Test-Path -LiteralPath $root)|Should -BeFalse
  [bool]$afterTask|Should -Be ([bool]$beforeTask)
 }
}

$provider=Join-Path $PSScriptRoot '..\providers\HpSupportSolutionsFrameworkManualDemandStart.ps1'
Describe 'EXP-087 zero-mutation Windows integration' -Tag 'Integration' {
 BeforeAll {
  $enabled=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1' -and $IsWindows
 }
 It 'keeps service startup state unchanged during Check and DryRun' -Skip:(-not $enabled) {
  $before=@(Get-CimInstance Win32_Service | Select-Object Name,StartMode,State | Sort-Object Name | ConvertTo-Json -Compress -Depth 5)
  & $provider -Action Check -StatePath "$TestDrive\state.json" -LogPath "$TestDrive\check.jsonl" | Out-Null
  $checkExit=$LASTEXITCODE
  & $provider -Action DryRun -StatePath "$TestDrive\state.json" -LogPath "$TestDrive\dryrun.jsonl" | Out-Null
  $after=@(Get-CimInstance Win32_Service | Select-Object Name,StartMode,State | Sort-Object Name | ConvertTo-Json -Compress -Depth 5)
  $after | Should -Be $before
  $checkExit | Should -BeIn 0,$null
 }
 It 'contains no broad destructive integration operation' {
  $text=Get-Content $provider -Raw
  $text | Should -Not -Match 'Remove-Service|sc\.exe\s+delete|Remove-AppxPackage|pnputil|Disable-PnpDevice|Remove-ScheduledTask|Disable-ScheduledTask|Stop-Process'
 }
}

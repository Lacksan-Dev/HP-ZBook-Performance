$provider=Join-Path $PSScriptRoot '..\providers\HpDiagnosticsHsaManualDemandStart.ps1'
Describe 'EXP-067 zero-mutation Windows integration' -Tag 'WindowsIntegration' {
 BeforeAll {$enabled=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1' -and $env:OS -eq 'Windows_NT'}
 It 'keeps service startup and protected service state unchanged during Check and DryRun' -Skip:(-not $enabled) {
  $before=@(Get-CimInstance Win32_Service | Select-Object Name,StartMode,State | Sort-Object Name | ConvertTo-Json -Compress -Depth 5)
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  $support=& $provider -Action Check -StatePath $state -LogPath $log
  if($support.Supported){& $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null}
  $after=@(Get-CimInstance Win32_Service | Select-Object Name,StartMode,State | Sort-Object Name | ConvertTo-Json -Compress -Depth 5)
  $after | Should -BeExactly $before
 }
 It 'contains no broad destructive operation' {
  $text=Get-Content -LiteralPath $provider -Raw
  $text | Should -Not -Match 'Remove-Service|sc\.exe\s+delete|Remove-AppxPackage|pnputil|Disable-PnpDevice|Remove-ScheduledTask|Disable-ScheduledTask|Stop-Process|Set-MpPreference|Set-NetFirewall'
 }
}

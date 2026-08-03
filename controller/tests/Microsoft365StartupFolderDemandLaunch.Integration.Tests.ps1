$Provider=Join-Path $PSScriptRoot '..\providers\Microsoft365StartupFolderDemandLaunch.ps1'
Describe 'EXP-058 Windows zero-mutation integration' -Tag 'Integration' {
 It 'Check and DryRun leave Startup-folder and protected service state unchanged' {
  if($env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Windows integration only';return}
  if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1'){Set-ItResult -Skipped -Because 'Set LACKSAN_RUN_WINDOWS_INTEGRATION=1 to opt in';return}
  $root=[Environment]::GetFolderPath('Startup')
  $beforeFiles=@(Get-ChildItem -LiteralPath $root -File -Force -ErrorAction SilentlyContinue|ForEach-Object{[pscustomobject]@{Path=$_.FullName;Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}}|Sort-Object Path)|ConvertTo-Json -Compress
  $serviceNames=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')
  $beforeServices=@($serviceNames|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName)|ConvertTo-Json -Compress
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  & $Provider -Action Check -StatePath $state -LogPath $log | Out-Null
  try { & $Provider -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { $_.Exception.Message | Should -Not -BeNullOrEmpty }
  $afterFiles=@(Get-ChildItem -LiteralPath $root -File -Force -ErrorAction SilentlyContinue|ForEach-Object{[pscustomobject]@{Path=$_.FullName;Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}}|Sort-Object Path)|ConvertTo-Json -Compress
  $afterServices=@($serviceNames|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName)|ConvertTo-Json -Compress
  $afterFiles | Should -BeExactly $beforeFiles
  $afterServices | Should -BeExactly $beforeServices
  Test-Path -LiteralPath $state | Should -BeFalse
 }
}

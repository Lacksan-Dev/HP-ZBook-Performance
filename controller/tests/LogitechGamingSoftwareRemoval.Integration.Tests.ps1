$provider=Join-Path $PSScriptRoot '..\providers\LogitechGamingSoftwareRemoval.ps1'
Describe 'EXP-085 Logitech Gaming Software zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  if($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'){return}
  function Snapshot {
   [pscustomobject]@{
    Products=@(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue|Where-Object{$_.DisplayName -match 'Logitech Gaming Software'}|Select-Object DisplayName,DisplayVersion,Publisher,PSChildName)
    Protected=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName)
   }
  }
 }
 It 'Check is mutation free when explicitly enabled' -Skip:($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT') {
  $before=Snapshot|ConvertTo-Json -Compress -Depth 12
  & $provider -Action Check -OfflineInstaller $env:LACKSAN_EXP085_INSTALLER | Out-Null
  $after=Snapshot|ConvertTo-Json -Compress -Depth 12
  $after|Should -Be $before
 }
 It 'DryRun and Apply WhatIf are mutation free when rollback media is configured' -Skip:($env:RUN_LACKSAN_WINDOWS_INTEGRATION-ne'1'-or$env:OS-ne'Windows_NT'-or[string]::IsNullOrWhiteSpace($env:LACKSAN_EXP085_INSTALLER)) {
  $root=Join-Path $env:TEMP ('Lacksan-EXP085-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $root|Out-Null
  try {
   $state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$before=Snapshot|ConvertTo-Json -Compress -Depth 12
   & $provider -Action DryRun -OfflineInstaller $env:LACKSAN_EXP085_INSTALLER -StatePath $state -LogPath $log | Out-Null
   & $provider -Action Capture -OfflineInstaller $env:LACKSAN_EXP085_INSTALLER -StatePath $state -LogPath $log | Out-Null
   & $provider -Action Apply -OfflineInstaller $env:LACKSAN_EXP085_INSTALLER -StatePath $state -LogPath $log -WhatIf | Out-Null
   $after=Snapshot|ConvertTo-Json -Compress -Depth 12;$after|Should -Be $before
  } finally {Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue}
 }
}
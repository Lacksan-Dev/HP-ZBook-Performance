Describe 'EXP-160 zero-mutation Windows integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:providerPath=Join-Path $PSScriptRoot '..\providers\InventoryBoundStartupFolderRemoval.ps1'
  $script:enabled=($env:LACKSAN_RUN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-Startup {
   $rows=@();foreach($root in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}|Select-Object -Unique){if(Test-Path $root){$rows+=@(Get-ChildItem $root -File -Force -ErrorAction SilentlyContinue|Sort-Object FullName|ForEach-Object{[pscustomobject]@{Path=$_.FullName;Length=$_.Length;Sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash;Attributes=[int]$_.Attributes;LastWriteTimeUtc=$_.LastWriteTimeUtc.ToString('o')}})}};@($rows|Sort-Object Path)|ConvertTo-Json -Compress -Depth 6
  }
  function Snapshot-Protected {
   Get-CimInstance Win32_Service -ErrorAction SilentlyContinue|Where-Object{$_.Name-in@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')}|Sort-Object Name|Select-Object Name,StartMode,PathName|ConvertTo-Json -Compress -Depth 5
  }
 }
 It 'Check and DryRun preserve Startup folders and protected services' -Skip:(-not$script:enabled) {
  $selection=$env:LACKSAN_EXP160_SELECTION;if([string]::IsNullOrWhiteSpace($selection)-or!(Test-Path $selection)){Set-ItResult -Skipped -Because 'Set LACKSAN_EXP160_SELECTION to a real EXP-143 selection artifact.';return}
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl';$beforeStartup=Snapshot-Startup;$beforeProtected=Snapshot-Protected
  $check=& $script:providerPath -Action Check -SelectionPath $selection -StatePath $state -LogPath $log
  if($check.Supported){& $script:providerPath -Action DryRun -SelectionPath $selection -StatePath $state -LogPath $log|Out-Null}
  (Snapshot-Startup)|Should -BeExactly $beforeStartup;(Snapshot-Protected)|Should -BeExactly $beforeProtected;Test-Path $state|Should -BeFalse
 }
 It 'Capture and Apply WhatIf preserve production state when eligible' -Skip:(-not$script:enabled) {
  $selection=$env:LACKSAN_EXP160_SELECTION;if([string]::IsNullOrWhiteSpace($selection)-or!(Test-Path $selection)){Set-ItResult -Skipped -Because 'Set LACKSAN_EXP160_SELECTION to a real EXP-143 selection artifact.';return}
  $state=Join-Path $TestDrive 'whatif-state.json';$log=Join-Path $TestDrive 'whatif-events.jsonl';$beforeStartup=Snapshot-Startup;$beforeProtected=Snapshot-Protected
  $check=& $script:providerPath -Action Check -SelectionPath $selection -StatePath $state -LogPath $log;if(!$check.Supported){Set-ItResult -Skipped -Because ($check.Reasons-join'; ');return}
  & $script:providerPath -Action Capture -SelectionPath $selection -StatePath $state -LogPath $log|Out-Null;& $script:providerPath -Action Apply -SelectionPath $selection -StatePath $state -LogPath $log -WhatIf|Out-Null
  (Snapshot-Startup)|Should -BeExactly $beforeStartup;(Snapshot-Protected)|Should -BeExactly $beforeProtected
 }
 It 'contains no broad destructive operation and no EXP-155 identity' {
  $text=Get-Content -LiteralPath $script:providerPath -Raw;$text|Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|Set-Service|Stop-Service|Remove-Service|Disable-PnpDevice|pnputil|Disable-ScheduledTask|Unregister-ScheduledTask|Set-MpPreference|Set-NetFirewall';$text|Should -Not -Match 'EXP-155';$text|Should -Match 'EXP-160'
 }
}

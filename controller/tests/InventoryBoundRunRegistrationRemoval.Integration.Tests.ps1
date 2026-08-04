Describe 'EXP-153 inventory-bound Run/RunOnce zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:provider=Join-Path $PSScriptRoot '..\providers\InventoryBoundRunRegistrationRemoval.ps1'
  function Snapshot-Run {
   $rows=@();foreach($hive in 'HKCU','HKLM'){foreach($view in 'Registry32','Registry64'){foreach($path in 'Software\Microsoft\Windows\CurrentVersion\Run','Software\Microsoft\Windows\CurrentVersion\RunOnce'){
    $h=if($hive-eq'HKCU'){[Microsoft.Win32.RegistryHive]::CurrentUser}else{[Microsoft.Win32.RegistryHive]::LocalMachine};$v=[Enum]::Parse([Microsoft.Win32.RegistryView],$view);$b=[Microsoft.Win32.RegistryKey]::OpenBaseKey($h,$v);try{$k=$b.OpenSubKey($path,$false);if(!$k){$rows+=[pscustomobject]@{Hive=$hive;View=$view;Path=$path;Absent=$true};continue};try{$rows+=[pscustomobject]@{Hive=$hive;View=$view;Path=$path;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}finally{$k.Dispose()}}finally{$b.Dispose()}
   }}};$rows|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps Run and RunOnce state unchanged for unsupported selection and Apply WhatIf' -Skip:($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT') {
  $selection=Join-Path $TestDrive 'selection.json';$state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  [ordered]@{experiment='EXP-143';classification='priority-target';surface='RegistryRun';inventoryHash='integration-placeholder';hive='HKCU';registryView='Registry64';path='Software\Microsoft\Windows\CurrentVersion\Run';valueName='LacksanDefinitelyAbsent';originalState=@{kind='String';data='C:\DefinitelyAbsent\Lacksan.exe'}}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $selection -Encoding UTF8
  $before=Snapshot-Run
  & $provider -Action Check -SelectionPath $selection -StatePath $state -LogPath $log|Out-Null
  try{& $provider -Action DryRun -SelectionPath $selection -StatePath $state -LogPath $log|Out-Null}catch{}
  try{& $provider -Action Apply -SelectionPath $selection -StatePath $state -LogPath $log -WhatIf|Out-Null}catch{}
  (Snapshot-Run)|Should -BeExactly $before
  (Get-Content -LiteralPath $log -Raw)|Should -Match 'support-detection'
 }
}

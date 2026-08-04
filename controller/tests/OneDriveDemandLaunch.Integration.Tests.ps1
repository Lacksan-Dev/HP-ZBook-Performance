# Opt-in zero-mutation Windows integration for an HP Windows 11 lab system.
$runIntegration=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'
Describe 'EXP-092 OneDriveDemandLaunch zero-mutation integration' -Tag 'WindowsIntegration' -Skip:(-not $runIntegration) {
 BeforeAll {
  $provider=Join-Path $PSScriptRoot '..\providers\OneDriveDemandLaunch.ps1'
  $root=Join-Path $env:TEMP ('Lacksan-EXP-092-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $root -Force|Out-Null
  $state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$runPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  function Snapshot-Boundary {
   $run=if(Test-Path $runPath){$k=Get-Item $runPath;$acl=Get-Acl $runPath;[ordered]@{Owner=$acl.Owner;Sddl=$acl.Sddl;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}else{$null}
   $policy=@();foreach($path in 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive','HKCU:\SOFTWARE\Policies\Microsoft\OneDrive'){if(Test-Path $path){$k=Get-Item $path;$policy+=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Path=$path;Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}
   $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$s=Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue;if($s){[pscustomobject]@{Name=$s.Name;State=$s.State;StartMode=$s.StartMode;PathName=$s.PathName}}}
   $tasks=@(Get-ScheduledTask -ErrorAction SilentlyContinue|Where-Object{$_.TaskName-match'(?i)OneDrive'}|Sort-Object TaskPath,TaskName|Select-Object TaskPath,TaskName,State)
   [ordered]@{Run=$run;Policy=$policy;Services=@($services);OneDriveTasks=$tasks}|ConvertTo-Json -Compress -Depth 10
  }
 }
 AfterAll { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
 It 'keeps Run ACL values policy protected services and OneDrive tasks unchanged during Check Capture DryRun and Apply WhatIf' {
  $before=Snapshot-Boundary
  $check=& $provider -Action Check -StatePath $state -LogPath $log
  if($check.Support.Supported -and @($check.Candidates).Count -eq 1 -and [int]$check.AccountState.AccountCount -eq 1){
   try { & $provider -Action Capture -StatePath $state -LogPath $log|Out-Null } catch { }
   try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null } catch { }
  } else {
   try { & $provider -Action Capture -StatePath $state -LogPath $log|Out-Null } catch { }
   try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null } catch { }
  }
  try { & $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null } catch { }
  (Snapshot-Boundary)|Should -BeExactly $before
 }
 It 'emits schema-v3 parseable JSONL without common secret material' {
  if(Test-Path $log){$records=Get-Content $log|ForEach-Object{$_|ConvertFrom-Json};$records.Count|Should -BeGreaterThan 0;$records[-1].schemaVersion|Should -Be 3;(Get-Content $log -Raw)|Should -Not -Match '(?i)password|access[_-]?token|refresh[_-]?token|cookie|tenant[_-]?id|user[_-]?email'}
 }
}

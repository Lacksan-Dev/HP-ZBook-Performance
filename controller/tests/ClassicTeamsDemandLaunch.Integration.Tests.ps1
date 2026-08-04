# Opt-in Windows integration contract for an HP Windows 11 lab system.
$runIntegration = $env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'
Describe 'EXP-049 ClassicTeamsDemandLaunch zero-mutation integration' -Tag 'WindowsIntegration' -Skip:(-not $runIntegration) {
 BeforeAll {
  $provider=Join-Path $PSScriptRoot '..\providers\ClassicTeamsDemandLaunch.ps1'
  $root=Join-Path $env:TEMP ('Lacksan-EXP-049-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $root -Force|Out-Null
  $state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl';$runPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  function Snapshot-Run { if(!(Test-Path $runPath)){return '<missing>'};$k=Get-Item $runPath;$acl=Get-Acl $runPath;[ordered]@{Owner=$acl.Owner;Sddl=$acl.Sddl;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}|ConvertTo-Json -Compress -Depth 6 }
  function Snapshot-Protected { $s=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$x=Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue;if($x){[pscustomobject]@{Name=$x.Name;State=$x.State;StartMode=$x.StartMode;PathName=$x.PathName}}};$teams=@(Get-AppxPackage -Name MSTeams -ErrorAction SilentlyContinue|Sort-Object PackageFullName|Select-Object Name,PackageFullName,Version,Status);[ordered]@{Services=@($s);NewTeams=$teams}|ConvertTo-Json -Compress -Depth 8 }
 }
 AfterAll { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
 It 'keeps Run ACL values and protected state unchanged during Check Capture DryRun and Apply WhatIf' {
  $beforeRun=Snapshot-Run;$beforeProtected=Snapshot-Protected
  $check=& $provider -Action Check -StatePath $state -LogPath $log
  if($check.Support.Supported -and @($check.Candidates).Count -eq 1){
   & $provider -Action Capture -StatePath $state -LogPath $log|Out-Null
   & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null
  } else {
   try { & $provider -Action Capture -StatePath $state -LogPath $log|Out-Null } catch { }
   try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null } catch { }
  }
  try { & $provider -Action DryRun -StatePath $state -LogPath $log|Out-Null } catch { }
  (Snapshot-Run)|Should -BeExactly $beforeRun
  (Snapshot-Protected)|Should -BeExactly $beforeProtected
 }
 It 'emits schema-v3 parseable JSONL without common secret material' {
  if(Test-Path $log){$records=Get-Content $log|ForEach-Object{$_|ConvertFrom-Json};$records.Count|Should -BeGreaterThan 0;$records[-1].schemaVersion|Should -Be 3;(Get-Content $log -Raw)|Should -Not -Match '(?i)password|access[_-]?token|refresh[_-]?token|cookie|mailbox|meeting[_-]?url'}
 }
}

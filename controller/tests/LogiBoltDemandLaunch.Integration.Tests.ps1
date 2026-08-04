Describe 'EXP-051 LogiBoltDemandLaunch zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:providerPath = Join-Path $PSScriptRoot '..\providers\LogiBoltDemandLaunch.ps1'
  $script:enabled = ($env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1' -and $env:OS -eq 'Windows_NT')
  function Snapshot-Run {
   $path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
   if(!(Test-Path $path)){return 'absent'}
   $k=Get-Item $path;$acl=Get-Acl $path
   [ordered]@{Owner=$acl.Owner;Sddl=$acl.Sddl;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}|ConvertTo-Json -Compress -Depth 6
  }
  function Snapshot-Protected {
   $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$x=Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue;if($x){[pscustomobject]@{Name=$x.Name;State=$x.State;StartMode=$x.StartMode;PathName=$x.PathName}}}
   $drivers=@(Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue|Where-Object{$_.Name-match'(?i)logi|logitech'-or$_.PathName-match'(?i)logi|logitech'}|Sort-Object Name|Select-Object Name,State,StartMode,PathName)
   $devices=@(Get-PnpDevice -ErrorAction SilentlyContinue|Where-Object{$_.FriendlyName-match'(?i)logi|logitech'-or$_.Manufacturer-match'(?i)logi|logitech'}|Sort-Object InstanceId|Select-Object InstanceId,Status,Class,FriendlyName)
   [ordered]@{Services=@($services);Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps Run ACL values and protected state unchanged during Check Capture DryRun and Apply WhatIf' -Skip:(-not $script:enabled) {
  $beforeRun=Snapshot-Run;$beforeProtected=Snapshot-Protected
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  $check=& $script:providerPath -Action Check -StatePath $state -LogPath $log
  if($check.Support.Supported -and @($check.Candidates).Count -eq 1){
   & $script:providerPath -Action Capture -StatePath $state -LogPath $log | Out-Null
   & $script:providerPath -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null
  } else {
   try { & $script:providerPath -Action Capture -StatePath $state -LogPath $log | Out-Null } catch { }
   try { & $script:providerPath -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { }
  }
  try { & $script:providerPath -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { }
  (Snapshot-Run)|Should -BeExactly $beforeRun
  (Snapshot-Protected)|Should -BeExactly $beforeProtected
 }
}

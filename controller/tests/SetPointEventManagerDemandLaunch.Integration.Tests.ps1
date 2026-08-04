$provider = Join-Path $PSScriptRoot '..\providers\SetPointEventManagerDemandLaunch.ps1'
Describe 'SetPointEventManagerDemandLaunch integration' -Tag 'WindowsIntegration' {
 function Snapshot-Run {
  $items=@()
  foreach($path in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'){
   if(!(Test-Path -LiteralPath $path)){ $items += [pscustomobject]@{Path=$path;State='absent'}; continue }
   $k=Get-Item -LiteralPath $path
   $acl=Get-Acl -LiteralPath $path
   $items += [pscustomobject]@{Path=$path;State='present';Owner=$acl.Owner;Sddl=$acl.Sddl;Values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}
  }
  $items|ConvertTo-Json -Compress -Depth 8
 }
 function Snapshot-ProtectedConfiguration {
  $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$x=Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue;if($x){[pscustomobject]@{Name=$x.Name;StartMode=$x.StartMode;PathName=$x.PathName}}}
  $drivers=@(Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue|Where-Object{$_.Name-match'(?i)logi|logitech'-or$_.PathName-match'(?i)logi|logitech'}|Sort-Object Name|Select-Object Name,StartMode,PathName)
  $devices=@(Get-PnpDevice -ErrorAction SilentlyContinue|Where-Object{$_.FriendlyName-match'(?i)logi|logitech'-or$_.Manufacturer-match'(?i)logi|logitech'}|Sort-Object InstanceId|Select-Object InstanceId,Class,FriendlyName,Manufacturer)
  [ordered]@{Services=@($services);Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 10
 }
 It 'keeps Run ACL values and protected configuration unchanged during Check DryRun and Apply WhatIf' -Skip:(-not $env:LACKSAN_RUN_WINDOWS_INTEGRATION) {
  $beforeRun=Snapshot-Run;$beforeProtected=Snapshot-ProtectedConfiguration
  $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
  & $provider -Action Check -StatePath $state -LogPath $log | Out-Null
  try { & $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { }
  try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { }
  (Snapshot-Run)|Should -BeExactly $beforeRun
  (Snapshot-ProtectedConfiguration)|Should -BeExactly $beforeProtected
  if(Test-Path -LiteralPath $state){ (Get-Content -LiteralPath $state -Raw) | Should -Match 'needs-evidence' }
  (Get-Content -LiteralPath $log -Raw) | Should -Match 'support-detection'
 }
}

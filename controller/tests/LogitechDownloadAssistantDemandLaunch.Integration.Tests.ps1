Describe 'EXP-080 Logitech Download Assistant zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:provider=Join-Path $PSScriptRoot '..\providers\LogitechDownloadAssistantDemandLaunch.ps1'
  $script:enabled=($env:LACKSAN_RUN_WINDOWS_INTEGRATION-eq'1'-and$env:OS-eq'Windows_NT')
  function Snapshot-Run {
   $rows=@();foreach($path in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'){if(Test-Path -LiteralPath $path){$k=Get-Item -LiteralPath $path;$acl=Get-Acl -LiteralPath $path;$values=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}});$rows+=[pscustomobject]@{Path=$path;Owner=$acl.Owner;Sddl=$acl.Sddl;Values=$values}}else{$rows+=[pscustomobject]@{Path=$path;Absent=$true}}};$rows|ConvertTo-Json -Compress -Depth 8
  }
  function Snapshot-Protected {
   $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'){$s=Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue;if($s){[pscustomobject]@{Name=$s.Name;StartMode=$s.StartMode;PathName=$s.PathName}}}
   $drivers=@(Get-CimInstance Win32_SystemDriver -ErrorAction SilentlyContinue|Where-Object{$_.Name-match'(?i)logi|logitech'-or$_.PathName-match'(?i)logi|logitech'}|Sort-Object Name|Select-Object Name,StartMode,PathName)
   $devices=@(Get-PnpDevice -ErrorAction SilentlyContinue|Where-Object{$_.FriendlyName-match'(?i)logi|logitech'-or$_.Manufacturer-match'(?i)logi|logitech'}|Sort-Object InstanceId|Select-Object InstanceId,Class,FriendlyName,Manufacturer)
   [ordered]@{Services=@($services);Drivers=$drivers;Devices=$devices}|ConvertTo-Json -Compress -Depth 10
  }
 }
 It 'keeps Run ACL values and protected configuration unchanged during read-only lifecycle and Apply WhatIf' -Skip:(-not$script:enabled) {
  $beforeRun=Snapshot-Run;$beforeProtected=Snapshot-Protected;$root=Join-Path $TestDrive 'exp080';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl'
  $check=& $script:provider -Action Check -StatePath $state -LogPath $log
  try {& $script:provider -Action DryRun -StatePath $state -LogPath $log|Out-Null} catch {}
  if($check.Support -and $check.Support.Supported){$check=$check.Support}
  if($check.Supported -and @($check.Candidates).Count-eq1){& $script:provider -Action Capture -StatePath $state -LogPath $log|Out-Null;& $script:provider -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null}
  (Snapshot-Run)|Should -BeExactly $beforeRun
  (Snapshot-Protected)|Should -BeExactly $beforeProtected
 }
}

$controller=Join-Path $PSScriptRoot 'Invoke-Exp024HpTouchpoint.ps1'
Describe 'EXP-024 controller zero-mutation integration' -Tag 'WindowsIntegration' {
  BeforeAll {
    $script:enabled=($env:RUN_LACKSAN_WINDOWS_INTEGRATION -eq '1' -and $env:OS -eq 'Windows_NT')
    function Snapshot-ProductionState {
      $svc=Get-CimInstance Win32_Service -Filter "Name='HPTouchpointAnalyticsService'" -ErrorAction SilentlyContinue
      $reg=$null
      $key='HKLM:\SYSTEM\CurrentControlSet\Services\HPTouchpointAnalyticsService'
      if(Test-Path $key){$k=Get-Item $key;$reg=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}
      $protected=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale'|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName)
      [ordered]@{Target=if($svc){$svc|Select-Object Name,State,StartMode,StartName,PathName}else{$null};Registry=$reg;Protected=$protected}|ConvertTo-Json -Compress -Depth 12
    }
  }
  It 'keeps Check and explicit DryRun production state unchanged' -Skip:(-not $script:enabled) {
    $root=Join-Path $TestDrive 'exp024';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl'
    $check=& $controller -Action Check -StatePath $state -LogPath $log
    if(-not $check.Supported){Set-ItResult -Skipped -Because 'EXP-024 support gate refused this machine.';return}
    $before=Snapshot-ProductionState
    & $controller -Action DryRun -StatePath $state -LogPath $log|Out-Null
    (Snapshot-ProductionState)|Should -BeExactly $before
  }
  It 'keeps Capture and Apply WhatIf production state unchanged when eligible' -Skip:(-not $script:enabled) {
    $root=Join-Path $TestDrive 'exp024-whatif';New-Item -ItemType Directory -Path $root -Force|Out-Null;$state=Join-Path $root 'state.json';$log=Join-Path $root 'events.jsonl'
    try {$check=& $controller -Action Check -StatePath $state -LogPath $log} catch {Set-ItResult -Skipped -Because $_.Exception.Message;return}
    if($check.StartMode -notin @('Auto','Automatic')){Set-ItResult -Skipped -Because 'Automatic baseline required.';return}
    $before=Snapshot-ProductionState
    & $controller -Action Capture -StatePath $state -LogPath $log|Out-Null
    & $controller -Action Apply -StatePath $state -LogPath $log -WhatIf|Out-Null
    (Snapshot-ProductionState)|Should -BeExactly $before
  }
}

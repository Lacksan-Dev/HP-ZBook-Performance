$runIntegration=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'

Describe 'EXP-067 zero-mutation Windows integration' -Tag 'Integration' {
  It 'runs Check and DryRun without changing HPDiagsCap or protected services' -Skip:(-not $runIntegration) {
    if($env:OS -ne 'Windows_NT'){Set-ItResult -Skipped -Because 'Windows required';return}
    $scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp067HpDiagnostics.ps1'
    $serviceName='HPDiagsCap'
    $svc=Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
    if(-not $svc){Set-ItResult -Skipped -Because 'HPDiagsCap absent';return}
    $protected=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')
    function Snapshot {
      $delayedState=try {
        (Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name DelayedAutoStart -ErrorAction Stop).DelayedAutoStart
      } catch {$null}
      [ordered]@{
        target=(Get-CimInstance Win32_Service -Filter "Name='$serviceName'"|Select-Object Name,StartMode,State,PathName)
        delayed=$delayedState
        protected=@($protected|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Select-Object Name,StartMode,State,PathName|Sort-Object Name)
      }
    }
    $before=Snapshot
    $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
    $check=& $scriptPath -Action Check -StatePath $state -LogPath $log
    if(-not $check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
    $dry=& $scriptPath -Action DryRun -StatePath $state -LogPath $log
    $after=Snapshot
    ($before|ConvertTo-Json -Depth 10 -Compress) | Should -Be ($after|ConvertTo-Json -Depth 10 -Compress)
    $dry.Service | Should -Be $serviceName
    $dry.To | Should -Be 'Manual'
    $dry.PreserveRunningState | Should -BeTrue
    $dry.DelayedAutoStartPreservedExactly | Should -BeTrue
  }
}

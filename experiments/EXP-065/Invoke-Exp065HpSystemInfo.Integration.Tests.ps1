$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp065HpSystemInfo.ps1'
$runIntegration=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'

Describe 'EXP-065 zero-mutation Windows integration' -Tag 'Integration' {
  It 'runs Check and DryRun without changing HPSysInfoCap or protected services' -Skip:(-not $runIntegration) {
    if($env:OS -ne 'Windows_NT'){Set-ItResult -Skipped -Because 'Windows required';return}
    $serviceName='HPSysInfoCap'
    $svc=Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
    if(-not $svc){Set-ItResult -Skipped -Because 'HPSysInfoCap absent';return}
    $protected=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')
    function Snapshot {
      [ordered]@{
        target=(Get-CimInstance Win32_Service -Filter "Name='$serviceName'"|Select-Object Name,StartMode,State,PathName)
        delayed=try{(Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name DelayedAutoStart -ErrorAction Stop).DelayedAutoStart}catch{$null}
        protected=@($protected|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Select-Object Name,StartMode,State,PathName|Sort-Object Name)
      }
    }
    $before=Snapshot
    $check=& $scriptPath -Action Check -StatePath (Join-Path $TestDrive 'state.json') -LogPath (Join-Path $TestDrive 'events.jsonl')
    if(-not $check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
    $dry=& $scriptPath -Action DryRun -StatePath (Join-Path $TestDrive 'state.json') -LogPath (Join-Path $TestDrive 'events.jsonl')
    $after=Snapshot
    ($before|ConvertTo-Json -Depth 10 -Compress) | Should -Be ($after|ConvertTo-Json -Depth 10 -Compress)
    $dry.Service | Should -Be $serviceName
    $dry.To | Should -Be 'Manual'
    $dry.PreserveRunningState | Should -BeTrue
    $dry.DelayedAutoStartPreservedExactly | Should -BeTrue
  }
}

$runIntegration=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'
Describe 'EXP-066 zero-mutation Windows integration' -Tag 'Integration' {
  It 'runs Check and DryRun without changing HPNetworkCap or the network stack' -Skip:(-not $runIntegration) {
    if($env:OS -ne 'Windows_NT'){Set-ItResult -Skipped -Because 'Windows required';return}
    $scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp066HpNetwork.ps1';$serviceName='HPNetworkCap'
    $svc=Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
    if(-not $svc){Set-ItResult -Skipped -Because 'HPNetworkCap absent';return}
    function Snapshot {
      [ordered]@{
        service=(Get-CimInstance Win32_Service -Filter "Name='$serviceName'"|Select-Object Name,StartMode,State,PathName)
        adapters=@(Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue|Select-Object Name,InterfaceDescription,Status,MacAddress,LinkSpeed|Sort-Object Name)
        bindings=@(Get-NetAdapterBinding -AllBindings -ErrorAction SilentlyContinue|Select-Object Name,ComponentID,Enabled|Sort-Object Name,ComponentID)
        protected=@('WinDefend','mpssvc','wuauserv','TermService','Tailscale'|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Select-Object Name,StartMode,State,PathName|Sort-Object Name)
      }
    }
    $before=Snapshot;$state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
    $check=& $scriptPath -Action Check -StatePath $state -LogPath $log
    if(-not $check.Supported){Set-ItResult -Skipped -Because ($check.Reasons -join '; ');return}
    $dry=& $scriptPath -Action DryRun -StatePath $state -LogPath $log;$after=Snapshot
    ($before|ConvertTo-Json -Depth 12 -Compress)|Should -Be ($after|ConvertTo-Json -Depth 12 -Compress)
    $dry.Service|Should -Be $serviceName;$dry.To|Should -Be 'Manual';$dry.NetworkStackPreserved|Should -BeTrue
  }
}

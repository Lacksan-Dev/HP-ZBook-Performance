$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/SearchWebResultsPolicy.ps1'
Describe 'EXP-082 Search web-results zero-mutation integration' -Tag 'WindowsIntegration' {
  It 'runs Check without changing either candidate registry value' -Skip:($env:LACKSAN_RUN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') {
    $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search';$names=@('DisableWebSearch','ConnectedSearchUseWeb')
    function Snapshot { $result=@();foreach($name in $names){if(!(Test-Path $path)){$result+="$name|key-absent";continue};$k=Get-Item $path;if($k.GetValueNames()-notcontains$name){$result+="$name|value-absent";continue};$result+=($name+'|'+$k.GetValueKind($name).ToString()+'|'+[string]$k.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames))};$result -join ';' }
    $before=Snapshot
    & $provider -Action Check -StatePath (Join-Path $TestDrive 'state.json') -LogPath (Join-Path $TestDrive 'log.jsonl') | Out-Null
    $after=Snapshot
    $after | Should -BeExactly $before
  }
}

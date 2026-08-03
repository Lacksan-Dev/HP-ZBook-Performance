$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/SearchHighlightsPolicy.ps1'
Describe 'EXP-083 Search highlights zero-mutation integration' -Tag 'WindowsIntegration' {
  It 'runs Check without changing the candidate registry state' -Skip:($env:LACKSAN_RUN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') {
    $path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search';$name='EnableDynamicContentInWSB'
    function Snapshot { if(!(Test-Path $path)){return 'key-absent'};$k=Get-Item $path;if($k.GetValueNames()-notcontains$name){return 'value-absent'};return ($k.GetValueKind($name).ToString()+'|'+[string]$k.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)) }
    $before=Snapshot
    & $provider -Action Check -StatePath (Join-Path $TestDrive 'state.json') -LogPath (Join-Path $TestDrive 'log.jsonl') | Out-Null
    $after=Snapshot
    $after | Should -BeExactly $before
  }
}

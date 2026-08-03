$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/EdgeNewTabPrerenderPolicy.ps1'
$run=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'
Describe 'EXP-076 zero-mutation Windows integration' -Skip:(-not $run) {
  BeforeAll {
    if($env:OS -ne 'Windows_NT'){ Set-ItResult -Skipped -Because 'Windows required' }
    $script:temp=Join-Path $env:TEMP ('lacksan-exp076-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:temp -Force|Out-Null
    $script:state=Join-Path $script:temp 'state.json'
    $script:log=Join-Path $script:temp 'events.jsonl'
  }
  AfterAll { if($script:temp -and(Test-Path $script:temp)){Remove-Item $script:temp -Recurse -Force} }
  It 'Check performs discovery without creating state' {
    & $provider -Action Check -StatePath $state -LogPath $log | Should -Not -BeNullOrEmpty
    Test-Path $state | Should -BeFalse
  }
  It 'DryRun leaves the candidate policy unchanged when supported' {
    $before=Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended' -Name NewTabPagePrerenderEnabled -ErrorAction SilentlyContinue
    try { & $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { }
    $after=Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended' -Name NewTabPagePrerenderEnabled -ErrorAction SilentlyContinue
    ($before|ConvertTo-Json -Compress) | Should -Be ($after|ConvertTo-Json -Compress)
  }
  It 'Apply WhatIf performs zero policy mutation' {
    $before=Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended' -Name NewTabPagePrerenderEnabled -ErrorAction SilentlyContinue
    if(Test-Path $state){Remove-Item $state -Force}
    try { & $provider -Action Capture -StatePath $state -LogPath $log | Out-Null; & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { }
    $after=Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended' -Name NewTabPagePrerenderEnabled -ErrorAction SilentlyContinue
    ($before|ConvertTo-Json -Compress) | Should -Be ($after|ConvertTo-Json -Compress)
  }
}

$root=Split-Path -Parent $PSScriptRoot
$provider=Join-Path $root 'providers/EdgeNewTabContentPolicy.ps1'
$run=$env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1'
Describe 'EXP-148 zero-mutation Windows integration' -Skip:(-not $run) {
  BeforeAll {
    if($env:OS -ne 'Windows_NT'){ Set-ItResult -Skipped -Because 'Windows required' }
    $script:temp=Join-Path $env:TEMP ('lacksan-exp148-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Path $script:temp -Force|Out-Null
    $script:state=Join-Path $script:temp 'state.json'
    $script:log=Join-Path $script:temp 'events.jsonl'
    $script:policy='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    $script:name='NewTabPageContentEnabled'
  }
  AfterAll { if($script:temp-and(Test-Path $script:temp)){Remove-Item $script:temp -Recurse -Force} }
  It 'Check performs discovery without creating captured state' {
    & $provider -Action Check -StatePath $state -LogPath $log | Should -Not -BeNullOrEmpty
    Test-Path $state | Should -BeFalse
  }
  It 'DryRun preserves the mandatory candidate policy' {
    $before=Get-ItemProperty $policy -Name $name -ErrorAction SilentlyContinue
    try { & $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null } catch { }
    $after=Get-ItemProperty $policy -Name $name -ErrorAction SilentlyContinue
    ($before|ConvertTo-Json -Compress) | Should -Be ($after|ConvertTo-Json -Compress)
  }
  It 'Apply WhatIf preserves the mandatory candidate policy when capture eligibility is supplied' {
    $before=Get-ItemProperty $policy -Name $name -ErrorAction SilentlyContinue
    if(Test-Path $state){Remove-Item $state -Force}
    $edgeUserData=Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
    $profile=Join-Path $edgeUserData 'Default'
    try {
      & $provider -Action Capture -StatePath $state -LogPath $log -TargetProfilePath $profile -ProfileSignInType Local -BaselineContentActive -SelfManagedNtpConfirmed | Out-Null
      & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null
    } catch { }
    $after=Get-ItemProperty $policy -Name $name -ErrorAction SilentlyContinue
    ($before|ConvertTo-Json -Compress) | Should -Be ($after|ConvertTo-Json -Compress)
  }
}

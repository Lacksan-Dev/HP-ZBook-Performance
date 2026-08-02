$provider=Join-Path $PSScriptRoot '..\providers\EdgeSetSleepingTabsTimeout.ps1'
Describe 'EXP-073 Windows zero-mutation integration' -Tag 'Integration' {
    It 'keeps policy, startup, service, task, driver, and device state unchanged during Check, DryRun, and Apply -WhatIf' -Skip:(-not $env:LACKSAN_WINDOWS_INTEGRATION) {
        function Snapshot {
            [ordered]@{
                policy = if(Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'){Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'|ConvertTo-Json -Depth 5 -Compress}else{'absent'}
                recommended = if(Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'){Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'|ConvertTo-Json -Depth 5 -Compress}else{'absent'}
                startup = @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|ForEach-Object{if($_ -and(Test-Path $_)){Get-ChildItem $_ -File|Select-Object FullName,Length,LastWriteTimeUtc}}|ConvertTo-Json -Depth 5 -Compress
                services = Get-Service|Select-Object Name,Status,StartType|Sort-Object Name|ConvertTo-Json -Compress
                tasks = Get-ScheduledTask|Select-Object TaskPath,TaskName,State|Sort-Object TaskPath,TaskName|ConvertTo-Json -Compress
                drivers = Get-CimInstance Win32_SystemDriver|Select-Object Name,State,StartMode,PathName|Sort-Object Name|ConvertTo-Json -Compress
                devices = Get-PnpDevice|Select-Object InstanceId,Status,Class|Sort-Object InstanceId|ConvertTo-Json -Compress
            }|ConvertTo-Json -Depth 3 -Compress
        }
        $before=Snapshot
        & $provider -Action Check | Out-Null
        & $provider -Action DryRun | Out-Null
        & $provider -Action Apply -WhatIf | Out-Null
        $after=Snapshot
        $after | Should -BeExactly $before
    }
}

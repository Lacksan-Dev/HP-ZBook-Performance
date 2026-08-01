$provider = Join-Path $PSScriptRoot '..\providers\OneDriveDemandLaunch.ps1'
Describe 'OneDriveDemandLaunch integration' -Tag 'WindowsIntegration' {
    It 'keeps OneDrive startup, policy, and protected state unchanged during Check, DryRun, and Apply WhatIf' -Skip:(-not $env:LACKSAN_RUN_WINDOWS_INTEGRATION) {
        function Snapshot-OneDriveBoundary {
            $run='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            $runState=if(Test-Path $run){$k=Get-Item $run;@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}else{@()}
            $policy=@();foreach($path in 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive','HKCU:\SOFTWARE\Policies\Microsoft\OneDrive'){if(Test-Path $path){$k=Get-Item $path;$policy+=@($k.GetValueNames()|Sort-Object|ForEach-Object{[pscustomobject]@{Path=$path;Name=$_;Kind=$k.GetValueKind($_).ToString();Data=[string]$k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}})}}
            $services=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){ $s=Get-Service $n -ErrorAction SilentlyContinue;if($s){[pscustomobject]@{Name=$s.Name;Status=$s.Status.ToString();StartType=$s.StartType.ToString()}}}
            [ordered]@{Run=$runState;Policy=$policy;Services=@($services)}|ConvertTo-Json -Compress -Depth 8
        }
        $before=Snapshot-OneDriveBoundary
        & $provider -Action Check | Out-Null
        try { & $provider -Action DryRun | Out-Null } catch { }
        $state=Join-Path $TestDrive 'state.json';$log=Join-Path $TestDrive 'events.jsonl'
        try { & $provider -Action Apply -StatePath $state -LogPath $log -WhatIf | Out-Null } catch { }
        $after=Snapshot-OneDriveBoundary
        $after | Should -BeExactly $before
    }
}

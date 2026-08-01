$provider=Join-Path $PSScriptRoot '..\providers\EdgeMeasuredExtensionBlocklist.ps1'
Describe 'EXP-089 zero-mutation integration' -Tag 'Integration' {
    BeforeAll {
        if($env:LACKSAN_RUN_WINDOWS_INTEGRATION -ne '1'){Set-ItResult -Skipped -Because 'Set LACKSAN_RUN_WINDOWS_INTEGRATION=1 on an HP Windows 11 test machine.'}
        if([string]::IsNullOrWhiteSpace($env:LACKSAN_EDGE_EXTENSION_ID)){Set-ItResult -Skipped -Because 'Set LACKSAN_EDGE_EXTENSION_ID to one measured user-installed Edge extension.'}
        $script:state=Join-Path $TestDrive 'exp089-state.json'
        $script:log=Join-Path $TestDrive 'exp089.jsonl'
        function Snapshot {
            $policy='HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist'
            $values=@()
            if(Test-Path -LiteralPath $policy){$k=Get-Item -LiteralPath $policy;$values=@($k.GetValueNames()|Sort-Object|ForEach-Object{"$_|$($k.GetValueKind($_))|$($k.GetValue($_,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames))"})}
            $protected=foreach($n in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'){if($s=Get-Service $n -ErrorAction SilentlyContinue){"$($s.Name)|$($s.Status)|$($s.StartType)"}}
            [pscustomobject]@{Policy=($values -join "`n");Protected=(@($protected)|Sort-Object)-join "`n"}
        }
    }
    It 'Check performs zero mutation' {
        $before=Snapshot
        & $provider -Action Check -ExtensionId $env:LACKSAN_EDGE_EXTENSION_ID -LogPath $script:log | Out-Null
        $after=Snapshot
        $after.Policy | Should -BeExactly $before.Policy
        $after.Protected | Should -BeExactly $before.Protected
    }
    It 'Capture performs zero mutation' {
        $before=Snapshot
        & $provider -Action Capture -ExtensionId $env:LACKSAN_EDGE_EXTENSION_ID -StatePath $script:state -LogPath $script:log | Out-Null
        $after=Snapshot
        $after.Policy | Should -BeExactly $before.Policy
        $after.Protected | Should -BeExactly $before.Protected
    }
    It 'DryRun performs zero mutation' {
        $before=Snapshot
        & $provider -Action DryRun -ExtensionId $env:LACKSAN_EDGE_EXTENSION_ID -StatePath $script:state -LogPath $script:log | Out-Null
        $after=Snapshot
        $after.Policy | Should -BeExactly $before.Policy
        $after.Protected | Should -BeExactly $before.Protected
    }
    It 'Apply WhatIf performs zero mutation' {
        $before=Snapshot
        & $provider -Action Apply -ExtensionId $env:LACKSAN_EDGE_EXTENSION_ID -StatePath $script:state -LogPath $script:log -WhatIf | Out-Null
        $after=Snapshot
        $after.Policy | Should -BeExactly $before.Policy
        $after.Protected | Should -BeExactly $before.Protected
    }
}

$provider = Join-Path $PSScriptRoot '..\providers\EdgeTrueDemandLaunch.ps1'
Describe 'EdgeTrueDemandLaunch integration' -Tag 'WindowsIntegration' {
    It 'keeps Edge policy state unchanged during Check DryRun and Apply WhatIf' -Skip:(-not $IsWindows) {
        $path='HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
        $name='StartupBoostEnabled'
        function Snapshot {
            if(!(Test-Path -LiteralPath $path)){ return 'key-absent' }
            $k=Get-Item -LiteralPath $path
            if(!($k.GetValueNames()-contains$name)){ return 'value-absent' }
            [ordered]@{Kind=$k.GetValueKind($name).ToString();Data=$k.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}|ConvertTo-Json -Compress
        }
        $before=Snapshot
        & $provider -Action Check | Out-Null
        try { & $provider -Action DryRun | Out-Null } catch { }
        $state=Join-Path $TestDrive 'edge-state.json'
        try { & $provider -Action Apply -StatePath $state -WhatIf | Out-Null } catch { }
        (Snapshot) | Should -BeExactly $before
    }
}

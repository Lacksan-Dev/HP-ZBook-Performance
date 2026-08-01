$provider = Join-Path $PSScriptRoot '..\providers\EdgeVisibleStartupOff.ps1'
Describe 'EdgeVisibleStartupOff integration' -Tag 'WindowsIntegration' {
    BeforeAll {
        if($env:RUN_LACKSAN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT'){ Set-ItResult -Skipped -Because 'Opt-in Windows integration only.'; return }
        function Snapshot-State {
            $path='HKLM:\SOFTWARE\Policies\Microsoft\Edge';$name='LaunchEdgeOnWindowsStartupEnabled'
            $policy=if(Test-Path -LiteralPath $path){$k=Get-Item -LiteralPath $path;if($k.GetValueNames()-contains$name){[ordered]@{Key=$true;Value=$true;Kind=$k.GetValueKind($name).ToString();Data=$k.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}else{[ordered]@{Key=$true;Value=$false}}}else{[ordered]@{Key=$false;Value=$false}}
            $startup=foreach($f in @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup'))|Where-Object{$_}){if(Test-Path -LiteralPath $f){Get-ChildItem -LiteralPath $f -File -ErrorAction SilentlyContinue|Select-Object FullName,Length,LastWriteTimeUtc}}
            [ordered]@{Policy=$policy;Startup=@($startup)}|ConvertTo-Json -Compress -Depth 8
        }
    }
    It 'keeps policy and Startup-folder state unchanged during Check DryRun and Apply WhatIf' {
        $before=Snapshot-State
        & $provider -Action Check | Out-Null
        try { & $provider -Action DryRun | Out-Null } catch { }
        $state=Join-Path $TestDrive 'edge-visible-startup-state.json'
        try { & $provider -Action Apply -StatePath $state -WhatIf | Out-Null } catch { }
        (Snapshot-State) | Should -BeExactly $before
    }
}

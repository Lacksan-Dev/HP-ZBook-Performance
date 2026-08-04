Describe 'EXP-120 HP Hotkey UWP zero-mutation integration' -Tag 'WindowsIntegration' {
    BeforeAll {
        $script:providerPath = Join-Path $PSScriptRoot '..\providers\HpHotkeyUwpDelayedStart.ps1'
        $script:integrationEnabled = $env:LACKSAN_RUN_WINDOWS_INTEGRATION -eq '1' -and $env:OS -eq 'Windows_NT'
    }

    It 'keeps service configuration and hotkey device state unchanged during Check and DryRun' -Skip:(-not $script:integrationEnabled) {
        function Get-IntegrationSnapshot {
            [ordered]@{
                Services = @(Get-CimInstance Win32_Service | Select-Object Name,StartMode,State,PathName | Sort-Object Name)
                HotkeyDevices = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
                    $_.Class -match '(?i)keyboard|hidclass|system' -and $_.FriendlyName -match '(?i)HP|hotkey|keyboard|HID|ACPI'
                } | Select-Object InstanceId,Status,Class,FriendlyName | Sort-Object InstanceId)
            } | ConvertTo-Json -Compress -Depth 10
        }

        $before = Get-IntegrationSnapshot
        $state = Join-Path $TestDrive 'state.json'
        $log = Join-Path $TestDrive 'events.jsonl'
        $floor = Join-Path $TestDrive 'security-floor.json'
        $support = & $script:providerPath -Action Check -StatePath $state -LogPath $log -SecurityFloorPath $floor
        if ($support.Supported) {
            & $script:providerPath -Action DryRun -StatePath $state -LogPath $log -SecurityFloorPath $floor | Out-Null
        }
        $after = Get-IntegrationSnapshot
        $after | Should -BeExactly $before
    }

    It 'contains no broad destructive operation' {
        $text = Get-Content -LiteralPath $script:providerPath -Raw
        $text | Should -Not -Match 'Remove-Service|sc\.exe\s+delete|Remove-AppxPackage|Disable-PnpDevice|Remove-PnpDevice|pnputil|Unregister-ScheduledTask|Disable-ScheduledTask|Set-MpPreference|Set-NetFirewallRule'
    }
}

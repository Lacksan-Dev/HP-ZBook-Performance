$sut = Join-Path $PSScriptRoot 'Invoke-Exp136ScheduledTaskInventory.ps1'
$runIntegration = $env:LACKSAN_EXP136_INTEGRATION -eq '1'

Describe 'EXP-136 zero-mutation Windows integration' -Tag Integration {
    It 'preserves scheduled tasks during Check Capture and DryRun' -Skip:(-not $runIntegration) {
        if ($env:OS -ne 'Windows_NT') { Set-ItResult -Skipped -Because 'Windows is required'; return }

        function Get-TaskSnapshot {
            @(Get-ScheduledTask | Sort-Object TaskPath,TaskName | ForEach-Object {
                $xml = Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath
                [pscustomobject]@{
                    taskPath = $_.TaskPath
                    taskName = $_.TaskName
                    state = [string]$_.State
                    xml = $xml
                }
            }) | ConvertTo-Json -Depth 8 -Compress
        }

        function Get-ProtectedSnapshot {
            $services = 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale'
            [pscustomobject]@{
                services = @($services | ForEach-Object {
                    $s = Get-Service $_ -ErrorAction SilentlyContinue
                    if ($s) { [pscustomobject]@{name=$s.Name;status=[string]$s.Status;startType=[string]$s.StartType} }
                })
                drivers = @(Get-CimInstance Win32_SystemDriver | Sort-Object Name | ForEach-Object { [pscustomobject]@{name=$_.Name;state=$_.State;startMode=$_.StartMode;path=$_.PathName} })
                processes = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '(?i)omnissa|horizon|msrdc|mstsc|tailscale|windowsapp' } | Sort-Object Name,Id | ForEach-Object { [pscustomobject]@{name=$_.Name;id=$_.Id} })
            } | ConvertTo-Json -Depth 8 -Compress
        }

        $beforeTasks = Get-TaskSnapshot
        $beforeProtected = Get-ProtectedSnapshot
        $temp = Join-Path ([IO.Path]::GetTempPath()) ('exp136-' + [guid]::NewGuid().ToString('n') + '.json')
        try {
            & $sut -Action Check | Out-Null
            & $sut -Action Capture -OutputPath $temp | Out-Null
            & $sut -Action DryRun | Out-Null
            & $sut -Action Capture -OutputPath $temp -WhatIf | Out-Null

            (Get-TaskSnapshot) | Should -BeExactly $beforeTasks
            (Get-ProtectedSnapshot) | Should -BeExactly $beforeProtected
        }
        finally {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'keeps Select mutation-free when physical attribution is supplied' -Skip:(-not $runIntegration) {
        if ($env:OS -ne 'Windows_NT') { Set-ItResult -Skipped -Because 'Windows is required'; return }

        $inventoryPath = Join-Path ([IO.Path]::GetTempPath()) ('exp136-inventory-' + [guid]::NewGuid().ToString('n') + '.json')
        $attrPath = Join-Path ([IO.Path]::GetTempPath()) ('exp136-attribution-' + [guid]::NewGuid().ToString('n') + '.json')
        try {
            $inventory = & $sut -Action Capture -OutputPath $inventoryPath
            $eligible = @($inventory.tasks | Where-Object { $_.eligibleForAttribution })
            if ($eligible.Count -eq 0) { Set-ItResult -Skipped -Because 'No eligible physical candidate exists on this machine'; return }

            @([pscustomobject]@{ taskIdHash=$eligible[0].taskIdHash; trials=5; startupCostScore=1.0 }) |
                ConvertTo-Json | Set-Content -LiteralPath $attrPath -Encoding UTF8

            $before = @(Get-ScheduledTask | Sort-Object TaskPath,TaskName | ForEach-Object { Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath }) | ConvertTo-Json -Compress
            $selection = & $sut -Action Select -AttributionPath $attrPath
            $after = @(Get-ScheduledTask | Sort-Object TaskPath,TaskName | ForEach-Object { Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath }) | ConvertTo-Json -Compress

            $selection.mutationAllowed | Should -BeFalse
            $after | Should -BeExactly $before
        }
        finally {
            Remove-Item -LiteralPath $inventoryPath,$attrPath -Force -ErrorAction SilentlyContinue
        }
    }
}

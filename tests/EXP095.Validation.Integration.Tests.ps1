Describe 'EXP-095 validation harness Windows integration' -Tag 'Integration' {
    BeforeAll {
        if ($env:LACKSAN_RUN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') {
            Set-ItResult -Skipped -Because 'Set LACKSAN_RUN_WINDOWS_INTEGRATION=1 on Windows to run opt-in integration coverage.'
            return
        }

        $script:Harness = Join-Path $PSScriptRoot '../validation/Invoke-EXP095Validation.ps1'
        $script:EvidenceRoot = Join-Path $TestDrive 'EXP-095'

        function Get-ServiceConfigurationSnapshot {
            $names = @('hpqcaslwmiex','WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale')
            $items = foreach ($name in $names) {
                $svc = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
                if ($svc) {
                    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$name"
                    $delayedProperty = Get-ItemProperty -LiteralPath $key -Name DelayedAutoStart -ErrorAction SilentlyContinue
                    [pscustomobject]@{
                        Name = $svc.Name
                        StartMode = $svc.StartMode
                        State = $svc.State
                        PathName = $svc.PathName
                        DelayedAutoStartPresent = $null -ne $delayedProperty
                        DelayedAutoStart = if ($null -ne $delayedProperty) { [int]$delayedProperty.DelayedAutoStart } else { $null }
                    }
                }
            }
            @($items | Sort-Object Name) | ConvertTo-Json -Compress -Depth 6
        }
    }

    It 'keeps the baseline evidence path zero-mutation for CASL and protected services' {
        if ($env:LACKSAN_RUN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') { return }

        $before = Get-ServiceConfigurationSnapshot
        & $Harness -Phase Baseline -EvidenceRoot $EvidenceRoot -TargetRuns 1 -SampleSeconds 1 | Out-Null
        $after = Get-ServiceConfigurationSnapshot

        $after | Should -BeExactly $before
        Test-Path (Join-Path $EvidenceRoot 'raw/Baseline-01.json') | Should -BeTrue
    }

    It 'keeps summarize zero-mutation and produces structured evidence' {
        if ($env:LACKSAN_RUN_WINDOWS_INTEGRATION -ne '1' -or $env:OS -ne 'Windows_NT') { return }

        $before = Get-ServiceConfigurationSnapshot
        $summary = & $Harness -Phase Summarize -EvidenceRoot $EvidenceRoot -TargetRuns 1
        $after = Get-ServiceConfigurationSnapshot

        $after | Should -BeExactly $before
        $summary.experiment | Should -Be 'EXP-095'
        $summary.classification | Should -Be 'inconclusive'
        Test-Path (Join-Path $EvidenceRoot 'summary.json') | Should -BeTrue
    }
}

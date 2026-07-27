$scriptPath = Join-Path $PSScriptRoot 'Invoke-LatencySurfaceAudit.ps1'
$scriptText = Get-Content -LiteralPath $scriptPath -Raw

Describe 'EXP-023 latency-surface profiler contract' {
    It 'offers only observation actions' {
        $scriptText | Should Match "ValidateSet\('Audit', 'Trace', 'Status'\)"
        $scriptText | Should Not Match '\b(Set-ItemProperty|Remove-ItemProperty|Stop-Service|Set-Service|sc\.exe|fltmc\.exe\s+(unload|detach))\b'
    }

    It 'implements bounded WPR capture and dry-run support' {
        $scriptText | Should Match 'SupportsShouldProcess = \$true'
        $scriptText | Should Match 'ValidateRange\(5, 300\)'
        $scriptText | Should Match '\$PSCmdlet\.ShouldProcess'
        $scriptText | Should Match "'-cancel'"
    }

    It 'records shell-extension and minifilter candidates without declaring them unnecessary' {
        $scriptText | Should Match 'ContextMenuHandlers'
        $scriptText | Should Match 'fltmc\.exe'
        $scriptText | Should Match 'candidateOnly = \$true'
        $scriptText | Should Match 'does not measure latency or prove'
    }

    It 'records the Shell Launcher edition boundary' {
        $scriptText | Should Match 'shellLauncherEditionSupported'
        $scriptText | Should Match 'Microsoft Shell Launcher is not supported on this Windows edition'
    }

    It 'writes verifiable structured evidence without machine or user names' {
        $scriptText | Should Match 'ConvertTo-Json -Depth 16'
        $scriptText | Should Match 'Audit evidence verification failed'
        $scriptText | Should Not Match '\$env:USERNAME|\$env:COMPUTERNAME'
        $scriptText | Should Match 'Protect-LocalPath'
    }

    It 'preserves the instrumentation-overhead limitation' {
        $scriptText | Should Match "instrumentationOverhead = 'Unqualified'"
        $scriptText | Should Match 'WPR instrumentation overhead is not yet qualified'
    }
}

if ($env:OS -eq 'Windows_NT') {
    Describe 'EXP-023 read-only runtime behavior' {
        It 'creates a schema-valid audit and reports no applied changes' {
            $outputRoot = Join-Path $TestDrive 'audit'
            $result = & $scriptPath Audit -OutputRoot $outputRoot -SkipSignatureValidation
            $summary = @($result) | Where-Object { $_.action -eq 'Audit' } | Select-Object -Last 1

            $summary | Should Not BeNullOrEmpty
            $summary.changesApplied | Should Be $false
            (Test-Path -LiteralPath $summary.evidencePath) | Should Be $true

            $evidence = Get-Content -LiteralPath $summary.evidencePath -Raw | ConvertFrom-Json
            $evidence.schemaVersion | Should Be 1
            $evidence.experiment | Should Be 'EXP-023'
            $evidence.evidenceClass | Should Be 'ObservationOnly'
            $evidence.changesApplied | Should Be $false
        }

        It 'previews a trace without starting WPR or creating an ETL file' {
            $outputRoot = Join-Path $TestDrive 'trace-preview'
            $result = & $scriptPath Trace -Seconds 5 -OutputRoot $outputRoot -WhatIf
            $summary = @($result) | Where-Object { $_.action -eq 'Trace' } | Select-Object -Last 1

            $summary | Should Not BeNullOrEmpty
            $summary.preview | Should Be $true
            $summary.changesApplied | Should Be $false
            @(Get-ChildItem -LiteralPath $outputRoot -Filter '*.etl' -ErrorAction SilentlyContinue).Count | Should Be 0
        }
    }
}

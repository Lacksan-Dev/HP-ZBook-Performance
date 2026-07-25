BeforeAll {
    $script:Harness = Join-Path $PSScriptRoot '..\Invoke-Exp001Baseline.ps1'
    $script:TestRoot = Join-Path $TestDrive 'exp001-output'
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
}

Describe 'EXP-001 observational baseline harness' {
    It 'parses as valid PowerShell' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:Harness,[ref]$tokens,[ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }

    It 'contains no state-changing tuning commands' {
        $source = Get-Content -LiteralPath $script:Harness -Raw
        $forbidden = @(
            'Set-MpPreference',
            'Disable-WindowsOptionalFeature',
            'Stop-Service',
            'Set-Service',
            'bcdedit',
            'powercfg /set',
            'Remove-AppxPackage',
            'Set-ItemProperty'
        )
        foreach ($command in $forbidden) {
            $source | Should -Not -Match ([regex]::Escape($command))
        }
    }

    It 'supports the required actions' {
        $source = Get-Content -LiteralPath $script:Harness -Raw
        foreach ($action in @('Check','DryRun','Capture','Verify','Rollback')) {
            $source | Should -Match "'$action'"
        }
    }

    It 'creates a dry-run report without mutable-state capture' -Skip:($env:OS -ne 'Windows_NT') {
        $runId = 'pester-dryrun'
        & $script:Harness -Action DryRun -Workflow Idle -OutputRoot $script:TestRoot -RunId $runId -AllowNonHpLabHost | Out-Null
        $runPath = Join-Path $script:TestRoot $runId
        Test-Path (Join-Path $runPath 'plan.json') | Should -BeTrue
        Test-Path (Join-Path $runPath 'manifest.json') | Should -BeTrue
        Test-Path (Join-Path $runPath 'original-state.json') | Should -BeFalse
        $manifest = Get-Content (Join-Path $runPath 'manifest.json') -Raw | ConvertFrom-Json
        $manifest.Classification | Should -Be 'dry-run'
    }

    It 'rejects unsupported production hardware without the explicit lab-host switch' -Skip:($env:OS -ne 'Windows_NT') {
        & $script:Harness -Action Check -OutputRoot $script:TestRoot 2>$null | Out-Null
        if ((Get-CimInstance Win32_ComputerSystem).Model -notmatch 'ZBook') {
            $LASTEXITCODE | Should -Be 2
        }
    }

    It 'captures screening evidence and verifies hashes' -Skip:($env:OS -ne 'Windows_NT') {
        $runId = 'pester-capture'
        & $script:Harness -Action Capture -Workflow OutlookCold -OutputRoot $script:TestRoot -RunId $runId -AllowNonHpLabHost | Out-Null
        $runPath = Join-Path $script:TestRoot $runId
        $manifest = Get-Content (Join-Path $runPath 'manifest.json') -Raw | ConvertFrom-Json
        $manifest.Classification | Should -Be 'screening'
        $manifest.FormalEvidence | Should -BeFalse

        $verification = & $script:Harness -Action Verify -OutputRoot $script:TestRoot -RunId $runId
        ($verification | ConvertFrom-Json).Passed | Should -BeTrue
    }

    It 'reports zero unexplained rollback differences for the read-only harness' -Skip:($env:OS -ne 'Windows_NT') {
        $runId = 'pester-rollback'
        & $script:Harness -Action Capture -Workflow EdgeCold -OutputRoot $script:TestRoot -RunId $runId -AllowNonHpLabHost | Out-Null
        $json = & $script:Harness -Action Rollback -OutputRoot $script:TestRoot -RunId $runId
        ($json | ConvertFrom-Json).Passed | Should -BeTrue
    }

    It 'detects tampered evidence' -Skip:($env:OS -ne 'Windows_NT') {
        $runId = 'pester-tamper'
        & $script:Harness -Action Capture -Workflow WindowsSearch -OutputRoot $script:TestRoot -RunId $runId -AllowNonHpLabHost | Out-Null
        $runPath = Join-Path $script:TestRoot $runId
        Add-Content -LiteralPath (Join-Path $runPath 'inventory.json') -Value 'tamper'
        & $script:Harness -Action Verify -OutputRoot $script:TestRoot -RunId $runId 2>$null | Out-Null
        $LASTEXITCODE | Should -Be 3
    }
}

BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $agentPath = Join-Path $repoRoot '.codex\agents\experiment-discovery-portfolio.toml'
    $runbookPath = Join-Path $repoRoot '.codex\portfolio-agent.md'
    $runnerPath = Join-Path $repoRoot '.codex\scripts\Invoke-PortfolioValidation.ps1'
    $queuePath = Join-Path $repoRoot 'portfolio\validation-queue.json'
    $exp065HarnessPath = Join-Path $repoRoot 'experiments\EXP-065\Invoke-Exp065LabHarness.ps1'
    $exp095HarnessPath = Join-Path $repoRoot 'experiments\EXP-095\Invoke-Exp095LabHarness.ps1'
    $agent = Get-Content -LiteralPath $agentPath -Raw
    $runbook = Get-Content -LiteralPath $runbookPath -Raw
    $runner = Get-Content -LiteralPath $runnerPath -Raw
    $queue = Get-Content -LiteralPath $queuePath -Raw | ConvertFrom-Json
}

Describe 'Experiment Discovery and Portfolio Codex agent' {
    It 'uses the project-scoped custom-agent schema' {
        $agent | Should -Match '(?m)^name\s*=\s*"experiment_discovery_portfolio"'
        $agent | Should -Match '(?m)^description\s*='
        $agent | Should -Match '(?m)^developer_instructions\s*=\s*"""'
    }

    It 'codifies evidence, merge, release, and physical-mutation boundaries' {
        foreach ($token in @('needs-evidence','Missing checks are not passing checks','no sensitive data','exact rollback','never assign Stable','Do not post inventory-only commentary','only authorized machine-mutation entry point','Never run a provider or change Windows directly')) {
            $agent | Should -Match ([regex]::Escape($token))
        }
    }
}

Describe 'Portfolio runbook and queue' {
    It 'defines focused Experimental verification gates' {
        foreach ($token in @('one candidate and one changed variable','five matched baseline','five matched treatment','original-state capture','sensitive-data gate','Never assign `Stable`')) {
            $runbook | Should -Match ([regex]::Escape($token))
        }
    }

    It 'accepts multiple reviewed ready candidates in deterministic priority order' {
        $queue.schemaVersion | Should -Be 1
        $items = @($queue.items)
        $items.Count | Should -BeGreaterThan 1
        @($items | Group-Object experiment | Where-Object Count -gt 1).Count | Should -Be 0
        $ordered = @($items | Sort-Object priority,experiment)
        @($items | ForEach-Object experiment) -join ',' | Should -Be (@($ordered | ForEach-Object experiment) -join ',')
        $items[0].experiment | Should -Be 'EXP-065'
        $items[1].experiment | Should -Be 'EXP-095'
        [int]$items[0].priority | Should -BeLessThan ([int]$items[1].priority)
        foreach ($item in $items) {
            $item.track | Should -Be 'service-candidate'
            $item.state | Should -Be 'ready'
            $item.releaseState | Should -Be 'Experimental'
            $item.runsPerArm | Should -Be 5
            @($item.verification).Count | Should -BeGreaterThan 0
            $item.rollback | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $repoRoot ($item.harnessPath.Replace('/','\'))) | Should -BeTrue
        }
    }

    It 'declares every protected startup, network, and security scope on every candidate' {
        $required = @('WindowsSecurity','WindowsUpdate','EdgeUpdate','Credentials','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Networking','Omnissa','WindowsApp','RemoteDesktop','Tailscale')
        foreach ($item in @($queue.items)) {
            $declared = @($item.protectedScopes)
            foreach ($scope in $required) { $declared | Should -Contain $scope }
        }
    }
}

Describe 'Guarded HP laptop validation runner' {
    It 'parses under Windows PowerShell syntax' {
        $tokens = $null; $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($runnerPath,[ref]$tokens,[ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }

    It 'enforces one active run while selecting the highest-priority ready candidate' {
        foreach ($token in @('active-cycle.json','Sort-Object priority,experiment','Start-ReadyValidation -Item $ready[0]','Test-IsElevated','GetSystemPowerStatus','GetLastInputInfo','Test-PendingReboot','SESSIONNAME','msiexec','RequiredProtectedScopes','Register-ScheduledTask','VerifyReboot','Rollback')) {
            $runner | Should -Match ([regex]::Escape($token))
        }
    }

    It 'keeps raw evidence local and writes only bounded Experimental evidence' {
        $runner | Should -Match "retention = 'machine-local-only'"
        $runner | Should -Match "releaseState = 'Experimental'"
        $runner | Should -Match 'identifiersCommitted = \$false'
        $runner | Should -Match 'stableAssignment = \$false'
        $runner | Should -Match 'evidence\\physical'
    }

    It 'inspects all ready candidates without creating machine-local state' {
        $testData = Join-Path $TestDrive 'portfolio-validation'
        $result = & $runnerPath -Action Inspect -QueuePath $queuePath -DataRoot $testData
        $result.mutationPerformed | Should -BeFalse
        @($result.readyExperiments) | Should -Contain 'EXP-065'
        @($result.readyExperiments) | Should -Contain 'EXP-095'
        @($result.readyExperiments)[0] | Should -Be 'EXP-065'
        Test-Path -LiteralPath $testData | Should -BeFalse
    }
}

Describe 'Queued reboot harness contracts' {
    It 'keeps EXP-065 and EXP-095 parseable with complete guarded lifecycles' {
        foreach ($harnessPath in @($exp065HarnessPath,$exp095HarnessPath)) {
            $tokens = $null; $errors = $null
            [Management.Automation.Language.Parser]::ParseFile($harnessPath,[ref]$tokens,[ref]$errors) | Out-Null
            @($errors).Count | Should -Be 0
            $harness = Get-Content -LiteralPath $harnessPath -Raw
            foreach ($token in @('Start','Continue','Status','Stop','Capture','DryRun','VerifyReboot','Rollback','Register-ScheduledTask')) {
                $harness | Should -Match ([regex]::Escape($token))
            }
        }
    }
}
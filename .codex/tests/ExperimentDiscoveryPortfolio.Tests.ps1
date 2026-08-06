BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $agentPath = Join-Path $repoRoot '.codex\agents\experiment-discovery-portfolio.toml'
    $runbookPath = Join-Path $repoRoot '.codex\portfolio-agent.md'
    $runnerPath = Join-Path $repoRoot '.codex\scripts\Invoke-PortfolioValidation.ps1'
    $queuePath = Join-Path $repoRoot 'portfolio\validation-queue.json'
    $exp065HarnessPath = Join-Path $repoRoot 'experiments\EXP-065\Invoke-Exp065LabHarness.ps1'
    $exp095HarnessPath = Join-Path $repoRoot 'experiments\EXP-095\Invoke-Exp095LabHarness.ps1'
    $agentsPath = Join-Path $repoRoot 'AGENTS.md'
    $projectPath = Join-Path $repoRoot 'PROJECT.md'
    $portfolioReadmePath = Join-Path $repoRoot 'portfolio\README.md'
    $cursorPath = Join-Path $repoRoot 'experiments\EXP-001\hourly-layer-cycle.json'
    $agent = Get-Content -LiteralPath $agentPath -Raw
    $runbook = Get-Content -LiteralPath $runbookPath -Raw
    $runner = Get-Content -LiteralPath $runnerPath -Raw
    $queue = Get-Content -LiteralPath $queuePath -Raw | ConvertFrom-Json
    $agents = Get-Content -LiteralPath $agentsPath -Raw
    $project = Get-Content -LiteralPath $projectPath -Raw
    $portfolioReadme = Get-Content -LiteralPath $portfolioReadmePath -Raw
    $cursor = Get-Content -LiteralPath $cursorPath -Raw | ConvertFrom-Json
}

Describe 'Experiment Discovery and Portfolio Codex agent' {
    It 'uses the project-scoped custom-agent schema' {
        $agent | Should -Match '(?m)^name\s*=\s*"experiment_discovery_portfolio"'
        $agent | Should -Match '(?m)^description\s*='
        $agent | Should -Match '(?m)^developer_instructions\s*=\s*"""'
    }

    It 'requires every portfolio input and all three independent lanes' {
        foreach ($token in @(
            'hourly-layer-cycle.json','open issues','open pull requests','checks and workflow results',
            'evidence merged','startup responsiveness','Edge demand-launch','service candidates'
        )) {
            $agent | Should -Match ([regex]::Escape($token))
        }
    }

    It 'keeps the checked-in portfolio cadence aligned at two hours' {
        $agent | Should -Match 'every two hours'
        $agents | Should -Match 'every two hours'
        $project | Should -Match 'every two hours'
        $portfolioReadme | Should -Match 'two-hour\s+cadence'
        $cursor.cadence | Should -Be 'two-hour'
        foreach ($track in @($cursor.activeTracks)) { $track.cadence | Should -Be 'two-hour' }
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

    It 'retains completed history and accepts remaining candidates in deterministic priority order' {
        $queue.schemaVersion | Should -Be 1
        $items = @($queue.items)
        $items.Count | Should -BeGreaterThan 1
        @($items | Group-Object experiment | Where-Object Count -gt 1).Count | Should -Be 0
        $ordered = @($items | Sort-Object priority,experiment)
        @($items | ForEach-Object experiment) -join ',' | Should -Be (@($ordered | ForEach-Object experiment) -join ',')
        $items[0].experiment | Should -Be 'EXP-065'
        $items[1].experiment | Should -Be 'EXP-095'
        [int]$items[0].priority | Should -BeLessThan ([int]$items[1].priority)
        $items[0].state | Should -Be 'completed'
        $items[0].result | Should -Be 'unqualified'
        $items[0].evidencePath | Should -Be 'evidence/physical/EXP-065/20260806-034334'
        foreach ($item in $items) {
            $item.track | Should -BeIn @('service-candidate','startup-responsiveness')
            $item.state | Should -BeIn @('ready','completed')
            $item.releaseState | Should -Be 'Experimental'
            $item.runsPerArm | Should -Be 5
            @($item.verification).Count | Should -BeGreaterThan 0
            $item.rollback | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $repoRoot ($item.harnessPath.Replace('/','\'))) | Should -BeTrue
        }
        foreach ($item in @($items | Select-Object -Skip 1)) { $item.state | Should -Be 'ready' }
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
        $runner | Should -Match ([regex]::Escape("Join-Path `$DataRoot 'sanitized-evidence'"))
    }

    It 'inspects all ready candidates without creating machine-local state' {
        $testData = Join-Path $TestDrive 'portfolio-validation'
        $result = & $runnerPath -Action Inspect -QueuePath $queuePath -DataRoot $testData
        $result.mutationPerformed | Should -BeFalse
        @($result.readyExperiments) | Should -Not -Contain 'EXP-065'
        @($result.readyExperiments) | Should -Contain 'EXP-095'
        @($result.readyExperiments)[0] | Should -Be 'EXP-095'
        Test-Path -LiteralPath $testData | Should -BeFalse
    }

    It 'provides an explicit runner-owned recovery path that retains failures and never exports an incomplete run' {
        $runner | Should -Match "ValidateSet\('Inspect','Auto','Export','Recover'\)"
        $runner | Should -Match 'function Recover-ActiveValidation'
        $runner | Should -Match ([regex]::Escape('& $harness -Action Stop'))
        $runner | Should -Match "evidenceStatus = 'recovered-needs-rerun'"
        $runner | Should -Match 'the incomplete run is not publishable evidence'
        $runner | Should -Match 'retain the active cycle for inspection'
    }

    It 'accepts only a commit-bound local recovery request through the guarded Auto path' {
        foreach ($token in @('RecoveryRequestPath','LocalApplicationData','recovery-request.json','request.activeSourceCommit','active.sourceCommit','request.runnerCommit','Get-SourceCommit')) {
            $runner | Should -Match ([regex]::Escape($token))
        }
        $runner | Should -Match ([regex]::Escape("`$Action -eq 'Auto'"))
        $runner | Should -Match "request.action -ne 'recover'"
        $runner | Should -Match "recoveryResult.evidenceStatus -eq 'recovered-needs-rerun'"
        $runner | Should -Match 'Retain the active cycle and recovery request for inspection'
    }

    It 'exports only bounded aggregate evidence from identifier-bearing raw files' {
        $dataRoot = Join-Path $TestDrive 'machine-data'
        $evidenceRoot = Join-Path $dataRoot 'runs\EXP-065'
        $runDirectory = Join-Path $evidenceRoot '20260804-000000'
        $outputRoot = Join-Path $TestDrive 'published-evidence'
        New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
        [ordered]@{
            schema = 1
            experiment = 'EXP-065'
            generatedUtc = '2026-08-04T00:00:00Z'
            computer = 'DESKTOP-SECRET'
            groups = [ordered]@{
                Baseline = [ordered]@{ runs=5; cpuMedianPercent=[ordered]@{median=4.1;mad=0.2}; privatePath='C:\Users\secret' }
                Treatment = [ordered]@{ runs=5; cpuMedianPercent=[ordered]@{median=3.8;mad=0.3}; userSid='S-1-5-21-secret' }
            }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $runDirectory 'summary.json') -Encoding UTF8
        @(
            '{"action":"Capture","event":"state-captured","computer":"DESKTOP-SECRET","userSid":"S-1-5-21-secret"}',
            '{"action":"Apply","event":"dry-run","path":"C:\\Users\\secret"}',
            '{"action":"Apply","event":"applied"}',
            '{"action":"Verify","event":"verified"}',
            '{"action":"VerifyReboot","event":"reboot-verified"}',
            '{"action":"Rollback","event":"rolled-back"}'
        ) | Set-Content -LiteralPath (Join-Path $runDirectory 'controller-events.jsonl') -Encoding UTF8
        New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
        [ordered]@{
            schemaVersion=1;experiment='EXP-065';issue=153;track='service-candidate';releaseState='Experimental'
            harnessPath='experiments/EXP-065/Invoke-Exp065LabHarness.ps1';evidenceRoot=$evidenceRoot;sourceCommit='0123456789abcdef'
            candidate='One bounded service startup-mode candidate.';benchmark='Five matched baseline and treatment boots.'
            protectedScopes=@($queue.items[0].protectedScopes);startedUtc='2026-08-04T00:00:00Z';status='harness-active'
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $dataRoot 'active-cycle.json') -Encoding UTF8

        $result = & $runnerPath -Action Export -QueuePath $queuePath -DataRoot $dataRoot -EvidenceOutputRoot $outputRoot
        $publishedPath = @(Get-ChildItem -LiteralPath $outputRoot -Filter 'summary.json' -File -Recurse)[0].FullName
        $publishedText = Get-Content -LiteralPath $publishedPath -Raw
        $published = $publishedText | ConvertFrom-Json
        $result.evidenceStatus | Should -Be 'physical-lifecycle-recorded'
        $published.releaseState | Should -Be 'Experimental'
        $published.stableAssignment | Should -BeFalse
        $published.performanceClaim | Should -BeFalse
        $published.classification | Should -Be 'unqualified'
        $published.lifecycle.capture | Should -BeTrue
        $published.lifecycle.dryRun | Should -BeTrue
        $published.lifecycle.apply | Should -BeTrue
        $published.lifecycle.verify | Should -BeTrue
        $published.lifecycle.verifyReboot | Should -BeTrue
        $published.lifecycle.rollback | Should -BeTrue
        $published.rawEvidence.identifiersCommitted | Should -BeFalse
        $publishedText | Should -Not -Match 'DESKTOP-SECRET|S-1-5-21-secret|C:\\\\Users\\\\secret|privatePath|userSid'
        Test-Path -LiteralPath (Join-Path $dataRoot 'active-cycle.json') | Should -BeFalse
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

    It 'runs EXP-095 support detection and dry run before registering reboot continuation' {
        $harness = Get-Content -LiteralPath $exp095HarnessPath -Raw
        $start = [regex]::Match($harness,"'Start'\s*\{(?<body>.+?)\}\s*'Continue'",[Text.RegularExpressions.RegexOptions]::Singleline).Groups['body'].Value
        $start.IndexOf('InvokePhase Preflight') | Should -BeGreaterThan -1
        $start.IndexOf('RegisterResume') | Should -BeGreaterThan $start.IndexOf('InvokePhase Preflight')
        $validation = Get-Content -LiteralPath (Join-Path $repoRoot 'validation\Invoke-EXP095Validation.ps1') -Raw
        $validation | Should -Match ([regex]::Escape("'Preflight'{& `$provider -Action Check"))
        $validation | Should -Match ([regex]::Escape('& $provider -Action DryRun'))
    }
}

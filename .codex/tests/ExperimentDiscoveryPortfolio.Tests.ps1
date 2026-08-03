BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $agentPath = Join-Path $repoRoot '.codex\agents\experiment-discovery-portfolio.toml'
    $runbookPath = Join-Path $repoRoot '.codex\portfolio-agent.md'
    $runnerPath = Join-Path $repoRoot '.codex\scripts\Invoke-PortfolioValidation.ps1'
    $queuePath = Join-Path $repoRoot 'portfolio\validation-queue.json'
    $harnessPath = Join-Path $repoRoot 'experiments\EXP-065\Invoke-Exp065LabHarness.ps1'
    $agent = Get-Content -LiteralPath $agentPath -Raw
    $runbook = Get-Content -LiteralPath $runbookPath -Raw
    $runner = Get-Content -LiteralPath $runnerPath -Raw
    $harness = Get-Content -LiteralPath $harnessPath -Raw
    $queue = Get-Content -LiteralPath $queuePath -Raw | ConvertFrom-Json
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

    It 'codifies evidence, merge, release, and note boundaries' {
        $agent | Should -Match 'needs-evidence'
        $agent | Should -Match 'Missing checks are not passing checks'
        $agent | Should -Match 'no sensitive data'
        $agent | Should -Match 'exact rollback'
        $agent | Should -Match 'never assign Stable'
        $agent | Should -Match 'Do not post inventory-only commentary'
    }

    It 'makes the guarded runner the only physical mutation entry point' {
        $agent | Should -Match ([regex]::Escape('.codex/scripts/Invoke-PortfolioValidation.ps1 -Action Auto -AllowAutomaticReboot'))
        $agent | Should -Match 'only authorized machine-mutation entry point'
        $agent | Should -Match 'Never run a provider or change Windows directly'
    }
}

Describe 'Portfolio runbook and queue' {
    It 'defines focused issue and Experimental merge gates' {
        foreach ($token in @(
            'one candidate and one changed variable','five matched baseline','five matched treatment',
            'original-state capture','sensitive-data gate','Never assign `Stable`'
        )) {
            $runbook | Should -Match ([regex]::Escape($token))
        }
    }

    It 'contains one reviewed Experimental ready candidate' {
        $queue.schemaVersion | Should -Be 1
        @($queue.items).Count | Should -Be 1
        $item = @($queue.items)[0]
        $item.experiment | Should -Be 'EXP-065'
        $item.track | Should -Be 'service-candidate'
        $item.state | Should -Be 'ready'
        $item.releaseState | Should -Be 'Experimental'
        $item.runsPerArm | Should -Be 5
        @($item.verification).Count | Should -BeGreaterThan 0
        $item.rollback | Should -Not -BeNullOrEmpty
    }

    It 'declares every protected startup, network, and security scope' {
        $declared = @($queue.items[0].protectedScopes)
        foreach ($scope in @(
            'WindowsSecurity','WindowsUpdate','EdgeUpdate','Credentials','Recovery',
            'EnterpriseManagement','DeviceCriticalDrivers','Networking','Omnissa',
            'WindowsApp','RemoteDesktop','Tailscale'
        )) {
            $declared | Should -Contain $scope
        }
    }
}

Describe 'Guarded HP laptop validation runner' {
    It 'parses under Windows PowerShell syntax' {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($runnerPath,[ref]$tokens,[ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }

    It 'enforces the machine and harness safety gates' {
        foreach ($token in @(
            'Test-IsElevated','GetSystemPowerStatus','GetLastInputInfo','Test-PendingReboot',
            'SESSIONNAME','msiexec','single candidate','RequiredProtectedScopes',
            'Register-ScheduledTask','VerifyReboot','Rollback'
        )) {
            $runner | Should -Match ([regex]::Escape($token))
        }
    }

    It 'keeps raw evidence local and writes only a bounded Experimental export' {
        $runner | Should -Match "retention = 'machine-local-only'"
        $runner | Should -Match "releaseState = 'Experimental'"
        $runner | Should -Match 'identifiersCommitted = \$false'
        $runner | Should -Match 'stableAssignment = \$false'
        $runner | Should -Match 'evidence\\physical'
    }

    It 'can inspect the queue without creating machine-local state' {
        $testData = Join-Path $TestDrive 'portfolio-validation'
        $result = & $runnerPath -Action Inspect -QueuePath $queuePath -DataRoot $testData
        $result.mutationPerformed | Should -BeFalse
        @($result.readyExperiments) | Should -Contain 'EXP-065'
        Test-Path -LiteralPath $testData | Should -BeFalse
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
            classification = 'inconclusive'
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

Describe 'EXP-065 queued reboot harness' {
    It 'parses and exposes the complete guarded lifecycle' {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($harnessPath,[ref]$tokens,[ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
        foreach ($token in @('Start','Continue','Status','Stop','Capture','DryRun','VerifyReboot','Rollback')) {
            $harness | Should -Match ([regex]::Escape($token))
        }
    }

    It 'runs dry-run after capture and before registering the reboot sequence' {
        $start = [regex]::Match($harness,"'Start'\s*\{(?<body>.+?)\}\s*'Continue'",[Text.RegularExpressions.RegexOptions]::Singleline).Groups['body'].Value
        $start.IndexOf("Controller 'Capture'") | Should -BeGreaterThan -1
        $start.IndexOf("Controller 'Apply' `$dir -DryRun") | Should -BeGreaterThan $start.IndexOf("Controller 'Capture'")
        $start.IndexOf('Register-ResumeTask') | Should -BeGreaterThan $start.IndexOf("Controller 'Apply' `$dir -DryRun")
    }
}

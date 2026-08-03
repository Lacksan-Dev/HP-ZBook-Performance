BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $agent = Get-Content -LiteralPath (Join-Path $repoRoot '.codex\agents\experiment-discovery-portfolio.toml') -Raw
    $runnerPath = Join-Path $repoRoot '.codex\scripts\Invoke-PortfolioValidation.ps1'
    $queuePath = Join-Path $repoRoot 'portfolio\validation-queue.json'
    $queue = Get-Content -LiteralPath $queuePath -Raw | ConvertFrom-Json
}

Describe 'Portfolio validation regression coverage' {
    It 'retains all independent portfolio lanes and inputs' {
        foreach ($token in @('hourly-layer-cycle.json','open issues','open pull requests','checks and workflow results','evidence merged','startup responsiveness','Edge demand-launch','service candidates')) {
            $agent | Should -Match ([regex]::Escape($token))
        }
    }

    It 'exports bounded aggregate evidence and removes identifiers' {
        $dataRoot = Join-Path $TestDrive 'machine-data'
        $evidenceRoot = Join-Path $dataRoot 'runs\EXP-065'
        $runDirectory = Join-Path $evidenceRoot '20260804-000000'
        $outputRoot = Join-Path $TestDrive 'published-evidence'
        New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
        [ordered]@{
            schema=1; experiment='EXP-065'; generatedUtc='2026-08-04T00:00:00Z'; computer='DESKTOP-SECRET'; classification='inconclusive'
            groups=[ordered]@{ Baseline=[ordered]@{runs=5;cpuMedianPercent=[ordered]@{median=4.1;mad=0.2};privatePath='C:\Users\secret'}; Treatment=[ordered]@{runs=5;cpuMedianPercent=[ordered]@{median=3.8;mad=0.3};userSid='S-1-5-21-secret'} }
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $runDirectory 'summary.json') -Encoding UTF8
        @(
            '{"action":"Capture","event":"state-captured","computer":"DESKTOP-SECRET"}',
            '{"action":"Apply","event":"dry-run","path":"C:\\Users\\secret"}',
            '{"action":"Apply","event":"applied"}',
            '{"action":"Verify","event":"verified"}',
            '{"action":"VerifyReboot","event":"reboot-verified"}',
            '{"action":"Rollback","event":"rolled-back"}'
        ) | Set-Content -LiteralPath (Join-Path $runDirectory 'controller-events.jsonl') -Encoding UTF8
        New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
        [ordered]@{
            schemaVersion=1;experiment='EXP-065';issue=153;track='service-candidate';releaseState='Experimental';harnessPath='experiments/EXP-065/Invoke-Exp065LabHarness.ps1';evidenceRoot=$evidenceRoot;sourceCommit='0123456789abcdef';candidate='One bounded service startup-mode candidate.';benchmark='Five matched baseline and treatment boots.';protectedScopes=@($queue.items[0].protectedScopes);startedUtc='2026-08-04T00:00:00Z';status='harness-active'
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

    It 'keeps capture and dry-run ahead of reboot scheduling for EXP-065' {
        $harness = Get-Content -LiteralPath (Join-Path $repoRoot 'experiments\EXP-065\Invoke-Exp065LabHarness.ps1') -Raw
        $start = [regex]::Match($harness,"'Start'\s*\{(?<body>.+?)\}\s*'Continue'",[Text.RegularExpressions.RegexOptions]::Singleline).Groups['body'].Value
        $start.IndexOf("Controller 'Capture'") | Should -BeGreaterThan -1
        $start.IndexOf("Controller 'Apply' `$dir -DryRun") | Should -BeGreaterThan $start.IndexOf("Controller 'Capture'")
        $start.IndexOf('Register-ResumeTask') | Should -BeGreaterThan $start.IndexOf("Controller 'Apply' `$dir -DryRun")
    }
}
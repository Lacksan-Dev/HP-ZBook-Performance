BeforeAll {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $cyclePath = Join-Path $repoRoot '.codex\scripts\Invoke-LaptopCycle.ps1'
    $installerPath = Join-Path $repoRoot 'controller\automation\UxRomLaptopCycle.ps1'
    $bootstrapPath = Join-Path $repoRoot 'ZBookPerf.ps1'
    $cycle = Get-Content -LiteralPath $cyclePath -Raw
    $installer = Get-Content -LiteralPath $installerPath -Raw
    $bootstrap = Get-Content -LiteralPath $bootstrapPath -Raw
}

Describe 'Two-hour laptop cycle' {
    It 'parses every PowerShell entry point' {
        foreach ($path in @($cyclePath,$installerPath,$bootstrapPath)) {
            $tokens=$null; $errors=$null
            [Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors) | Out-Null
            @($errors).Count | Should -Be 0
        }
    }

    It 'updates only a clean inactive checkout by fast forward' {
        foreach ($token in @('active-cycle.json','status --porcelain','fetch origin main --prune','merge --ff-only origin/main','Global\LacksanUxRomLaptopCycle')) {
            $cycle | Should -Match ([regex]::Escape($token))
        }
        $cycle | Should -Not -Match 'reset --hard|checkout --|clean -f'
    }

    It 'uses the guarded portfolio runner for mutation and reboot continuation' {
        $cycle | Should -Match 'Invoke-PortfolioValidation.ps1'
        $cycle | Should -Match "Action = 'Auto'"
        $cycle | Should -Match 'AllowAutomaticReboot'
    }

    It 'installs one elevated recurring and logon task' {
        foreach ($token in @('UX-ROM Laptop Cycle','RepetitionInterval','IntervalHours = 2','New-ScheduledTaskTrigger -AtLogOn','RunLevel Highest','MultipleInstances IgnoreNew')) {
            $installer | Should -Match ([regex]::Escape($token))
        }
    }

    It 'exposes install remove and status from the main script' {
        foreach ($token in @('InstallLaptopCycle','RemoveLaptopCycle','LaptopCycleStatus','controller\automation\UxRomLaptopCycle.ps1')) {
            $bootstrap | Should -Match ([regex]::Escape($token))
        }
    }
}

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

    It 'binds automatic execution to one exact HP ZBook laptop' {
        foreach ($token in @('ExpectedMachineUuid','Assert-BoundZBookLaptop','Win32_ComputerSystemProduct','Win32_SystemEnclosure','Win32_Battery','\bZBook\b','portableChassis','different physical HP ZBook')) {
            $cycle | Should -Match ([regex]::Escape($token))
        }
        $guardPosition = $cycle.IndexOf('$targetIdentity = Assert-BoundZBookLaptop')
        $runnerPosition = $cycle.IndexOf('& $runner @arguments')
        $guardPosition | Should -BeGreaterThan -1
        $runnerPosition | Should -BeGreaterThan $guardPosition
    }

    It 'fails closed for legacy scheduled tasks without a machine binding' {
        $cycle | Should -Match 'predates machine binding'
        $cycle | Should -Match 'Reinstall it locally on the intended HP ZBook laptop'
    }

    It 'installs one elevated recurring and logon task only on a qualified ZBook laptop' {
        foreach ($token in @('UX-ROM Laptop Cycle','RepetitionInterval','IntervalHours = 2','New-ScheduledTaskTrigger -AtLogOn','RunLevel Highest','MultipleInstances IgnoreNew','Assert-ZBookLaptopTarget','Win32_ComputerSystemProduct','Win32_SystemEnclosure','Win32_Battery','ExpectedMachineUuid')) {
            $installer | Should -Match ([regex]::Escape($token))
        }
        $assertPosition = $installer.IndexOf('$target = Assert-ZBookLaptopTarget')
        $registerPosition = $installer.IndexOf('Register-ScheduledTask')
        $assertPosition | Should -BeGreaterThan -1
        $registerPosition | Should -BeGreaterThan $assertPosition
    }

    It 'persists the exact hardware UUID into the scheduled task command' {
        $installer | Should -Match "'-ExpectedMachineUuid '"
        $installer | Should -Match '\$target\.uuid'
        $installer | Should -Match 'bound to \$\(\$target\.model\)'
    }

    It 'exposes install remove and status from the main script' {
        foreach ($token in @('InstallLaptopCycle','RemoveLaptopCycle','LaptopCycleStatus','controller\automation\UxRomLaptopCycle.ps1')) {
            $bootstrap | Should -Match ([regex]::Escape($token))
        }
    }
}

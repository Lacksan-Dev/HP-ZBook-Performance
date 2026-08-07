Describe 'UX-ROM bounded performance tuning maintenance' {
    BeforeAll {
        $script:entryPath = Join-Path $PSScriptRoot '..\..\ZBookPerf.ps1'
        $script:helperPath = Join-Path $PSScriptRoot '..\maintenance\UxRomPerformanceTuning.ps1'
        $script:launcherInstallerPath = Join-Path $PSScriptRoot '..\..\scripts\Install-ZBookPerfSystem32Launcher.ps1'
        $script:entry = Get-Content -LiteralPath $script:entryPath -Raw
        $script:helper = Get-Content -LiteralPath $script:helperPath -Raw
    }

    It 'parses the entry point and maintenance helper' {
        foreach ($path in @($script:entryPath,$script:helperPath,$script:launcherInstallerPath)) {
            $tokens = $null
            $errors = $null
            [Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors) | Out-Null
            @($errors).Count | Should -Be 0
        }
    }

    It 'exposes one apply command and its rollback without public preflight actions' {
        $script:entry | Should -Match "'PerformanceTune'"
        $script:entry | Should -Match "'PerformanceTuneRollback'"
        $script:entry | Should -Not -Match "PerformanceTuneCheck"
        $script:entry | Should -Not -Match "PerformanceTuneDryRun"
        $script:entry | Should -Not -Match "PerformanceTuneVerify"
        $script:entry | Should -Match 'Enter-UxRomProcessExecutionPolicy'
    }

    It 'binds support to the intended HP ZBook portable model' {
        foreach ($token in @('Win32_OperatingSystem','Win32_ComputerSystem','Win32_ComputerSystemProduct','Win32_SystemEnclosure','ZBook\s+Firefly\s+14.*G8','MachineUuid')) {
            $script:helper | Should -Match $token
        }
    }

    It 'pins the three HP-recommended driver packages and verifies HP signatures' {
        foreach ($token in @(
            'sp172303','2547.8.50.0','sp172001-172500/sp172303.exe',
            'sp165709','23.170.1.1','sp165501-166000/sp165709.exe',
            'sp173092','19.6.1.27','sp173001-173500/sp173092.exe',
            'Get-AuthenticodeSignature','HP Inc\.','pnputil.exe','/export-driver','/delete-driver','/add-driver'
        )) { $script:helper | Should -Match ([regex]::Escape($token)) }
    }

    It 'changes only the AC power-mode vote and captures its exact original GUID' {
        $script:helper | Should -Match 'PowerGetUserConfiguredACPowerMode'
        $script:helper | Should -Match 'PowerSetUserConfiguredACPowerMode'
        $script:helper | Should -Match 'ded574b5-45a0-4f42-8737-46345c09c238'
        $script:helper | Should -Match 'originalAcPowerMode'
        $script:helper | Should -Not -Match 'PowerSetUserConfiguredDCPowerMode'
        $script:helper | Should -Not -Match 'PROCTHROTTLEMIN|PROCTHROTTLEMAX|PERFEPP'
    }

    It 'targets only the requested sign-in registrations' {
        foreach ($token in @('Logitech Download Assistant','LogiLDA\.dll','MicrosoftEdgeAutoLaunch','msedge\.exe','Send to OneNote.lnk')) {
            $script:helper | Should -Match ([regex]::Escape($token))
        }
        $script:helper | Should -Match 'EdgeAutomaticLaunch'
        $script:helper | Should -Match 'LogitechDownloadAssistant'
        $script:helper | Should -Match 'SendToOneNote'
    }

    It 'makes Omnissa redirection and Cowork cleanup explicit opt-ins' {
        foreach ($token in @('IncludeOmnissaRedirection','IncludeCoworkService','ftscanmgrhv','hznsprrdpwks','USBArbService','CoworkVMService')) {
            $script:helper | Should -Match $token
        }
        $script:helper | Should -Match '\[bool\]\$IncludeOmnissaRedirection = \$false'
        $script:helper | Should -Match '\[bool\]\$IncludeCoworkService = \$false'
    }

    It 'protects Defender audio Tailscale and the core Horizon client' {
        foreach ($token in @('WinDefend','MDCoreSvc','SecurityHealthService','Audiosrv','AudioEndpointBuilder','RtkAudioUniversalService','Tailscale','client_service','ftnlsv3hv')) {
            $script:helper | Should -Match ([regex]::Escape($token))
        }
        $script:helper | Should -Match 'Test-ProtectedEquivalent'
        $script:helper | Should -Match 'ProblemDeviceCount'
    }

    It 'captures state runs internal preflight verifies and provides exact rollback' {
        foreach ($token in @('Save-NewState','internal-preflight','Test-StartupRemoved','Test-ServiceTreatment','Test-DriverTreatment','Restore-StartupRecords','Restore-ServiceRecord','Restore-HpDrivers','rolled-back','idempotent')) {
            $script:helper | Should -Match $token
        }
        $script:helper | Should -Match 'performanceClaim=\$false'
    }

    It 'does not contain broad application security update or execution-policy mutations' {
        foreach ($forbidden in @(
            'Remove-AppxPackage','Uninstall-Package','Win32_Product','Set-MpPreference','DisableRealtimeMonitoring',
            'Set-ExecutionPolicy','wuauserv.*Disabled','Audiosrv.*Disabled','Tailscale.*Disabled','client_service.*Disabled',
            'Remove-Item\s+[^\r\n]*-Recurse','powercfg\.exe\s+/setactive'
        )) { $script:helper | Should -Not -Match $forbidden }
    }

    It 'installs a recoverable System32 command launcher using only a process-scoped bypass' {
        $installer = Get-Content -LiteralPath $script:launcherInstallerPath -Raw
        foreach ($token in @('ZBookPerf.cmd','system32-backups','Copy-Item','Get-FileHash','-ExecutionPolicy Bypass','PerformanceTuneRollback')) {
            $installer | Should -Match ([regex]::Escape($token))
        }
        $installer | Should -Not -Match 'Set-ExecutionPolicy'
        $installer | Should -Not -Match 'Remove-Item\s+[^\r\n]*-Recurse'
    }
}

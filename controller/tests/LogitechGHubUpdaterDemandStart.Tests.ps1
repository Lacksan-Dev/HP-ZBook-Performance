$provider = Join-Path $PSScriptRoot '..\providers\LogitechGHubUpdaterDemandStart.ps1'
Describe 'EXP-055 Logitech G Hub updater demand-start provider contract' {
    BeforeAll { $text = Get-Content -LiteralPath $provider -Raw }
    It 'parses as PowerShell' {
        $tokens=$null;$errors=$null
        [System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)|Out-Null
        @($errors).Count | Should -Be 0
    }
    It 'declares the Experimental profile and evidence state' {
        $text | Should -Match 'EXP-055'
        $text | Should -Match 'LGHUBUpdaterService'
        $text | Should -Match 'needs-evidence'
        $text | Should -Not -Match 'status:stable|Stable='
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback') { $text | Should -Match "'$action'" }
        foreach($token in 'SupportsShouldProcess','WhatIfPreference','State overwrite refused','ConvertTo-Json -Compress','idempotent','A later boot is required','Exact rollback verification failed') { $text | Should -Match [regex]::Escape($token) }
    }
    It 'limits mutation to one exact updater service startup configuration' {
        $text | Should -Match "ServiceName='LGHUBUpdaterService'"
        $text | Should -Match 'lghub_updater\.exe'
        $text | Should -Match 'Set-Service -Name \$ServiceName -StartupType Manual'
        $text | Should -Match 'PreserveRunningState'
        $text | Should -Not -Match 'Remove-Service|sc\.exe\s+delete|pnputil|Remove-PnpDevice|Uninstall-Package|Remove-AppxPackage|dism\.exe|Disable-WindowsOptionalFeature'
    }
    It 'requires HP Windows 11 elevation exact Logitech identity and safe dependencies' {
        foreach($token in 'Windows 11 required','HP platform required','elevation required','exact LGHUBUpdaterService identity missing','display identity mismatch','executable identity mismatch','installation path identity mismatch','Logitech publisher signature invalid','driver-backed service refused','dependency-sensitive service refused') { $text | Should -Match [regex]::Escape($token) }
        foreach($token in 'Get-AuthenticodeSignature','Get-FileHash','ValidLogitech') { $text | Should -Match $token }
    }
    It 'captures registry existence type and raw delayed-start data for exact restoration' {
        foreach($token in 'RegistryStart','DelayedAutoStart','Exists=','Kind=','Data=','DoNotExpandEnvironmentNames','RegistryValueKind','capturedBootTime') { $text | Should -Match $token }
    }
    It 'captures service executable dependency and running-state identity' {
        foreach($token in 'StartMode','State=','PathName','StartName','Dependencies','Dependents','Sha256','Thumbprint','Version=','Product=','Company=') { $text | Should -Match $token }
    }
    It 'preserves management security update remote access and Logitech device-critical state' {
        foreach($token in 'enterprise management ownership detected','CcmExec','Enrollments','OMADM','WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','Win32_SystemDriver','Get-PnpDevice','LogitechDrivers','LogitechDevices') { $text | Should -Match [regex]::Escape($token) }
    }
    It 'verifies treatment immediately and after a later boot including delayed-start state' {
        $text | Should -Match 'Treatment startup mode absent'
        $text | Should -Match 'Delayed-auto-start drift detected'
        $text | Should -Match 'Treatment failed reboot persistence'
        $text | Should -Match 'Delayed-auto-start drift detected after reboot'
    }
    It 'implements drift-safe exact rollback including delayed-auto-start existence type and running state' {
        foreach($token in 'Rollback collision','Rollback refused on delayed-auto-start drift','RegistryValueKind','Remove-ItemProperty','Start-Service','Stop-Service','restoredExactOriginal') { $text | Should -Match $token }
    }
    It 'retains terminating failure evidence' {
        $text | Should -Match "Log 'failure' 'failure'"
        $text | Should -Match '\$ErrorActionPreference=''Stop'''
        $text | Should -Match 'throw'
    }
}

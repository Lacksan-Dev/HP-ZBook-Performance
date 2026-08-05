#requires -Version 5.1
BeforeAll {
    $ProviderPath = Join-Path $PSScriptRoot 'Invoke-Exp162ScheduledTaskRegistration.ps1'
    $Source = Get-Content -LiteralPath $ProviderPath -Raw
}

Describe 'EXP-162 scheduled-task provider contract' {
    It 'keeps the provider bound to EXP-162' {
        $Source | Should -Match "\$ExperimentId = 'EXP-162'"
    }

    It 'exposes the complete reversible lifecycle' {
        foreach ($token in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')) {
            $Source | Should -Match "'$token'"
        }
    }

    It 'uses ShouldProcess and disables only the selected scheduled task' {
        $Source | Should -Match 'SupportsShouldProcess'
        $Source | Should -Match 'Disable-ScheduledTask -TaskName \$TaskName -TaskPath \$TaskPath'
        $Source | Should -Not -Match 'Unregister-ScheduledTask'
        $Source | Should -Not -Match 'Remove-Item.*Task'
    }

    It 'requires logon trigger, signed executable, exact executable hash, and self-managed ownership' {
        $Source | Should -Match 'LogonTrigger'
        $Source | Should -Match 'Get-AuthenticodeSignature'
        $Source | Should -Match 'ExpectedExecutableSha256'
        $Source | Should -Match 'SelfManagedLab'
    }

    It 'refuses protected identities and Windows platform task paths' {
        foreach ($token in @('omnissa','windowsapp','remote desktop','tailscale','defender','windowsupdate','credential','recovery','driver','firmware')) {
            $Source.ToLowerInvariant() | Should -Match [regex]::Escape($token)
        }
        $Source | Should -Match "\\Microsoft\\Windows\\\*"
    }

    It 'captures exact XML plus structural hash and verifies exact XML on rollback' {
        $Source | Should -Match 'Export-ScheduledTask'
        $Source | Should -Match 'xmlHash'
        $Source | Should -Match 'structuralHash'
        $Source | Should -Match '\$after\.xmlHash -ne \$state\.original\.xmlHash'
        $Source | Should -Match 'rollback refused'
    }

    It 'separates protected runtime evidence from configuration drift gating' {
        $Source | Should -Match 'Get-ProtectedConfiguration'
        $Source | Should -Match 'Get-ProtectedRuntimeEvidence'
        $Source | Should -Match 'Assert-ProtectedConfigurationUnchanged'
        $Source | Should -Not -Match 'Assert-ProtectedRuntime'
    }

    It 'records structured JSONL success and failure evidence' {
        $Source | Should -Match 'ConvertTo-Json -Depth 12 -Compress'
        $Source | Should -Match 'Add-Content -LiteralPath \$LogPath'
        $Source | Should -Match 'Write-Log \$Action failure'
    }

    It 'requires a later boot for reboot persistence verification' {
        $Source | Should -Match "A later boot has not occurred"
    }

    It 'does not alter services, drivers, packages, files, registry, or security configuration' {
        $Source | Should -Not -Match '\bSet-Service\b'
        $Source | Should -Not -Match '\bsc\.exe\b'
        $Source | Should -Not -Match '\bpnputil\b'
        $Source | Should -Not -Match '\bRemove-AppxPackage\b'
        $Source | Should -Not -Match '\bSet-ItemProperty\b'
        $Source | Should -Not -Match '\bRemove-ItemProperty\b'
        $Source | Should -Not -Match '\bNew-NetFirewallRule\b'
    }
}

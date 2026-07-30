BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\Invoke-LogitechDownloadAssistantCalibration.ps1'
    $content = Get-Content -LiteralPath $scriptPath -Raw
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors) | Out-Null
}

Describe 'EXP-080 Logitech Download Assistant calibration contract' {
    It 'has valid PowerShell syntax' {
        $errors.Count | Should -Be 0
    }

    It 'exposes the complete action contract' {
        foreach ($action in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')) {
            $content | Should -Match ([regex]::Escape("'$action'"))
        }
    }

    It 'supports ShouldProcess and dry run' {
        $content | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
        $content | Should -Match 'ShouldProcess'
        $content | Should -Match "'DryRun'"
    }

    It 'captures exact registry identity and unexpanded value data' {
        foreach ($term in @('DoNotExpandEnvironmentNames','GetValueKind','userSid','Executable','PublisherSubject','capturedUtc')) {
            $content | Should -Match ([regex]::Escape($term))
        }
    }

    It 'requires Logitech publisher validation' {
        $content | Should -Match 'Get-AuthenticodeSignature'
        $content | Should -Match "Status -eq 'Valid'"
        $content | Should -Match '\(Logitech\|Logi\)'
    }

    It 'refuses enterprise management signals' {
        foreach ($term in @('DomainJoined','Microsoft\\Enrollments','PolicyManager','CcmExec','mutation is refused')) {
            $content | Should -Match ([regex]::Escape($term))
        }
    }

    It 'preserves protected startup identities by explicit refusal' {
        foreach ($term in @('omnissa','windows app','remote desktop','tailscale','defender','credential','bitlocker','firewall','windows update','recovery')) {
            $content.ToLowerInvariant() | Should -Match ([regex]::Escape($term))
        }
    }

    It 'limits mutation to one Run registry value' {
        $content | Should -Match 'Remove-ItemProperty'
        $content | Should -Match '\.SetValue\('
        $content | Should -Not -Match 'Remove-AppxPackage|Uninstall-Package|pnputil|Disable-PnpDevice|sc\.exe|Set-Service|Disable-ScheduledTask|Remove-Item\s+-Recurse'
    }

    It 'implements structured JSONL logging and terminating failure handling' {
        $content | Should -Match 'ConvertTo-Json -Compress'
        $content | Should -Match 'events\.jsonl'
        $content | Should -Match "Write-ExpLog 'failure' 'fail'"
        $content | Should -Match '\$ErrorActionPreference\s*=\s*''Stop'''
    }

    It 'implements idempotent apply and exact rollback verification' {
        $content | Should -Match "'idempotent'"
        $content | Should -Match 'Rollback refused because the registry value already exists'
        $content | Should -Match 'Test-Restored'
        $content | Should -Match 'Rollback verification failed'
    }

    It 'includes reboot persistence verification' {
        $content | Should -Match 'VerifyReboot'
        $content | Should -Match 'LastBootUpTime'
        $content | Should -Match 'Reboot persistence verification failed'
    }
}

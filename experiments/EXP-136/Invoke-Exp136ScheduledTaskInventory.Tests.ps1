$sut = Join-Path $PSScriptRoot 'Invoke-Exp136ScheduledTaskInventory.ps1'
$source = Get-Content -LiteralPath $sut -Raw

Describe 'EXP-136 scheduled task inventory contract' {
    It 'is explicitly zero mutation during research selection' {
        $source | Should -Match "mutationAllowed = \$false"
        $source | Should -Match "ValidateSet\('Check','Capture','DryRun','Select'\)"
        $source | Should -Not -Match 'Disable-ScheduledTask'
        $source | Should -Not -Match 'Enable-ScheduledTask'
        $source | Should -Not -Match 'Register-ScheduledTask'
        $source | Should -Not -Match 'Unregister-ScheduledTask'
    }

    It 'requires Windows 11 support detection' {
        $source | Should -Match 'Win32_OperatingSystem'
        $source | Should -Match 'Windows 11 required'
    }

    It 'captures exact task XML and identity evidence' {
        $source | Should -Match 'Export-ScheduledTask'
        $source | Should -Match 'xmlSha256'
        $source | Should -Match 'Get-AuthenticodeSignature'
        $source | Should -Match 'Get-FileHash'
        $source | Should -Match 'fileVersion'
        $source | Should -Match 'productName'
        $source | Should -Match 'publisher'
        $source | Should -Match 'lastTaskResult'
        $source | Should -Match 'nextRunTime'
    }

    It 'restricts inventory to user logon triggers' {
        $source | Should -Match 'MSFT_TaskLogonTrigger'
        $source | Should -Match 'delay'
    }

    It 'checks enterprise ownership and protected scope' {
        $source | Should -Match 'PolicyManager'
        $source | Should -Match 'Microsoft\\Enrollments'
        $source | Should -Match 'CcmExec'
        $source | Should -Match 'domainJoined'
        $source | Should -Match 'omnissa'
        $source | Should -Match 'tailscale'
        $source | Should -Match 'defender'
        $source | Should -Match 'windows update'
        $source | Should -Match 'credential'
        $source | Should -Match 'accessibility'
        $source | Should -Match 'driver'
    }

    It 'excludes product families with focused experiments' {
        $source | Should -Match 'office'
        $source | Should -Match 'microsoft 365'
        $source | Should -Match 'teams'
        $source | Should -Match 'logi'
        $source | Should -Match 'logitech'
    }

    It 'requires valid signed single-action user applications' {
        $source | Should -Match "signatureStatus -eq 'Valid'"
        $source | Should -Match 'singleAction'
        $source | Should -Match 'resolvedCount -eq 1'
        $source | Should -Match 'signedCount -eq 1'
    }

    It 'keeps missing physical attribution as needs-evidence' {
        $source | Should -Match 'needsEvidence = \$true'
        $source | Should -Match 'needs-physical-attribution'
        $source | Should -Match 'at least five physical attribution trials'
        $source | Should -Match 'trials -lt 5'
    }

    It 'preserves structured JSONL failure evidence' {
        $source | Should -Match 'ConvertTo-Json -Depth 12 -Compress'
        $source | Should -Match "Write-EvidenceLog \$Action 'fail'"
        $source | Should -Match 'refusalReason'
        $source | Should -Match 'failureDetail'
        $source | Should -Match 'throw'
    }

    It 'supports dry run and ShouldProcess semantics' {
        $source | Should -Match 'SupportsShouldProcess=\$true'
        $source | Should -Match 'ShouldProcess'
        $source | Should -Match "action='DryRun'"
        $source | Should -Match 'wouldMutate=\$false'
    }

    It 'refuses ambiguous top physical attribution' {
        $source | Should -Match 'Highest-cost attribution is ambiguous'
        $source | Should -Match 'No eligible task has at least five qualifying physical attribution trials'
    }
}

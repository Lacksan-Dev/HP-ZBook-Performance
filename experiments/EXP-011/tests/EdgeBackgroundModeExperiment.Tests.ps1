BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot '..\EdgeBackgroundModeExperiment.ps1'
    $text = Get-Content $scriptPath -Raw
}

Describe 'EXP-011 Edge background mode contract' {
    It 'supports the required operating modes' {
        $text | Should -Match "ValidateSet\('Check','DryRun','Apply','Verify','Rollback','VerifyRollback'\)"
    }

    It 'uses the recommended policy path' {
        $text | Should -Match 'Edge\\Recommended'
    }

    It 'refuses mandatory policy override' {
        $text | Should -Match 'MandatoryPolicyPresent'
        $text | Should -Match 'mandatory BackgroundModeEnabled policy present'
    }

    It 'captures state before application' {
        $text | Should -Match 'Save-OriginalState'
        $text | Should -Match 'Get-CurrentState'
    }

    It 'implements ShouldProcess and structured JSONL logging' {
        $text | Should -Match 'SupportsShouldProcess'
        $text | Should -Match 'ConvertTo-Json -Compress'
    }

    It 'sets only BackgroundModeEnabled to zero' {
        $text | Should -Match "ValueName = 'BackgroundModeEnabled'"
        $text | Should -Match 'PropertyType DWord -Value 0'
    }

    It 'implements exact rollback and rollback verification' {
        $text | Should -Match 'Restore-OriginalState'
        $text | Should -Match 'VerifyRollback'
        $text | Should -Match 'Rollback verification failed'
    }

    It 'contains no commands that uninstall packages, disable security, or modify services' {
        $text | Should -Not -Match 'Uninstall-Package|Remove-AppxPackage|Set-Service|Stop-Service|Disable-WindowsOptionalFeature|Set-MpPreference'
    }
}

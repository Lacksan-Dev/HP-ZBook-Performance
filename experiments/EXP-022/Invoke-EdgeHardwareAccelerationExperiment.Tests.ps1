BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot 'Invoke-EdgeHardwareAccelerationExperiment.ps1'
    $scriptText = Get-Content -LiteralPath $scriptPath -Raw
}

Describe 'EXP-022 engineering contract' {
    It 'uses ShouldProcess for live changes' {
        $scriptText | Should -Match 'SupportsShouldProcess=\$true'
        $scriptText | Should -Match '\$PSCmdlet\.ShouldProcess'
    }

    It 'refuses mandatory Edge policy precedence' {
        $scriptText | Should -Match 'Mandatory enterprise policy controls HardwareAccelerationModeEnabled'
        $scriptText | Should -Match 'Assert-MandatoryPolicyAbsent'
    }

    It 'captures exact original policy state' {
        $scriptText | Should -Match 'DoNotExpandEnvironmentNames'
        $scriptText | Should -Match 'GetValueKind'
        $scriptText | Should -Match 'schemaVersion=1'
    }

    It 'implements dry run, verification, idempotence, reboot verification, and rollback' {
        $scriptText | Should -Match "ValidateSet\('Capture','Apply','Verify','Rollback','VerifyReboot'\)"
        $scriptText | Should -Match 'apply-idempotent'
        $scriptText | Should -Match 'verify-reboot'
        $scriptText | Should -Match 'Rollback existence verification failed'
    }

    It 'writes structured JSONL evidence' {
        $scriptText | Should -Match 'ConvertTo-Json -Compress'
        $scriptText | Should -Match 'Add-Content -LiteralPath \$LogPath'
    }

    It 'limits support to HP Windows 11 systems with Edge installed' {
        $scriptText | Should -Match 'Windows 11'
        $scriptText | Should -Match 'HP\|Hewlett'
        $scriptText | Should -Match 'msedge\.exe'
    }
}

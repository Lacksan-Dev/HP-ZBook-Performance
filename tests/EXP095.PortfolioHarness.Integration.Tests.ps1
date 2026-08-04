Describe 'EXP-095 portfolio harness integration surface' -Tag 'Integration' {
    BeforeAll {
        $script:HarnessPath = Join-Path $PSScriptRoot '../experiments/EXP-095/Invoke-Exp095LabHarness.ps1'
        $script:HarnessText = Get-Content -LiteralPath $script:HarnessPath -Raw
    }

    It 'parses the portfolio harness without PowerShell syntax errors' {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($HarnessPath,[ref]$tokens,[ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }

    It 'builds a continuation command that preserves the same reboot authorization boundary' {
        $HarnessText | Should -Match 'RegisterResume'
        $HarnessText | Should -Match '-Action Continue'
        $HarnessText | Should -Match '\$automaticRebootArgument'
        $HarnessText | Should -Match '-AllowAutomaticReboot'
        $HarnessText | Should -Match 'ShouldProcess\(\$TaskName'
    }

    It 'keeps continuation cleanup and rollback reachable after treatment completion' {
        $HarnessText | Should -Match 'InvokePhase Summarize'
        $HarnessText | Should -Match 'InvokePhase Rollback'
        $HarnessText | Should -Match 'RemoveResume'
        $HarnessText | Should -Match 'Remove-Item \$ActivePointer -Force'
    }
}

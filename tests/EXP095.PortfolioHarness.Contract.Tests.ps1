Describe 'EXP-095 portfolio harness reboot continuation contract' {
    BeforeAll {
        $path = Join-Path $PSScriptRoot '../experiments/EXP-095/Invoke-Exp095LabHarness.ps1'
        $text = Get-Content -LiteralPath $path -Raw
    }

    It 'keeps automatic reboot behind explicit opt-in' {
        $text | Should -Match '\[switch\]\$AllowAutomaticReboot'
        $text | Should -Match 'if\(\$AllowAutomaticReboot\)'
        $text | Should -Match 'Restart-Computer -Force'
    }

    It 'propagates automatic reboot opt-in into the scheduled continuation command' {
        $text | Should -Match '\$automaticRebootArgument=if\(\$AllowAutomaticReboot\)'
        $text | Should -Match "' -AllowAutomaticReboot'"
        $text | Should -Match '\$ValidationPath`"\$automaticRebootArgument'
    }

    It 'does not authorize reboot when the opt-in is absent' {
        $text | Should -Match "else\{''\}"
        $text | Should -Match "'reboot-required' 'needs-evidence'"
    }

    It 'retains exact rollback and duplicate-boot refusal' {
        $text | Should -Match 'InvokePhase Rollback'
        $text | Should -Match 'Duplicate collection from same boot refused'
        $text | Should -Match 'RemoveResume'
    }
}

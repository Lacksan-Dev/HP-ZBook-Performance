$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp124LabHarness.ps1'
Describe 'EXP-124 reboot-aware lab harness contract' {
    BeforeAll {$text=Get-Content -LiteralPath $scriptPath -Raw}
    It 'parses as PowerShell' {
        $tokens=$null;$errors=$null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)|Out-Null
        @($errors).Count|Should -Be 0
    }
    It 'defaults to five matched baseline and treatment runs and 120 second sampling' {
        $text|Should -Match "RunsPerArm=5"
        $text|Should -Match "SampleSeconds=120"
        $text|Should -Match "'Baseline','Treatment'"
    }
    It 'delegates the only experimental Run mutation to the merged EXP-124 provider' {
        $text|Should -Match 'Microsoft365RunDemandLaunch\.ps1'
        $text|Should -Match "Invoke-Provider 'Capture'"
        $text|Should -Match "Invoke-Provider 'Apply'"
        $text|Should -Match "Invoke-Provider 'Verify'"
        $text|Should -Match "Invoke-Provider 'VerifyReboot'"
        $text|Should -Match "Invoke-Provider 'Rollback'"
        $text|Should -Not -Match 'Remove-ItemProperty'
        $text|Should -Not -Match 'Set-ItemProperty'
    }
    It 'requires a unique reboot for every collected trial' {
        $text|Should -Match 'Duplicate collection from the same boot refused'
        $text|Should -Match 'lastBootUtc'
        $text|Should -Match 'Get-BootUtc'
    }
    It 'verifies exact baseline treatment and post-rollback registration states' {
        $text|Should -Match 'Assert-BaselineRegistration'
        $text|Should -Match 'Assert-TreatmentRegistration'
        $text|Should -Match "phase='RollbackVerify'"
        $text|Should -Match 'rollbackRebootVerified'
    }
    It 'uses a reversible current-user continuation task without credentials or autologon' {
        $text|Should -Match 'New-ScheduledTaskTrigger -AtLogOn'
        $text|Should -Match 'LogonType Interactive'
        $text|Should -Match 'Unregister-ScheduledTask'
        $text|Should -Not -Match '(?i)autologon|password|credential'
    }
    It 'retains raw runs and computes medians plus median absolute deviation' {
        $text|Should -Match 'run-\{0\}-\{1:D2\}\.json'
        $text|Should -Match 'Get-Median'
        $text|Should -Match 'Get-Mad'
        $text|Should -Match 'summary\.json'
    }
    It 'records protected scope and keeps remaining physical function checks as needs-evidence' {
        foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','ClickToRunSvc','Tailscale','TermService','omnissa','windowsapp'){$text|Should -Match ([regex]::Escape($token))}
        foreach($token in 'manualOfficeLaunch','clickToRunServicing','activationDocumentsAddins','protectedApplicationConnectionReadiness'){$text|Should -Match ([regex]::Escape($token))}
        $text|Should -Match 'needs-evidence'
    }
    It 'keeps automatic reboot behind explicit opt-in and supports WhatIf' {
        $text|Should -Match 'AllowAutomaticReboot'
        $text|Should -Match 'WhatIfPreference'
        $text|Should -Match 'SupportsShouldProcess'
    }
    It 'preserves failure evidence through terminating errors and structured JSONL events' {
        $text|Should -Match "ErrorActionPreference='Stop'"
        $text|Should -Match 'lab-events\.jsonl'
        $text|Should -Match 'provider-events\.jsonl'
    }
}

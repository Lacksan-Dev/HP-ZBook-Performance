$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp125LabHarness.ps1'
Describe 'EXP-125 reboot-aware lab harness contract' {
    BeforeAll {$text=Get-Content -LiteralPath $scriptPath -Raw}
    It 'parses as PowerShell' {
        $tokens=$null;$errors=$null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)|Out-Null
        @($errors).Count|Should -Be 0
    }
    It 'defaults to five matched baseline and treatment runs and 120 second sampling' {
        $text|Should -Match 'RunsPerArm=5'
        $text|Should -Match 'SampleSeconds=120'
        $text|Should -Match "'Baseline','Treatment'"
    }
    It 'delegates the experimental Teams mutation to the merged EXP-125 provider' {
        $text|Should -Match 'MicrosoftTeamsSigninTask\.ps1'
        foreach($action in 'Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match ("Invoke-Provider '"+$action+"'")}
        $text|Should -Not -Match 'Disable-ScheduledTask'
        $text|Should -Not -Match 'Enable-ScheduledTask'
    }
    It 'requires a distinct boot for every collected trial' {
        $text|Should -Match 'Duplicate collection from the same boot refused'
        $text|Should -Match 'lastBootUtc'
        $text|Should -Match 'Get-BootUtc'
    }
    It 'verifies baseline treatment reboot persistence and rollback reboot state' {
        $text|Should -Match 'Assert-BaselineTask'
        $text|Should -Match 'Assert-TreatmentTask'
        $text|Should -Match "phase='RollbackVerify'"
        $text|Should -Match 'rollbackRebootVerified'
    }
    It 'uses one reversible interactive-logon continuation task without stored secrets' {
        $text|Should -Match 'New-ScheduledTaskTrigger -AtLogOn'
        $text|Should -Match 'LogonType Interactive'
        $text|Should -Match 'Unregister-ScheduledTask'
        $text|Should -Not -Match '(?i)autologon|password='
    }
    It 'retains raw runs and summarizes medians plus median absolute deviation' {
        $text|Should -Match 'run-\{0\}-\{1:D2\}\.json'
        $text|Should -Match 'Get-Median'
        $text|Should -Match 'Get-Mad'
        $text|Should -Match 'summary\.json'
    }
    It 'records protected scope and explicit remaining physical evidence' {
        foreach($token in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','TermService','omnissa','windowsapp'){$text|Should -Match ([regex]::Escape($token))}
        foreach($token in 'manualTeamsLaunch','teamsSignIn','messagingOrMeetingReadiness','teamsServicingReadiness','protectedApplicationConnectionReadiness'){$text|Should -Match ([regex]::Escape($token))}
        $text|Should -Match 'needs-evidence'
    }
    It 'gates automatic reboot behind explicit opt-in and supports WhatIf' {
        $text|Should -Match 'AllowAutomaticReboot'
        $text|Should -Match 'WhatIfPreference'
        $text|Should -Match 'SupportsShouldProcess'
    }
    It 'preserves terminating failure evidence in structured logs' {
        $text|Should -Match "ErrorActionPreference='Stop'"
        $text|Should -Match 'lab-events\.jsonl'
        $text|Should -Match 'provider-events\.jsonl'
        $text|Should -Match 'failureDetail'
        $text|Should -Match 'refusalReason'
    }
}

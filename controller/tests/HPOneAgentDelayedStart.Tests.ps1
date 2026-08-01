$provider=Join-Path $PSScriptRoot '..\providers\HPOneAgentDelayedStart.ps1'
Describe 'EXP-101 HPOneAgentDelayedStart provider contract' {
    BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
    It 'parses as PowerShell' {
        $tokens=$null;$errors=$null
        [void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)
        $errors.Count | Should -Be 0
    }
    It 'implements the complete reversible lifecycle' {
        foreach($action in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text | Should -Match "'$action'"}
    }
    It 'uses ShouldProcess and supports WhatIf' {
        $text | Should -Match 'SupportsShouldProcess\s*=\s*\$true'
        $text | Should -Match '\$PSCmdlet\.ShouldProcess'
        $text | Should -Match '\$WhatIfPreference'
    }
    It 'requires HP Windows 11 elevation and refuses management ownership' {
        $text | Should -Match 'Windows 11'
        $text | Should -Match 'Hewlett-Packard'
        $text | Should -Match 'Test-Elevated'
        $text | Should -Match 'DomainJoined'
        $text | Should -Match 'MdmEnrollments'
        $text | Should -Match 'PolicyManager'
        $text | Should -Match 'ConfigMgr'
        $text | Should -Match 'IntuneManagementExtension'
    }
    It 'discovers HP One Agent service identity dynamically' {
        $text | Should -Match '\^HP One Agent Service\$'
        $text | Should -Match 'Resolve-ServiceExecutable'
        $text | Should -Match 'Get-AuthenticodeSignature'
        $text | Should -Match 'HP Inc\|Hewlett-Packard'
        $text | Should -Match 'Get-FileHash'
    }
    It 'enforces the June 2026 HP security floor' {
        $text | Should -Match "1\.3\.214\.7339"
        $text | Should -Match 'HPSBHF04060 Rev\. 1'
        $text | Should -Match 'SecurityFloorMet'
    }
    It 'captures dependency package recovery trigger and repair task evidence' {
        $text | Should -Match 'Dependencies'
        $text | Should -Match 'Dependents'
        $text | Should -Match 'qfailure'
        $text | Should -Match 'qtriggerinfo'
        $text | Should -Match 'Get-PackageInventory'
        $text | Should -Match 'Get-OneAgentTasks'
        $text | Should -Match 'HpOneAgent'
        $text | Should -Match 'taskHash'
    }
    It 'refuses enabled repair or update task interference' {
        $text | Should -Match 'RepairOrUpdate'
        $text | Should -Match 'may overwrite treatment'
    }
    It 'mutates startup timing only through the service control interface' {
        $text | Should -Match 'sc\.exe config'
        $text | Should -Match "'delayed-auto'"
        $text | Should -Match "'auto'"
        $text | Should -Not -Match 'Remove-Service'
        $text | Should -Not -Match 'Uninstall-Package'
        $text | Should -Not -Match 'pnputil'
    }
    It 'captures and protects security update and remote access state' {
        foreach($identity in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','omnissa','msrdc','mstsc'){$text | Should -Match $identity}
        $text | Should -Match 'protectedScopeHash'
    }
    It 'implements state overwrite refusal identity binding and drift refusal' {
        $text | Should -Match 'State overwrite refused'
        $text | Should -Match 'userSid'
        $text | Should -Match 'machine'
        $text | Should -Match 'dependencyHash'
        $text | Should -Match 'taskHash'
        $text | Should -Match 'Service, executable, or version drift detected'
    }
    It 'preserves running state during application and restores captured state' {
        $text | Should -Match 'runningStatePreserved'
        $text | Should -Match 'Start-Service'
        $text | Should -Match 'Stop-Service'
        $text | Should -Match 'Rollback verification failed'
    }
    It 'requires a later boot for persistence verification' {
        $text | Should -Match 'capturedBootTime'
        $text | Should -Match 'A later boot is required'
        $text | Should -Match 'Reboot persistence'
    }
    It 'writes structured JSONL evidence including terminating failures' {
        $text | Should -Match 'ConvertTo-Json -Compress'
        $text | Should -Match 'Add-Content'
        $text | Should -Match "'failure' 'failed'"
        $text | Should -Match 'ScriptStackTrace'
    }
    It 'keeps Experimental identity explicit' {
        $text | Should -Match "\$experiment='EXP-101'"
        $text | Should -Match "\$profile='HPOneAgentDelayedStart'"
        $text | Should -Not -Match 'Stable'
    }
}

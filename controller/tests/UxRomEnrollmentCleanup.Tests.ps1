$sut = Join-Path (Split-Path $PSScriptRoot -Parent) 'maintenance\UxRomEnrollmentCleanup.ps1'
$source = Get-Content -LiteralPath $sut -Raw

Describe 'EXP-137 UX-ROM self-managed enrollment cleanup contract' {
    It 'supports capture cleanup reboot resume and local rollback' {
        $source | Should -Match "ValidateSet\('Start','Resume','Check','Rollback'\)"
        $source | Should -Match 'Get-DsRegSnapshot'
        $source | Should -Match 'Get-EnrollmentInventory'
        $source | Should -Match 'Register-ResumeTask'
        $source | Should -Match 'Restart-Computer -Force'
        $source | Should -Match 'Invoke-Resume'
        $source | Should -Match 'Invoke-Rollback'
    }

    It 'classifies active and residual enrollment records' {
        $source | Should -Match 'active-or-correlated-enrollment'
        $source | Should -Match 'residual-enrollment-record'
        $source | Should -Match 'residual-enterprisemgmt-task'
        $source | Should -Match 'EnterpriseMgmtTasks'
        $source | Should -Match 'OmadmAccounts'
        $source | Should -Match 'WorkplaceJoin'
    }

    It 'captures registry and scheduled-task rollback artifacts before deletion' {
        $source | Should -Match 'reg.exe'
        $source | Should -Match "'export'"
        $source | Should -Match 'Export-ScheduledTask'
        $source | Should -Match 'taskBackups'
        $source | Should -Match 'registryBackups'
    }

    It 'limits the automatic identity cleanup boundary' {
        $source | Should -Match 'domainJoined'
        $source | Should -Match 'azureAdJoined'
        $source | Should -Match 'enterpriseJoined'
        $source | Should -Match 'outside this cleanup scope'
        $source | Should -Match "dsregcmd.exe'.*'/leave'"
    }

    It 'cleans captured EnterpriseMgmt and self-managed MDM auto-enrollment state' {
        $source | Should -Match 'rootEnrollmentTaskCandidate'
        $source | Should -Match 'AutoEnrollMDM'
        $source | Should -Match 'UseAADCredentialType'
        $source | Should -Match 'Remove-MdmAutoEnrollPolicy'
    }

    It 'preserves Windows Update Defender Edge Update and Edge profile data from direct mutation' {
        $source | Should -Match 'WinDefend'
        $source | Should -Match 'wuauserv'
        $source | Should -Match 'edgeupdate'
        $source | Should -Match 'Microsoft Edge User Data'
        $source | Should -Match 'passwords, profiles, cookies, favorites, history and extensions'
        $source | Should -Not -Match 'Remove-Item.*Microsoft\\Edge\\User Data'
        $source | Should -Not -Match 'Set-MpPreference'
        $source | Should -Not -Match 'Remove-MpPreference'
        $source | Should -Not -Match 'Stop-Service.*wuauserv'
    }

    It 'reruns EXP-071 before reboot and verifies persistence after reboot' {
        $source | Should -Match 'Invoke-Exp071PreReboot'
        $source | Should -Match "-Action Check"
        $source | Should -Match "-Action Capture"
        $source | Should -Match "-Action DryRun"
        $source | Should -Match "-Action Apply"
        $source | Should -Match "-Action Verify"
        $source | Should -Match "-Action VerifyReboot"
    }

    It 'retains structured evidence' {
        $source | Should -Match 'ConvertTo-Json -Depth 16 -Compress'
        $source | Should -Match 'events.jsonl'
        $source | Should -Match '\$Label-dsregcmd\.txt'
        $source | Should -Match "Get-DsRegSnapshot 'before'"
        $source | Should -Match "Get-DsRegSnapshot 'after-reboot'"
    }
}

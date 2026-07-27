BeforeAll {
    Import-Module "$PSScriptRoot/../experiments/EXP-009/SendToOneNoteStartup.psm1" -Force
}

Describe 'EXP-009 Send to OneNote startup calibration' {
    InModuleScope SendToOneNoteStartup {
        BeforeEach {
            Mock Get-CimInstance {
                param($ClassName)
                if ($ClassName -eq 'Win32_OperatingSystem') { [pscustomobject]@{ Caption='Microsoft Windows 11 Pro'; BuildNumber='26100' } }
                else { [pscustomobject]@{ Manufacturer='HP'; Model='HP ZBook Firefly 14 G8' } }
            }
        }

        It 'supports HP Windows 11 systems' {
            (Get-Exp009Support).Supported | Should -BeTrue
        }

        It 'rejects non-HP systems' {
            Mock Get-CimInstance {
                param($ClassName)
                if ($ClassName -eq 'Win32_OperatingSystem') { [pscustomobject]@{ Caption='Microsoft Windows 11 Pro'; BuildNumber='26100' } }
                else { [pscustomobject]@{ Manufacturer='Other'; Model='Workstation' } }
            }
            (Get-Exp009Support).Supported | Should -BeFalse
        }

        It 'exports the required engineering contract' {
            $required = @('Get-Exp009Support','Get-Exp009Candidate','Invoke-Exp009DryRun','Save-Exp009State','Remove-Exp009Shortcut','Test-Exp009Applied','Test-Exp009RebootPersistence','Restore-Exp009Shortcut','Test-Exp009Rollback')
            foreach ($name in $required) { Get-Command $name -ErrorAction Stop | Should -Not -BeNullOrEmpty }
        }

        It 'uses ShouldProcess for apply and rollback' {
            (Get-Command Remove-Exp009Shortcut).CmdletBinding | Should -BeTrue
            (Get-Command Restore-Exp009Shortcut).CmdletBinding | Should -BeTrue
        }

        It 'rejects rollback state from another experiment' {
            Mock Get-Content { '{"SchemaVersion":1,"Experiment":"OTHER"}' }
            { Restore-Exp009Shortcut -StatePath 'state.json' -LogPath 'log.jsonl' -Confirm:$false } | Should -Throw '*identity mismatch*'
        }
    }
}

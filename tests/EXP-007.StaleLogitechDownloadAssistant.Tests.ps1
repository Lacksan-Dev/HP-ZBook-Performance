$modulePath = Join-Path $PSScriptRoot '..\experiments\EXP-007\StaleLogitechDownloadAssistant.psm1'
Import-Module $modulePath -Force

Describe 'EXP-007 stale Logitech Download Assistant calibration' {
    InModuleScope StaleLogitechDownloadAssistant {
        BeforeEach {
            Mock Get-CimInstance {
                param($ClassName)
                if ($ClassName -eq 'Win32_OperatingSystem') { return [pscustomobject]@{ Caption='Microsoft Windows 11 Pro'; BuildNumber='26100' } }
                return [pscustomobject]@{ Manufacturer='HP'; Model='HP ZBook Firefly 14 G8' }
            }
        }

        It 'supports HP Windows 11 systems' {
            (Get-Exp007Support).Supported | Should -BeTrue
        }

        It 'refuses a mismatched command identity in dry run' {
            Mock Test-Path { $true }
            Mock Get-Item {
                $key = New-Object psobject
                $key | Add-Member ScriptMethod GetValue { 'C:\Other\helper.exe' }
                $key | Add-Member ScriptMethod GetValueKind { [Microsoft.Win32.RegistryValueKind]::String }
                $key
            }
            $result = Invoke-Exp007DryRun
            $result.WouldChange | Should -BeFalse
            $result.Reason | Should -Be 'Command identity mismatch'
        }

        It 'selects only the exact LogiLDA candidate' {
            Mock Test-Path { $true }
            Mock Get-Item {
                $key = New-Object psobject
                $key | Add-Member ScriptMethod GetValue { 'C:\Windows\System32\rundll32.exe C:\Windows\System32\LogiLDA.dll,LogiFetch' }
                $key | Add-Member ScriptMethod GetValueKind { [Microsoft.Win32.RegistryValueKind]::String }
                $key
            }
            $result = Invoke-Exp007DryRun
            $result.WouldChange | Should -BeTrue
            $result.CurrentState.IdentityMatches | Should -BeTrue
        }

        It 'treats an absent registration as idempotent no-change' {
            Mock Test-Path { $false }
            Mock Write-Exp007Log {}
            $result = Remove-Exp007Registration -StatePath 'state.json' -LogPath 'log.jsonl' -Confirm:$false
            $result.Exists | Should -BeFalse
            Assert-MockCalled Write-Exp007Log -Times 1
        }

        It 'rejects rollback state for another registry identity' {
            Mock Test-Path { $true }
            Mock Get-Content { '{"registry":{"path":"HKLM:\\Other","name":"Other","exists":false}}' }
            { Restore-Exp007Registration -StatePath 'state.json' -LogPath 'log.jsonl' -Confirm:$false } | Should -Throw '*identity mismatch*'
        }
    }
}

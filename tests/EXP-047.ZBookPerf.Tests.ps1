Describe 'EXP-047 ZBookPerf' {
    BeforeAll {
        $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'ZBookPerf.ps1'
        . $scriptPath
    }

    Context 'static contract' {
        It 'parses without PowerShell syntax errors' {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It 'declares the ShouldProcess contract' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'WhatIf') | Should -BeTrue
            ($command.Parameters.Keys -contains 'Confirm') | Should -BeTrue
        }

        It 'keeps security and management exclusions out of mutation commands' {
            $content = Get-Content -LiteralPath $scriptPath -Raw
            $content | Should -Not -Match 'Set-MpPreference'
            $content | Should -Not -Match 'Disable-WindowsOptionalFeature'
            $content | Should -Not -Match 'bcdedit'
            $content | Should -Not -Match 'powercfg(?:\.exe)?\s+/hibernate\s+off'
            $content | Should -Not -Match 'Remove-WindowsDriver'
        }
    }

    Context 'console chart helpers' {
        It 'renders a bounded horizontal bar' {
            (New-HorizontalBar -Value 50 -Maximum 100 -Width 10) | Should -Be '#####-----'
            (New-HorizontalBar -Value 150 -Maximum 100 -Width 4) | Should -Be '####'
            (New-HorizontalBar -Value -10 -Maximum 100 -Width 4) | Should -Be '----'
        }

        It 'renders a monotonic sparkline without depending on a Unicode source encoding' {
            $sparkline = ConvertTo-Sparkline -Values @(0, 25, 50, 75, 100)
            $sparkline.Length | Should -Be 5
            [int][char]$sparkline[0] | Should -Be 0x2581
            [int][char]$sparkline[4] | Should -Be 0x2588
        }

        It 'handles an empty sparkline' {
            (ConvertTo-Sparkline -Values @()) | Should -Be ''
        }
    }

    Context 'change journal serialization' {
        It 'round-trips original state needed for rollback' {
            $input = [pscustomobject][ordered]@{
                schemaVersion = 1
                experimentId = 'EXP-047'
                computerName = 'LAB'
                entries = @(
                    [pscustomobject][ordered]@{
                        id = 'entry-1'
                        candidate = 'MmcssResponsiveness'
                        status = 'applied'
                        original = [pscustomobject][ordered]@{
                            Path = 'HKLM:\Example'
                            Name = 'Value'
                            Exists = $true
                            Kind = 'DWord'
                            Value = 20
                        }
                    }
                )
            }

            $roundTrip = ConvertFrom-ChangeLogJson -Json (ConvertTo-ChangeLogJson -InputObject $input)
            $roundTrip.schemaVersion | Should -Be 1
            $roundTrip.entries.Count | Should -Be 1
            $roundTrip.entries[0].original.Path | Should -Be 'HKLM:\Example'
            $roundTrip.entries[0].original.Kind | Should -Be 'DWord'
            $roundTrip.entries[0].original.Value | Should -Be 20
        }

        It 'rejects an empty journal payload' {
            { ConvertFrom-ChangeLogJson -Json '' } | Should -Throw
        }
    }

    Context 'dry-run boundary' {
        It 'does not journal or apply the per-user candidate under WhatIf' {
            $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("zbookperf-test-" + [guid]::NewGuid().ToString('N'))
            try {
                & $scriptPath -Action Enhance -Candidate VisualEffects -DataRoot $temporaryRoot -WhatIf
                Test-Path -LiteralPath (Join-Path $temporaryRoot 'changes.json') | Should -BeFalse
            } finally {
                if (Test-Path -LiteralPath $temporaryRoot) {
                    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
                }
            }
        }

        It 'refuses a confirmed application when baseline evidence is absent' {
            $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("zbookperf-test-" + [guid]::NewGuid().ToString('N'))
            try {
                { Invoke-Enhancement -Name VisualEffects -Root $temporaryRoot -Confirm:$false } | Should -Throw '*No baseline session exists*'
                Test-Path -LiteralPath (Join-Path $temporaryRoot 'changes.json') | Should -BeFalse
            } finally {
                if (Test-Path -LiteralPath $temporaryRoot) {
                    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
                }
            }
        }
    }
}

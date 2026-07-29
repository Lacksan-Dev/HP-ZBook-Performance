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

        It 'preserves the public Candidate parameter without using the Invoke-Expression collision name internally' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'EnhancementCandidate') | Should -BeTrue
            ($command.Parameters['EnhancementCandidate'].Aliases -contains 'Candidate') | Should -BeTrue
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

    Context 'Windows PowerShell launch paths' {
        It 'captures native stderr and evaluates the native exit code' {
            $result = Invoke-NativeCommand -FilePath $env:ComSpec -Arguments @(
                '/d',
                '/c',
                'echo simulated-native-stderr 1>&2'
            )

            $result.ExitCode | Should -Be 0
            $result.Output | Should -Match 'simulated-native-stderr'
        }

        It 'runs through Invoke-Expression without a parameter-scope collision' {
            $startInfo = New-Object Diagnostics.ProcessStartInfo
            $startInfo.FileName = 'powershell.exe'
            $startInfo.WorkingDirectory = Split-Path $scriptPath -Parent
            $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Get-Content -LiteralPath ''.\ZBookPerf.ps1'' -Raw | Invoke-Expression"'
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardInput = $true
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true

            $process = New-Object Diagnostics.Process
            $process.StartInfo = $startInfo
            [void]$process.Start()
            $process.StandardInput.WriteLine('Q')
            $process.StandardInput.Close()
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            $process.ExitCode | Should -Be 0
            $standardOutput | Should -Match 'ZBookPerf - EXP-047'
            $standardError | Should -Not -Match 'ValidateSetFailure|variable Candidate'
        }

        It 'preserves the original menu error through Invoke-Expression' {
            $startInfo = New-Object Diagnostics.ProcessStartInfo
            $startInfo.FileName = 'powershell.exe'
            $startInfo.WorkingDirectory = Split-Path $scriptPath -Parent
            $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "Get-Content -LiteralPath ''.\ZBookPerf.ps1'' -Raw | Invoke-Expression"'
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardInput = $true
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true

            $process = New-Object Diagnostics.Process
            $process.StartInfo = $startInfo
            [void]$process.Start()
            @('3', 'x') | ForEach-Object { $process.StandardInput.WriteLine($_) }
            $process.StandardInput.Close()
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            $process.ExitCode | Should -Not -Be 0
            $standardOutput | Should -Match 'Enhance \(one candidate only\)'
            $standardError | Should -Match 'Unknown candidate selection.'
            $standardError | Should -Not -Match 'variable.*PSCmdlet'
        }

        It 'handles an interactive Tier 2 choice without requiring a command-line flag' {
            $startInfo = New-Object Diagnostics.ProcessStartInfo
            $startInfo.FileName = 'powershell.exe'
            $startInfo.WorkingDirectory = Split-Path $scriptPath -Parent
            $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File ".\ZBookPerf.ps1"'
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardInput = $true
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true

            $process = New-Object Diagnostics.Process
            $process.StartInfo = $startInfo
            [void]$process.Start()
            @('3', '2', 'N', 'Q') | ForEach-Object { $process.StandardInput.WriteLine($_) }
            $process.StandardInput.Close()
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            $process.ExitCode | Should -Be 0
            $standardOutput | Should -Match 'Cancelled. No setting was changed.'
            $standardError | Should -Not -Match 'pass -LabTier2Confirmed'
        }

        It 'carries diagnostic intent from the explicit Fast Startup menu choice' {
            $script:Action = 'Menu'
            $script:menuCallCount = 0
            $script:capturedDiagnosticIntent = $null

            Mock Show-ZBookPerfMenu {
                $script:menuCallCount++
                if ($script:menuCallCount -eq 1) { return '3' }
                return 'Q'
            }
            Mock Select-CandidateInteractive { return 'FastStartupDiagnostic' }
            Mock Confirm-Tier2Interactive { return $true }
            Mock Invoke-Enhancement {
                $script:capturedDiagnosticIntent = [bool]$DiagnosticConfirmed
            }

            Invoke-ZBookPerfMain

            $script:capturedDiagnosticIntent | Should -BeTrue
            Should -Invoke Invoke-Enhancement -Times 1 -ParameterFilter {
                $Name -eq 'FastStartupDiagnostic' -and
                $Tier2Confirmed -and
                $DiagnosticConfirmed
            }
        }

        It 'retains the explicit diagnostic requirement outside the menu' {
            Mock Test-IsAdministrator { return $true }

            {
                Invoke-Enhancement -Name FastStartupDiagnostic -Root $TestDrive -Tier2Confirmed -WhatIf
            } | Should -Throw '*requires -Diagnostic in non-interactive runs*'
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

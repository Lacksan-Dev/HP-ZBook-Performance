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

        It 'exposes the Layer 10 shell profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'ShellProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'ShellRunCount') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'ShellProfile'
        }

        It 'exposes the Layer 11 workload profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'WorkloadProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'WorkloadProcessName') | Should -BeTrue
            ($command.Parameters.Keys -contains 'WorkloadSampleIntervalMilliseconds') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'WorkloadProfile'
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

    Context 'Layer 10 shell profile' {
        It 'summarizes measured runs without counting warmups' {
            $runs = @(
                [pscustomobject]@{ warmup = $true; status = 'Ready'; rawMilliseconds = 900 },
                [pscustomobject]@{ warmup = $false; status = 'Ready'; rawMilliseconds = 500 },
                [pscustomobject]@{ warmup = $false; status = 'Ready'; rawMilliseconds = 300 },
                [pscustomobject]@{ warmup = $false; status = 'Ready'; rawMilliseconds = 320 }
            )

            $summary = Get-ShellReadinessSummary -Runs $runs
            $summary.requestedRunCount | Should -Be 3
            $summary.successfulRunCount | Should -Be 3
            $summary.medianMilliseconds | Should -Be 320
            $summary.medianAbsoluteDeviationMilliseconds | Should -Be 20
            $summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
        }

        It 'marks an absent documented policy as not configured and never mutation eligible' {
            Mock Get-RsopPolicyOrigin {
                [pscustomobject]@{ available = $false; groupPolicyMatchCount = 0 }
            }
            $missing = Join-Path $TestDrive 'missing-policy-key'
            $state = Get-DocumentedPolicyState `
                -Name Widgets `
                -RegistryPath $missing `
                -RegistryKey 'SOFTWARE\Policies\Microsoft\Dsh' `
                -ValueName AllowNewsAndInterests `
                -DocumentedDefault 1 `
                -PolicyCsp './Device/Vendor/MSFT/Policy/Config/NewsAndInterests/AllowNewsAndInterests'

            $state.configured | Should -BeFalse
            $state.managementOrigin | Should -Be 'NotConfiguredAtDocumentedPolicyPath'
            $state.mutationEligible | Should -BeFalse
        }

        It 'calibrates shell-window probe overhead separately from readiness runs' {
            Mock Get-NewReadyShellWindow { @() }
            $measurement = Measure-ShellProbeOverhead `
                -ShellApplication ([pscustomobject]@{}) `
                -TargetPath $TestDrive `
                -Iterations 5

            $measurement.iterations | Should -Be 5
            $measurement.samplesMilliseconds.Count | Should -Be 5
            $measurement.medianMilliseconds | Should -BeGreaterOrEqual 0
            $measurement.p95Milliseconds | Should -BeGreaterOrEqual $measurement.medianMilliseconds
            Should -Invoke Get-NewReadyShellWindow -Times 6
        }

        It 'routes the public action to the shell profiler with bounded parameters' {
            $script:Action = 'ShellProfile'
            $script:ShellRunCount = 3
            $script:ShellWarmupRunCount = 1
            $script:ShellTimeoutMilliseconds = 4000
            $script:ShellProbeCalibrationIterations = 10
            $script:DataRoot = $TestDrive
            Mock Invoke-ShellProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-ShellProfile -Times 1
        }

        It 'contains no Windows-setting mutation command in the shell profiler' {
            $body = (Get-Command Invoke-ShellProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'New-ItemProperty|Set-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|schtasks|powercfg'
        }
    }

    Context 'Layer 11 workload runtime profile' {
        It 'normalizes exact executable names without accepting paths or wildcards' {
            $resolved = @(Resolve-WorkloadProcessNames -Names @('EXPLORER', 'msedge.exe', 'explorer'))

            $resolved | Should -Be @('explorer.exe', 'msedge.exe')
            { Resolve-WorkloadProcessNames -Names @('C:\Windows\notepad.exe') } | Should -Throw
            { Resolve-WorkloadProcessNames -Names @('edge*') } | Should -Throw
        }

        It 'computes CPU and IO deltas only for a stable process identity' {
            $frequency = [double][Diagnostics.Stopwatch]::Frequency
            $beforeRow = [pscustomobject]@{
                name = 'example.exe'
                processId = 42
                creationUtc = '2026-07-29T00:00:00.0000000Z'
                identity = '42|2026-07-29T00:00:00.0000000Z'
                kernelModeTime100ns = [uint64]0
                userModeTime100ns = [uint64]0
                ioCountersAvailable = $true
                readTransferBytes = [uint64]100
                writeTransferBytes = [uint64]50
                workingSetBytes = [uint64]900
                privateMemoryBytes = [uint64]800
                handleCount = [uint32]4
                threadCount = [uint32]2
            }
            $afterRow = $beforeRow.PSObject.Copy()
            $afterRow.kernelModeTime100ns = [uint64]5000000
            $afterRow.userModeTime100ns = [uint64]5000000
            $afterRow.readTransferBytes = [uint64]300
            $afterRow.writeTransferBytes = [uint64]150
            $afterRow.workingSetBytes = [uint64]1000
            $afterRow.privateMemoryBytes = [uint64]850
            $afterRow.handleCount = [uint32]5
            $afterRow.threadCount = [uint32]3
            $before = [pscustomobject]@{
                monotonicTicks = [int64]0
                processes = @($beforeRow)
            }
            $after = [pscustomobject]@{
                capturedUtc = '2026-07-29T00:00:02.0000000Z'
                monotonicTicks = [int64]($frequency * 2)
                queryDurationMilliseconds = 3
                processes = @($afterRow)
                errors = @()
            }

            $interval = ConvertTo-WorkloadInterval -Previous $before -Current $after -LogicalProcessorCount 2

            $interval.status | Should -Be 'Measured'
            $interval.stableProcessCount | Should -Be 1
            $interval.cpuLogicalProcessorPercent | Should -Be 50
            $interval.cpuMachinePercent | Should -Be 25
            $interval.readBytesPerSecond | Should -Be 100
            $interval.writeBytesPerSecond | Should -Be 50
            $interval.workingSetBytes | Should -Be 1000
        }

        It 'does not join reused process identifiers across different creation times' {
            $before = [pscustomobject]@{
                monotonicTicks = [int64]0
                processes = @([pscustomobject]@{
                    identity = '42|first'
                    processId = 42
                })
            }
            $after = [pscustomobject]@{
                capturedUtc = '2026-07-29T00:00:01.0000000Z'
                monotonicTicks = [int64][Diagnostics.Stopwatch]::Frequency
                queryDurationMilliseconds = 1
                processes = @([pscustomobject]@{
                    name = 'example.exe'
                    identity = '42|second'
                    processId = 42
                    creationUtc = 'second'
                    workingSetBytes = [uint64]100
                    privateMemoryBytes = [uint64]100
                    handleCount = [uint32]1
                    threadCount = [uint32]1
                })
                errors = @()
            }

            $interval = ConvertTo-WorkloadInterval -Previous $before -Current $after -LogicalProcessorCount 2

            $interval.status | Should -Be 'NoStableProcessPair'
            $interval.stableProcessCount | Should -Be 0
            $interval.startedProcessCount | Should -Be 1
            $interval.exitedProcessCount | Should -Be 1
        }

        It 'retains CPU and memory while leaving unavailable IO metrics null' {
            $identity = '7|2026-07-29T00:00:00.0000000Z'
            $beforeRow = [pscustomobject]@{
                name = 'protected.exe'; processId = 7; creationUtc = '2026-07-29T00:00:00.0000000Z'; identity = $identity
                kernelModeTime100ns = [uint64]0; userModeTime100ns = [uint64]0
                ioCountersAvailable = $false; readTransferBytes = $null; writeTransferBytes = $null
                workingSetBytes = [uint64]100; privateMemoryBytes = [uint64]80
                handleCount = [uint32]2; threadCount = [uint32]1
            }
            $afterRow = $beforeRow.PSObject.Copy()
            $afterRow.userModeTime100ns = [uint64]1000000
            $afterRow.workingSetBytes = [uint64]120
            $before = [pscustomobject]@{ monotonicTicks = [int64]0; processes = @($beforeRow) }
            $after = [pscustomobject]@{
                capturedUtc = '2026-07-29T00:00:01.0000000Z'
                monotonicTicks = [int64][Diagnostics.Stopwatch]::Frequency
                queryDurationMilliseconds = 1
                processes = @($afterRow)
                errors = @()
            }

            $interval = ConvertTo-WorkloadInterval -Previous $before -Current $after -LogicalProcessorCount 2

            $interval.status | Should -Be 'Measured'
            $interval.cpuMachinePercent | Should -Be 5
            $interval.workingSetBytes | Should -Be 120
            $interval.ioMeasuredProcessCount | Should -Be 0
            $interval.readBytesPerSecond | Should -BeNullOrEmpty
            $interval.writeBytesPerSecond | Should -BeNullOrEmpty
        }

        It 'reports distributions only from measured intervals' {
            $intervals = @(
                [pscustomobject]@{
                    status = 'Measured'; observedProcessCount = 1; startedProcessCount = 0; exitedProcessCount = 0
                    cpuLogicalProcessorPercent = 20; cpuMachinePercent = 10
                    readBytesPerSecond = 100; writeBytesPerSecond = 50
                    workingSetBytes = 1000; privateMemoryBytes = 800
                    handleCount = 5; threadCount = 3; queryDurationMilliseconds = 2
                },
                [pscustomobject]@{
                    status = 'NoStableProcessPair'; observedProcessCount = 0; startedProcessCount = 0; exitedProcessCount = 1
                },
                [pscustomobject]@{
                    status = 'Measured'; observedProcessCount = 1; startedProcessCount = 0; exitedProcessCount = 0
                    cpuLogicalProcessorPercent = 40; cpuMachinePercent = 20
                    readBytesPerSecond = 300; writeBytesPerSecond = 150
                    workingSetBytes = 1200; privateMemoryBytes = 900
                    handleCount = 7; threadCount = 5; queryDurationMilliseconds = 4
                }
            )

            $summary = Get-WorkloadProfileSummary -Intervals $intervals

            $summary.requestedIntervalCount | Should -Be 3
            $summary.measuredIntervalCount | Should -Be 2
            $summary.metrics.cpuMachinePercent.median | Should -Be 15
            $summary.metrics.readBytesPerSecond.p95 | Should -Be 300
            $summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
        }

        It 'records a missing target as unavailable instead of fabricating zero activity' {
            $interval = [pscustomobject]@{
                status = 'NoStableProcessPair'
                observedProcessCount = 0
                startedProcessCount = 0
                exitedProcessCount = 0
            }

            $summary = Get-WorkloadProfileSummary -Intervals @($interval)

            $summary.measuredIntervalCount | Should -Be 0
            $summary.metrics.cpuMachinePercent.count | Should -Be 0
            $summary.metrics.cpuMachinePercent.median | Should -BeNullOrEmpty
            $summary.decision | Should -Be 'NoStableTargetProcessObserved'
        }

        It 'calibrates the complete filtered snapshot query separately' {
            Mock Get-WorkloadProcessSnapshot {
                [pscustomobject]@{ queryDurationMilliseconds = 2 }
            }

            $measurement = Measure-WorkloadSnapshotOverhead -ProcessNames @('explorer.exe') -Iterations 3

            $measurement.iterations | Should -Be 3
            $measurement.samplesMilliseconds.Count | Should -Be 3
            $measurement.medianMilliseconds | Should -Be 2
            Should -Invoke Get-WorkloadProcessSnapshot -Times 4
        }

        It 'routes the public action with bounded runtime-profile parameters' {
            $script:Action = 'WorkloadProfile'
            $script:WorkloadProcessName = @('explorer.exe')
            $script:DurationSeconds = 5
            $script:WorkloadSampleIntervalMilliseconds = 500
            $script:WorkloadCalibrationIterations = 3
            $script:DataRoot = $TestDrive
            Mock Invoke-WorkloadProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-WorkloadProfile -Times 1
        }

        It 'contains no process or Windows-setting mutation command in the workload profiler' {
            $body = (Get-Command Invoke-WorkloadProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'Stop-Process|Start-Process|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|powercfg'
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

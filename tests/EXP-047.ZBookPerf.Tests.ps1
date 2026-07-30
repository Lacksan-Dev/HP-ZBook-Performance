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

        It 'exposes the Layer 12 dependency profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'DependencyProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'DependencyPath') | Should -BeTrue
            ($command.Parameters.Keys -contains 'DependencyEndpoint') | Should -BeTrue
            ($command.Parameters.Keys -contains 'DependencyTimeoutMilliseconds') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'DependencyProfile'
        }

        It 'exposes the sequential performance-layer workflow as a public action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'LayerWorkflow') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'LayerWorkflow'
            $validateSet.ValidValues | Should -Contain 'LayerMap'
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
            $standardOutput | Should -Match 'U X - R O M'
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
            @('M', '3', 'x') | ForEach-Object { $process.StandardInput.WriteLine($_) }
            $process.StandardInput.Close()
            $standardOutput = $process.StandardOutput.ReadToEnd()
            $standardError = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            $process.ExitCode | Should -Not -Be 0
            $standardOutput | Should -Match 'Apply one reversible experiment directly'
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
            @('M', '3', '2', 'N', 'Q') | ForEach-Object { $process.StandardInput.WriteLine($_) }
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
                if ($script:menuCallCount -eq 1) { return 'M' }
                return 'Q'
            }
            Mock Show-ZBookPerfAdvancedMenu { return '3' }
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

    Context 'capability-aware console guidance' {
        It 'normalizes native stderr without exposing the PowerShell RemoteException wrapper' {
            $result = Invoke-NativeCommand -FilePath $env:ComSpec -Arguments @(
                '/d',
                '/c',
                'echo simulated-native-stderr 1>&2'
            )

            $result.Output | Should -Match 'simulated-native-stderr'
            $result.Output | Should -Not -Match 'RemoteException|NativeCommandError'
        }

        It 'preserves an existing WPR recording instead of attempting to replace it' {
            Mock Test-IsAdministrator { return $true }
            Mock Get-Command {
                [pscustomobject]@{ Name = 'wpr.exe'; Source = 'C:\Windows\System32\wpr.exe' }
            } -ParameterFilter { $Name -eq 'wpr.exe' }
            Mock Get-WprRecordingState {
                [pscustomobject]@{ available = $true; state = 'recording'; raw = 'WPR recording is in progress' }
            }
            Mock Invoke-NativeCommand { throw 'ZBookPerf must not start WPR while another recording is active.' }

            $trace = Start-WprCapture -Root $TestDrive -Stamp 'busy-test'

            $trace.status | Should -Be 'busy'
            $trace.existingRecordingPreserved | Should -BeTrue
            $trace.reason | Should -Match 'wpr -stop C:\\Temp\\existing-trace\.etl'
            $trace.reason | Should -Match 'wpr -cancel'
            Should -Invoke Invoke-NativeCommand -Times 0
        }

        It 'turns a WPR start race into actionable busy guidance' {
            Mock Test-IsAdministrator { return $true }
            Mock Get-Command {
                [pscustomobject]@{ Name = 'wpr.exe'; Source = 'C:\Windows\System32\wpr.exe' }
            } -ParameterFilter { $Name -eq 'wpr.exe' }
            Mock Get-WprRecordingState {
                [pscustomobject]@{ available = $true; state = 'idle'; raw = 'WPR is not recording' }
            }
            Mock Invoke-NativeCommand {
                [pscustomobject]@{
                    ExitCode = 1
                    Output = "The profiles are already running.`r`nError code: 0xc5583001"
                }
            }

            $trace = Start-WprCapture -Root $TestDrive -Stamp 'race-test'

            $trace.status | Should -Be 'busy'
            $trace.existingRecordingPreserved | Should -BeTrue
            $trace.reason | Should -Not -Match 'RemoteException'
        }

        It 'detects when the legacy High performance candidate is unavailable' {
            Mock Invoke-NativeCommand {
                if ($Arguments[0] -eq '/list') {
                    return [pscustomobject]@{
                        ExitCode = 0
                        Output = 'Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e (Balanced) *'
                    }
                }
                return [pscustomobject]@{
                    ExitCode = 0
                    Output = 'Standby (S0 Low Power Idle) Network Connected'
                }
            }

            $support = Get-PowerCandidateSupport

            $support.supported | Should -BeFalse
            $support.modernStandbyDetected | Should -BeTrue
            $support.reason | Should -Match 'Balanced plan and Windows Power mode'
        }

        It 'returns to the menu without a Tier 2 prompt when PowerAc is unsupported' {
            Mock Get-PowerCandidateSupport {
                [pscustomobject]@{
                    supported = $false
                    modernStandbyDetected = $true
                    reason = 'High performance is unavailable.'
                }
            }
            Mock Read-Host { return '1' }
            Mock Write-Host { }

            $selected = Select-CandidateInteractive

            $selected | Should -BeNullOrEmpty
        }

        It 'rejects command-line PowerAc before baseline or mutation work when unsupported' {
            Mock Get-PowerCandidateSupport {
                [pscustomobject]@{
                    supported = $false
                    modernStandbyDetected = $true
                    reason = 'High performance is unavailable.'
                }
            }

            {
                Invoke-Enhancement -Name PowerAc -Root $TestDrive -Tier2Confirmed -Confirm:$false
            } | Should -Throw '*PowerAc is unsupported*No setting was changed*'
        }
    }

    Context 'sequential 12-layer workflow' {
        It 'defines all twelve layers in order without claiming missing integrations are healthy' {
            $catalog = @(Get-PerformanceLayerCatalog)

            $catalog.Count | Should -Be 12
            $catalog.number | Should -Be (1..12)
            $catalog[2].assessment | Should -Be 'NotIntegrated'
            $catalog[2].assessmentLabel | Should -Match 'No product-integrated'
            $catalog[9].assessment | Should -Be 'ShellProfile'
            $catalog[10].assessment | Should -Be 'WorkloadProfile'
        }

        It 'groups existing change experiments by their responsible performance layer' {
            (Get-PerformanceLayer -Number 5).candidates | Should -Be @('MmcssResponsiveness', 'NtfsLastAccess')
            (Get-PerformanceLayer -Number 6).candidates | Should -Be @('PowerAc')
            (Get-PerformanceLayer -Number 8).candidates | Should -Be @('FastStartupDiagnostic')
            (Get-PerformanceLayer -Number 10).candidates | Should -Be @('VisualEffects')
            (Get-PerformanceLayer -Number 11).candidates.Count | Should -Be 0
        }

        It 'persists a resumable workflow cursor independently from the engineering automation cursor' {
            $root = Join-Path $TestDrive 'workflow-state'
            $state = Get-LayerWorkflowState -Root $root
            $state.currentLayer | Should -Be 1
            $state.phase | Should -Be 'assessment-required'

            $state.currentLayer = 10
            $state.phase = 'assessed'
            Add-LayerWorkflowHistory -State $state -Action 'layer-selected' -Layer 10 -Candidate $null -EvidencePath $null -Reason 'test'
            Save-LayerWorkflowState -Root $root -State $state
            $restored = Get-LayerWorkflowState -Root $root

            $restored.currentLayer | Should -Be 10
            $restored.phase | Should -Be 'assessed'
            @($restored.history).Count | Should -Be 1
        }

        It 'orders multiple experiments within one layer rather than bundling them' {
            $state = New-LayerWorkflowState
            $state.currentLayer = 5

            (Get-NextLayerCandidate -State $state -Layer 5) | Should -Be 'MmcssResponsiveness'
            Add-LayerWorkflowHistory -State $state -Action 'candidate-kept' -Layer 5 -Candidate 'MmcssResponsiveness' -EvidencePath $null -Reason 'test'
            (Get-NextLayerCandidate -State $state -Layer 5) | Should -Be 'NtfsLastAccess'
        }

        It 'marks an unavailable assessment explicitly and lets the next safe step advance' {
            $root = Join-Path $TestDrive 'unavailable-assessment'
            $state = New-LayerWorkflowState
            $state.currentLayer = 3
            $runtime = @{
                Seconds = 5
                Interval = 1
                SkipTrace = $true
                ShellRuns = 3
                ShellWarmups = 0
                ShellTimeout = 1000
                ShellCalibration = 5
                WorkloadNames = @('explorer.exe')
                WorkloadInterval = 500
                WorkloadCalibration = 3
                DryRun = $true
            }
            Mock Write-Host { }

            Invoke-NextLayerWorkflowStep -Root $root -State $state -Runtime $runtime
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].action | Should -Be 'assessment-unavailable'

            Invoke-NextLayerWorkflowStep -Root $root -State $state -Runtime $runtime
            $state.currentLayer | Should -Be 4
            $state.phase | Should -Be 'assessment-required'
        }

        It 'routes the Layer 10 assessment to the shell profiler' {
            $root = Join-Path $TestDrive 'shell-layer'
            $state = New-LayerWorkflowState
            $state.currentLayer = 10
            Mock Invoke-ShellProfile {
                [pscustomobject]@{ evidencePath = 'shell-profile.json' }
            }

            Invoke-LayerAssessmentStep `
                -Root $root `
                -State $state `
                -Seconds 5 `
                -Interval 1 `
                -SkipTrace `
                -ShellRuns 3 `
                -ShellWarmups 0 `
                -ShellTimeout 1000 `
                -ShellCalibration 5 `
                -WorkloadNames @('explorer.exe') `
                -WorkloadInterval 500 `
                -WorkloadCalibration 3

            Should -Invoke Invoke-ShellProfile -Times 1
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].evidencePath | Should -Be 'shell-profile.json'
        }

        It 'captures a fresh baseline, applies only the next Layer 10 experiment, and pauses for measurement' {
            $root = Join-Path $TestDrive 'layer-apply'
            $state = New-LayerWorkflowState
            $state.currentLayer = 10
            $state.phase = 'assessed'
            $script:workflowLogCall = 0
            Mock Invoke-Measurement {
                [pscustomobject]@{ evidencePath = 'baseline.json' }
            }
            Mock Get-WorkflowCandidateSupport {
                [pscustomobject]@{ supported = $true; reason = 'test' }
            }
            Mock Invoke-Enhancement { }
            Mock Get-ChangeLog {
                $script:workflowLogCall++
                if ($script:workflowLogCall -eq 1) {
                    return [pscustomobject]@{ entries = @() }
                }
                return [pscustomobject]@{
                    entries = @(
                        [pscustomobject]@{
                            candidate = 'VisualEffects'
                            status = 'applied'
                            rebootRequired = $false
                            baselinePath = 'baseline.json'
                        }
                    )
                }
            }

            Invoke-LayerEnhancementStep -Root $root -State $state -Seconds 5 -Interval 1 -SkipTrace

            Should -Invoke Invoke-Measurement -Times 1 -ParameterFilter { $Kind -eq 'baseline' }
            Should -Invoke Invoke-Enhancement -Times 1 -ParameterFilter { $Name -eq 'VisualEffects' }
            $state.activeCandidate | Should -Be 'VisualEffects'
            $state.phase | Should -Be 'remeasure-required'
            @($state.history)[-1].action | Should -Be 'candidate-applied'
        }

        It 'blocks advancement while a change has not passed the measurement gate' {
            $root = Join-Path $TestDrive 'measurement-gate'
            $state = New-LayerWorkflowState
            $state.currentLayer = 10
            $state.phase = 'remeasure-required'
            $state.activeCandidate = 'VisualEffects'
            Mock Write-Host { }

            Complete-LayerWorkflowCandidate -Root $root -State $state

            $state.currentLayer | Should -Be 10
            $state.phase | Should -Be 'remeasure-required'
            $state.activeCandidate | Should -Be 'VisualEffects'
        }

        It 'advances after a measured change is explicitly retained' {
            $root = Join-Path $TestDrive 'measured-keep'
            $state = New-LayerWorkflowState
            $state.currentLayer = 10
            $state.phase = 'review-required'
            $state.activeCandidate = 'VisualEffects'

            Complete-LayerWorkflowCandidate -Root $root -State $state

            $state.currentLayer | Should -Be 11
            $state.phase | Should -Be 'assessment-required'
            $state.activeCandidate | Should -BeNullOrEmpty
            @($state.history)[-1].action | Should -Be 'candidate-kept'
        }

        It 'keeps direct remeasure and revert actions synchronized with an active layer workflow' {
            $root = Join-Path $TestDrive 'context-aware-actions'
            $state = New-LayerWorkflowState
            $state.currentLayer = 10
            $state.phase = 'remeasure-required'
            $state.activeCandidate = 'VisualEffects'
            Save-LayerWorkflowState -Root $root -State $state
            Mock Invoke-LayerRemeasureStep { }
            Mock Revert-LayerWorkflowCandidate { }
            Mock Invoke-Measurement { throw 'Direct measurement must not bypass the layer workflow.' }
            Mock Invoke-RevertChanges { throw 'Direct rollback must not bypass the layer workflow.' }

            Invoke-ContextAwareRemeasure -Root $root -Seconds 5 -Interval 1 -SkipTrace
            Invoke-ContextAwareRevert -Root $root

            Should -Invoke Invoke-LayerRemeasureStep -Times 1
            Should -Invoke Revert-LayerWorkflowCandidate -Times 1
            Should -Invoke Invoke-Measurement -Times 0
            Should -Invoke Invoke-RevertChanges -Times 0
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

    Context 'Layer 12 dependency readiness profile' {
        It 'redacts a local path while preserving storage-locality metadata' {
            $observation = Get-DependencyPathObservation -Path $TestDrive -InputIndex 2

            $observation.inputIndex | Should -Be 2
            $observation.identitySha256 | Should -Match '^[0-9a-f]{64}$'
            $observation.locality | Should -BeIn @('Local', 'CloudSyncRoot')
            $observation.driveType | Should -Be 'Fixed'
            $observation.existenceStatus | Should -Be 'Exists'
            ($observation.PSObject.Properties.Name -contains 'path') | Should -BeFalse
        }

        It 'classifies a UNC dependency without touching its remote contents' {
            Mock Test-Path { throw 'UNC existence must not be probed.' }
            Mock Get-Item { throw 'UNC metadata must not be opened.' }

            $observation = Get-DependencyPathObservation -Path '\\server.example\share\work' -InputIndex 0

            $observation.locality | Should -Be 'Network'
            $observation.driveType | Should -Be 'Network'
            $observation.existenceStatus | Should -Be 'NotProbedToAvoidUnboundedNetworkPathAccess'
            $observation.exists | Should -BeNullOrEmpty
            Should -Invoke Test-Path -Times 0
            Should -Invoke Get-Item -Times 0
        }

        It 'accepts only explicit bounded host and port endpoint declarations' {
            $endpoint = Resolve-DependencyEndpoint -Endpoint 'github.com:443' -InputIndex 1

            $endpoint.host | Should -Be 'github.com'
            $endpoint.port | Should -Be 443
            $endpoint.identitySha256 | Should -Match '^[0-9a-f]{64}$'
            { Resolve-DependencyEndpoint -Endpoint 'https://github.com' } | Should -Throw '*Use host:port*'
            { Resolve-DependencyEndpoint -Endpoint 'github.com:70000' } | Should -Throw '*1 through 65535*'
        }

        It 'summarizes repeated endpoint readiness without exposing a host name' {
            $probes = @(
                [pscustomobject]@{ identitySha256 = ('a' * 64); port = 443; status = 'Ready'; durationMilliseconds = 10; probeRun = 1 },
                [pscustomobject]@{ identitySha256 = ('a' * 64); port = 443; status = 'Timeout'; durationMilliseconds = 100; probeRun = 2 }
            )

            $summary = Get-DependencyProfileSummary -Paths @() -EndpointProbes $probes

            $summary.endpointCount | Should -Be 1
            $summary.readiness | Should -Be 'OneOrMoreEndpointProbesNotReady'
            $summary.endpoints[0].readyCount | Should -Be 1
            $summary.endpoints[0].timeoutCount | Should -Be 1
            ($summary | ConvertTo-Json -Depth 10) | Should -Not -Match 'github'
        }

        It 'produces the same condition signature when only timing changes' {
            $paths = @(
                [pscustomobject]@{
                    identitySha256 = ('b' * 64); locality = 'Local'; driveType = 'Fixed'
                    driveReady = $true; driveFormat = 'NTFS'; existenceStatus = 'Exists'
                    knownOneDriveRoot = $false; reparsePoint = $false; offline = $false
                    recallOnDataAccess = $false
                }
            )
            $first = @(
                [pscustomobject]@{ identitySha256 = ('c' * 64); port = 443; probeRun = 1; status = 'Ready'; durationMilliseconds = 5 }
            )
            $second = @(
                [pscustomobject]@{ identitySha256 = ('c' * 64); port = 443; probeRun = 1; status = 'Ready'; durationMilliseconds = 500 }
            )

            (Get-DependencyConditionSignature -Paths $paths -EndpointProbes $first) |
                Should -Be (Get-DependencyConditionSignature -Paths $paths -EndpointProbes $second)
        }

        It 'writes a redacted bounded profile and never stores declared names' {
            Mock Get-WindowsEnvironment { [pscustomobject]@{ mocked = $true } }
            Mock Invoke-DependencyEndpointProbe {
                [pscustomobject]@{
                    inputIndex = $Endpoint.inputIndex
                    identitySha256 = $Endpoint.identitySha256
                    port = $Endpoint.port
                    probeRun = $ProbeRun
                    status = 'Ready'
                    durationMilliseconds = 3
                    timeoutMilliseconds = $TimeoutMilliseconds
                    errorType = $null
                }
            }
            Mock Write-StructuredEvent { }

            $profile = Invoke-DependencyProfile `
                -Root $TestDrive `
                -Paths @($TestDrive) `
                -Endpoints @('github.com:443') `
                -ProbeRunCount 3 `
                -TimeoutMilliseconds 250 `
                -CalibrationIterations 3
            $json = Get-Content -LiteralPath $profile.evidencePath -Raw

            $profile.observationOnly | Should -BeTrue
            $profile.summary.readiness | Should -Be 'AllDeclaredEndpointsReady'
            $profile.endpointProbes.Count | Should -Be 3
            $profile.instrumentation.maximumDeclaredEndpointBudgetMilliseconds | Should -Be 750
            $json | Should -Not -Match [regex]::Escape($TestDrive)
            $json | Should -Not -Match 'github\.com'
            Should -Invoke Invoke-DependencyEndpointProbe -Times 3
        }

        It 'keeps the saved profile usable when the optional event journal is unavailable' {
            Mock Get-WindowsEnvironment { [pscustomobject]@{ mocked = $true } }
            Mock Write-StructuredEvent { throw [UnauthorizedAccessException]::new('test') }
            Mock Write-Warning { }

            $profile = Invoke-DependencyProfile `
                -Root $TestDrive `
                -Paths @($TestDrive) `
                -Endpoints @() `
                -ProbeRunCount 1 `
                -TimeoutMilliseconds 250 `
                -CalibrationIterations 3
            $secondProfile = Invoke-DependencyProfile `
                -Root $TestDrive `
                -Paths @($TestDrive) `
                -Endpoints @() `
                -ProbeRunCount 1 `
                -TimeoutMilliseconds 250 `
                -CalibrationIterations 3

            Test-Path -LiteralPath $profile.evidencePath | Should -BeTrue
            Test-Path -LiteralPath $secondProfile.evidencePath | Should -BeTrue
            $profile.evidencePath | Should -Not -Be $secondProfile.evidencePath
            Should -Invoke Write-Warning -Times 2 -ParameterFilter {
                $Message -match 'optional event journal'
            }
        }

        It 'routes the public action with dependency-profile bounds' {
            $script:Action = 'DependencyProfile'
            $script:DependencyPath = @($TestDrive)
            $script:DependencyEndpoint = @('github.com:443')
            $script:DependencyProbeRunCount = 3
            $script:DependencyTimeoutMilliseconds = 250
            $script:DependencyCalibrationIterations = 3
            $script:DataRoot = $TestDrive
            Mock Invoke-DependencyProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-DependencyProfile -Times 1
        }

        It 'contains no file-content or Windows-setting mutation command' {
            $body = (Get-Command Invoke-DependencyProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'Get-Content|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|powercfg|FileStream|ReadAll'
        }
    }

    Context 'UX-ROM layer-centered interface' {
        It 'uses the UX-ROM product identity and gives every layer a plain-language description' {
            $script:ProductName | Should -Be 'Lacksan UX-ROM'
            $catalog = @(Get-PerformanceLayerCatalog)

            @($catalog | Where-Object { [string]::IsNullOrWhiteSpace($_.description) }).Count | Should -Be 0
            $catalog[9].description | Should -Match 'Explorer'
            $catalog[11].assessment | Should -Be 'DependencyProfile'
        }

        It 'shows one full diagnostic, twelve layer choices, and one synergy batch on the main menu' {
            Mock Read-Host { return 'Q' }
            Mock Write-Host { }

            Show-ZBookPerfMenu | Should -Be 'Q'

            Should -Invoke Write-Host -ParameterFilter { $Object -match 'Full system diagnostics' }
            Should -Invoke Write-Host -ParameterFilter { $Object -match 'Apply all eligible tweaks' }
            Should -Invoke Write-Host -Times 1 -ParameterFilter { $Object -match '^10\. Shell, GUI' }
        }

        It 'does not scatter a read-only run behind a layer that has no eligible tweak' {
            $state = New-LayerWorkflowState
            Mock Get-LayerWorkflowState { return $state }
            Mock Invoke-LayerAssessmentStep { }
            Mock Write-Host { }

            Invoke-SelectedPerformanceLayer -Root $TestDrive -LayerNumber 3 -Runtime @{}

            Should -Invoke Invoke-LayerAssessmentStep -Times 0
        }

        It 'runs the required baseline internally before applying the selected layer tweak' {
            $state = New-LayerWorkflowState
            Mock Get-LayerWorkflowState { return $state }
            Mock Save-LayerWorkflowState { }
            Mock Invoke-LayerAssessmentStep { $State.phase = 'assessed' }
            Mock Invoke-LayerEnhancementStep { }
            Mock Write-Host { }
            $runtime = @{
                Seconds = 5; Interval = 1; SkipTrace = $true; DryRun = $true
                ShellRuns = 1; ShellWarmups = 0; ShellTimeout = 1000; ShellCalibration = 5
                WorkloadNames = @('explorer.exe'); WorkloadInterval = 1000; WorkloadCalibration = 3
            }

            Invoke-SelectedPerformanceLayer -Root $TestDrive -LayerNumber 10 -Runtime $runtime

            Should -Invoke Invoke-LayerAssessmentStep -Times 1
            Should -Invoke Invoke-LayerEnhancementStep -Times 1 -ParameterFilter {
                [int]$State.currentLayer -eq 10
            }
        }

        It 'combines the integrated read-only checks into one full diagnostic manifest' {
            Mock Invoke-Measurement {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'baseline.json') }
            }
            Mock Invoke-ShellProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'shell.json') }
            }
            Mock Invoke-WorkloadProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'workload.json') }
            }
            Mock Invoke-DependencyProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'dependencies.json') }
            }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }
            $runtime = @{
                Seconds = 5; Interval = 1; SkipTrace = $true
                ShellRuns = 1; ShellWarmups = 0; ShellTimeout = 1000; ShellCalibration = 5
                WorkloadNames = @('explorer.exe'); WorkloadInterval = 1000; WorkloadCalibration = 3
                DependencyPaths = @($TestDrive); DependencyEndpoints = @()
                DependencyRuns = 1; DependencyTimeout = 250; DependencyCalibration = 3
            }

            $result = Invoke-FullSystemDiagnostics -Root $TestDrive -Runtime $runtime

            $result.observationOnly | Should -BeTrue
            $result.coveredLayers | Should -Be @(1, 2, 5, 6, 10, 11, 12)
            Test-Path -LiteralPath $result.evidence.systemBaseline | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $TestDrive 'measurements') | Should -BeTrue
            Should -Invoke Invoke-Measurement -Times 1
            Should -Invoke Invoke-ShellProfile -Times 1
            Should -Invoke Invoke-WorkloadProfile -Times 1
            Should -Invoke Invoke-DependencyProfile -Times 1
        }

        It 'routes the public full-diagnostics action to the single diagnostic entry point' {
            $script:Action = 'FullDiagnostics'
            $script:DataRoot = $TestDrive
            Mock Invoke-FullSystemDiagnostics { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-FullSystemDiagnostics -Times 1
        }

        It 'routes the public apply-all action to the synergy batch controller' {
            $script:Action = 'ApplyAll'
            $script:DataRoot = $TestDrive
            $script:LabTier2Confirmed = $true
            Mock Invoke-AllEligibleTweaks { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-AllEligibleTweaks -Times 1
        }

        It 'keeps reboot-dependent controls out of the apply-all synergy batch' {
            Mock Get-WorkflowCandidateSupport {
                [pscustomobject]@{ supported = $true; reason = 'supported' }
            }

            $plan = @(Get-SynergyBatchPlan)

            $plan.candidate | Should -Be @('MmcssResponsiveness', 'PowerAc', 'VisualEffects')
            $plan.candidate | Should -Not -Contain 'NtfsLastAccess'
            $plan.candidate | Should -Not -Contain 'FastStartupDiagnostic'
        }

        It 'makes the apply-all dry run mutation-free while previewing every eligible candidate' {
            Mock Get-WorkflowCandidateSupport {
                [pscustomobject]@{ supported = $true; reason = 'supported' }
            }
            Mock Get-LayerWorkflowState { return (New-LayerWorkflowState) }
            Mock Invoke-Enhancement { }
            Mock Invoke-Measurement { throw 'A dry run must not collect an apply baseline.' }
            Mock Write-Host { }
            $runtime = @{ Seconds = 5; Interval = 1; SkipTrace = $true }

            Invoke-AllEligibleTweaks -Root $TestDrive -Runtime $runtime -Tier2Confirmed -DryRun

            Should -Invoke Invoke-Enhancement -Times 3
            Should -Invoke Invoke-Measurement -Times 0
        }

        It 'journals and measures all eligible controls as one reversible synergy batch' {
            $state = New-LayerWorkflowState
            $script:batchTestLog = [pscustomobject][ordered]@{ entries = @() }
            $script:batchMeasurementCall = 0
            Mock Get-WorkflowCandidateSupport {
                [pscustomobject]@{ supported = $true; reason = 'supported' }
            }
            Mock Get-LayerWorkflowState { return $state }
            Mock Get-ChangeLog { return $script:batchTestLog }
            Mock Invoke-Enhancement {
                $entry = [pscustomobject]@{
                    id = [guid]::NewGuid().ToString()
                    candidate = $Name
                    status = 'applied'
                }
                $script:batchTestLog.entries = @($script:batchTestLog.entries) + @($entry)
            }
            Mock Invoke-Measurement {
                $script:batchMeasurementCall++
                [pscustomobject]@{
                    evidencePath = Join-Path $TestDrive "measurement-$script:batchMeasurementCall.json"
                }
            }
            Mock Show-MeasurementComparison { }
            Mock Save-LayerWorkflowState { }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }
            $runtime = @{ Seconds = 5; Interval = 1; SkipTrace = $true }

            $batch = Invoke-AllEligibleTweaks -Root $TestDrive -Runtime $runtime -Tier2Confirmed

            $batch.entryIds.Count | Should -Be 3
            $batch.candidates | Should -Be @('MmcssResponsiveness', 'PowerAc', 'VisualEffects')
            $batch.status | Should -Be 'active'
            $batch.decision | Should -Be 'AppliedAsRequestedNoStandalonePerformanceClaim'
            Should -Invoke Invoke-Enhancement -Times 3
            Should -Invoke Invoke-Measurement -Times 2
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

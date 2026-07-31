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

        It 'exposes the Layer 1 thermal-envelope profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'ThermalProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'ThermalCalibrationIterations') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'ThermalProfile'
        }

        It 'exposes the Layer 2 storage-path profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'HardwareProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'HardwareCalibrationIterations') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'HardwareProfile'
        }

        It 'exposes the Layer 3 firmware-boundary profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'FirmwareProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'FirmwareCalibrationIterations') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'FirmwareProfile'
        }

        It 'exposes the Layer 4 driver and OEM ownership profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'DriverProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'DriverCalibrationIterations') | Should -BeTrue
            ($command.Parameters.Keys -contains 'DriverDeviceLimit') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'DriverProfile'
        }

        It 'exposes the Layer 5 kernel-pressure profile as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'KernelProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'KernelBlockCount') | Should -BeTrue
            ($command.Parameters.Keys -contains 'KernelSamplesPerBlock') | Should -BeTrue
            ($command.Parameters.Keys -contains 'KernelCalibrationIterations') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'KernelProfile'
        }

        It 'exposes the Layer 6 power-policy truth map as a public read-only action' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'PowerProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'PowerProfileSampleCount') | Should -BeTrue
            ($command.Parameters.Keys -contains 'PowerProfileSampleIntervalMilliseconds') | Should -BeTrue
            ($command.Parameters.Keys -contains 'PowerProfileCalibrationIterations') | Should -BeTrue
            ($command.Parameters.Keys -contains 'PowerProfileCallbackTimeoutMilliseconds') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'PowerProfile'
        }

        It 'exposes the Layer 7 protection-preserving security activity profile' {
            $command = Get-Command $scriptPath
            ($command.Parameters.Keys -contains 'SecurityProfile') | Should -BeTrue
            ($command.Parameters.Keys -contains 'SecurityProfileSampleIntervalMilliseconds') | Should -BeTrue
            ($command.Parameters.Keys -contains 'SecurityProfileCalibrationIterations') | Should -BeTrue
            $validateSet = @($command.Parameters['Action'].Attributes | Where-Object {
                $_ -is [System.Management.Automation.ValidateSetAttribute]
            })[0]
            $validateSet.ValidValues | Should -Contain 'SecurityProfile'
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
            $catalog[0].assessment | Should -Be 'ThermalProfile'
            $catalog[1].assessment | Should -Be 'HardwareProfile'
            $catalog[2].assessment | Should -Be 'FirmwareProfile'
            $catalog[3].assessment | Should -Be 'DriverProfile'
            $catalog[3].assessmentLabel | Should -Match 'signed-package'
            $catalog[4].assessment | Should -Be 'KernelProfile'
            $catalog[4].assessmentLabel | Should -Match 'DPC/ISR'
            $catalog[5].assessment | Should -Be 'PowerProfile'
            $catalog[5].assessmentLabel | Should -Match 'effective mode'
            $catalog[6].assessment | Should -Be 'SecurityProfile'
            $catalog[6].assessmentLabel | Should -Match 'protection state'
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
            $state.currentLayer = 9
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
            $state.currentLayer | Should -Be 10
            $state.phase | Should -Be 'assessment-required'
        }

        It 'routes the Layer 2 assessment to the storage-path profiler' {
            $root = Join-Path $TestDrive 'hardware-layer'
            $state = New-LayerWorkflowState
            $state.currentLayer = 2
            Mock Invoke-HardwareProfile {
                [pscustomobject]@{ evidencePath = 'hardware-profile.json' }
            }

            Invoke-LayerAssessmentStep `
                -Root $root `
                -State $state `
                -Seconds 5 `
                -Interval 1 `
                -SkipTrace `
                -ThermalCalibration 3 `
                -HardwareCalibration 3 `
                -ShellRuns 3 `
                -ShellWarmups 0 `
                -ShellTimeout 1000 `
                -ShellCalibration 5 `
                -WorkloadNames @('explorer.exe') `
                -WorkloadInterval 500 `
                -WorkloadCalibration 3

            Should -Invoke Invoke-HardwareProfile -Times 1
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].evidencePath | Should -Be 'hardware-profile.json'
        }

        It 'routes the Layer 3 assessment to the firmware-boundary profiler' {
            $root = Join-Path $TestDrive 'firmware-layer'
            $state = New-LayerWorkflowState
            $state.currentLayer = 3
            Mock Invoke-FirmwareProfile {
                [pscustomobject]@{ evidencePath = 'firmware-profile.json' }
            }

            Invoke-LayerAssessmentStep `
                -Root $root `
                -State $state `
                -Seconds 5 `
                -Interval 1 `
                -SkipTrace `
                -ThermalCalibration 3 `
                -HardwareCalibration 3 `
                -FirmwareCalibration 3 `
                -ShellRuns 3 `
                -ShellWarmups 0 `
                -ShellTimeout 1000 `
                -ShellCalibration 5 `
                -WorkloadNames @('explorer.exe') `
                -WorkloadInterval 500 `
                -WorkloadCalibration 3

            Should -Invoke Invoke-FirmwareProfile -Times 1
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].evidencePath | Should -Be 'firmware-profile.json'
        }

        It 'routes the Layer 4 assessment to the driver and OEM ownership profiler' {
            $root = Join-Path $TestDrive 'driver-layer'
            $state = New-LayerWorkflowState
            $state.currentLayer = 4
            Mock Invoke-DriverProfile {
                [pscustomobject]@{ evidencePath = 'driver-profile.json' }
            }

            Invoke-LayerAssessmentStep `
                -Root $root `
                -State $state `
                -Seconds 5 `
                -Interval 1 `
                -SkipTrace `
                -DriverCalibration 3 `
                -DriverLimit 512

            Should -Invoke Invoke-DriverProfile -Times 1
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].evidencePath | Should -Be 'driver-profile.json'
        }

        It 'routes the Layer 5 assessment to the kernel-pressure profiler' {
            $root = Join-Path $TestDrive 'kernel-layer'
            $state = New-LayerWorkflowState
            $state.currentLayer = 5
            Mock Invoke-KernelProfile {
                [pscustomobject]@{ evidencePath = 'kernel-profile.json' }
            }

            Invoke-LayerAssessmentStep `
                -Root $root `
                -State $state `
                -KernelBlocks 3 `
                -KernelSamples 5 `
                -KernelInterval 1 `
                -KernelCalibration 3

            Should -Invoke Invoke-KernelProfile -Times 1
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].evidencePath | Should -Be 'kernel-profile.json'
        }

        It 'routes the Layer 6 assessment to the power-policy truth map' {
            $root = Join-Path $TestDrive 'power-layer'
            $state = New-LayerWorkflowState
            $state.currentLayer = 6
            Mock Invoke-PowerProfile {
                [pscustomobject]@{ evidencePath = 'power-profile.json' }
            }

            Invoke-LayerAssessmentStep `
                -Root $root `
                -State $state `
                -PowerSamples 3 `
                -PowerIntervalMilliseconds 100 `
                -PowerCalibration 3 `
                -PowerCallbackTimeout 1000

            Should -Invoke Invoke-PowerProfile -Times 1
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].evidencePath | Should -Be 'power-profile.json'
        }

        It 'routes the Layer 7 assessment to the protection-preserving activity profiler' {
            $root = Join-Path $TestDrive 'security-layer'
            $state = New-LayerWorkflowState
            $state.currentLayer = 7
            Mock Invoke-SecurityProfile {
                [pscustomobject]@{ evidencePath = 'security-profile.json' }
            }

            Invoke-LayerAssessmentStep `
                -Root $root `
                -State $state `
                -Seconds 5 `
                -SecurityIntervalMilliseconds 1000 `
                -SecurityCalibration 3

            Should -Invoke Invoke-SecurityProfile -Times 1
            $state.phase | Should -Be 'assessed'
            @($state.history)[-1].evidencePath | Should -Be 'security-profile.json'
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

    Context 'Layer 1 thermal-envelope profile' {
        It 'separates an observed processor limit from an unsupported thermal-cause claim' {
            $samples = @(
                [pscustomobject]@{
                    processorTimePercent = 45
                    processorUtilityPercent = 60
                    processorPerformancePercent = 110
                    processorFrequencyMHz = 2400
                    performanceLimitPercent = 100
                    performanceLimitFlags = [uint32]0
                    acpiThermalZoneStatus = 'Unavailable'
                    acpiThermalZoneCelsius = @()
                    queryDurationMilliseconds = 4
                },
                [pscustomobject]@{
                    processorTimePercent = 90
                    processorUtilityPercent = 95
                    processorPerformancePercent = 80
                    processorFrequencyMHz = 1600
                    performanceLimitPercent = 80
                    performanceLimitFlags = [uint32]1
                    acpiThermalZoneStatus = 'Read'
                    acpiThermalZoneCelsius = @(72.5)
                    queryDurationMilliseconds = 5
                }
            )

            $summary = Get-ThermalProfileSummary -Samples $samples

            $summary.status | Should -Be 'ProcessorPerformanceLimitObserved'
            $summary.limitedSampleCount | Should -Be 1
            $summary.nonzeroLimitFlagSampleCount | Should -Be 1
            $summary.observedLimitFlagValues | Should -Be @([uint32]1)
            $summary.performanceLimitPercent.minimum | Should -Be 80
            $summary.acpiThermalZoneCelsius.maximum | Should -Be 72.5
            $summary.interpretation | Should -Match 'does not prove'
            $summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
        }

        It 'writes bounded structured evidence without mutating the observed system' {
            Mock Get-ThermalProfileSupport {
                [pscustomobject]@{
                    supported = $true
                    provider = 'Win32_PerfFormattedData_Counters_ProcessorInformation'
                    reason = 'supported'
                    missingProperties = @()
                    thermalZoneSupported = $false
                    thermalZoneStatus = 'Unavailable'
                    thermalZoneErrorType = 'CimException'
                }
            }
            Mock Measure-ThermalProfileObserver {
                [pscustomobject]@{
                    iterations = 3
                    durationMilliseconds = [pscustomobject]@{ count = 3; median = 1; p95 = 2; minimum = 1; maximum = 2 }
                    qualification = 'test'
                }
            }
            Mock Get-WindowsEnvironment { [pscustomobject]@{ windows = [pscustomobject]@{ build = '26200' } } }
            Mock Get-ThermalPerformanceSample {
                [pscustomobject]@{
                    timestampUtc = [DateTime]::UtcNow.ToString('o')
                    monotonicOffsetMilliseconds = 0
                    processorTimePercent = 20
                    processorUtilityPercent = 25
                    processorPerformancePercent = 100
                    processorFrequencyMHz = 2000
                    percentOfMaximumFrequency = 85
                    performanceLimitPercent = 100
                    performanceLimitFlags = [uint32]0
                    acpiThermalZoneStatus = 'Unavailable'
                    acpiThermalZoneCelsius = @()
                    acpiThermalZoneErrorType = 'CimException'
                    queryDurationMilliseconds = 2
                }
            }
            Mock Start-Sleep { }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }

            $profile = Invoke-ThermalProfile `
                -Root $TestDrive `
                -Seconds 5 `
                -IntervalSeconds 5 `
                -CalibrationIterations 3

            $profile.observationOnly | Should -BeTrue
            $profile.summary.sampleCount | Should -Be 2
            $profile.summary.status | Should -Be 'NoProcessorPerformanceLimitObserved'
            Test-Path -LiteralPath $profile.evidencePath | Should -BeTrue
            (Get-Content -LiteralPath $profile.evidencePath -Raw) | Should -Match 'thermal-envelope-profile'
            Should -Invoke Get-ThermalPerformanceSample -Times 2
        }

        It 'contains no state-changing command' {
            $body = (Get-Command Invoke-ThermalProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|powercfg|Restart-Computer'
        }

        It 'rejects a sample interval that would exceed the requested window' {
            Mock Get-ThermalProfileSupport {
                [pscustomobject]@{ supported = $true; reason = 'supported'; thermalZoneSupported = $false }
            }

            {
                Invoke-ThermalProfile -Root $TestDrive -Seconds 5 -IntervalSeconds 6 -CalibrationIterations 3
            } | Should -Throw '*sample interval cannot exceed*'
        }

        It 'routes the public action directly to the profiler' {
            $script:Action = 'ThermalProfile'
            $script:DataRoot = $TestDrive
            $script:DurationSeconds = 5
            $script:SampleIntervalSeconds = 1
            $script:ThermalCalibrationIterations = 3
            Mock Invoke-ThermalProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-ThermalProfile -Times 1
        }
    }

    Context 'Layer 2 hardware storage-path profile' {
        It 'summarizes each physical-disk instance and preserves transport as context rather than a gain claim' {
            $inventory = [pscustomobject]@{
                physicalDisks = @(
                    [pscustomobject]@{ busType = 'SATA' }
                )
            }
            $samples = @(
                [pscustomobject]@{
                    queryDurationMilliseconds = 3
                    disks = @(
                        [pscustomobject]@{
                            instance = '0 C:'
                            transferLatencyMilliseconds = 2
                            readLatencyMilliseconds = 3
                            writeLatencyMilliseconds = 1
                            currentQueueLength = 0
                            averageQueueLength = 0.1
                            bytesPerSecond = 1000
                            transfersPerSecond = 10
                            diskTimePercent = 4
                            idleTimePercent = 96
                        }
                    )
                },
                [pscustomobject]@{
                    queryDurationMilliseconds = 5
                    disks = @(
                        [pscustomobject]@{
                            instance = '0 C:'
                            transferLatencyMilliseconds = 4
                            readLatencyMilliseconds = 5
                            writeLatencyMilliseconds = 3
                            currentQueueLength = 1
                            averageQueueLength = 0.3
                            bytesPerSecond = 3000
                            transfersPerSecond = 30
                            diskTimePercent = 8
                            idleTimePercent = 92
                        }
                    )
                }
            )

            $summary = Get-HardwareProfileSummary -Samples $samples -Inventory $inventory

            $summary.sampleCount | Should -Be 2
            $summary.observedDiskCount | Should -Be 1
            $summary.observedBusTypes | Should -Be @('SATA')
            $summary.disks[0].transferLatencyMilliseconds.median | Should -Be 3
            $summary.disks[0].currentQueueLength.p95 | Should -Be 1
            $summary.interpretation | Should -Match 'does not prove'
            $summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
        }

        It 'writes bounded redacted structured evidence without generating storage I/O' {
            Mock Get-HardwareProfileSupport {
                [pscustomobject]@{
                    supported = $true
                    provider = 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk'
                    reason = 'supported'
                    missingProperties = @()
                    physicalDiskInventoryAvailable = $true
                }
            }
            Mock Get-HardwareStorageInventory {
                [pscustomobject]@{
                    physicalDiskStatus = 'Read'
                    physicalDiskErrorType = $null
                    physicalDisks = @([pscustomobject]@{
                        deviceId = '0'
                        friendlyName = 'Test SSD'
                        manufacturer = 'Test'
                        model = 'Test SSD'
                        firmwareVersion = '1'
                        mediaType = 'SSD'
                        busType = 'SATA'
                        sizeBytes = [uint64]256000000000
                        healthStatus = 'Healthy'
                        operationalStatus = @('OK')
                    })
                    controllerDriverStatus = 'Read'
                    controllerDriverErrorType = $null
                    controllerDrivers = @()
                    redaction = 'test'
                }
            }
            Mock Measure-HardwareProfileObserver {
                [pscustomobject]@{
                    iterations = 3
                    durationMilliseconds = [pscustomobject]@{ count = 3; median = 1; p95 = 2; minimum = 1; maximum = 2 }
                    qualification = 'test'
                }
            }
            Mock Get-WindowsEnvironment { [pscustomobject]@{ windows = [pscustomobject]@{ build = '26200' } } }
            Mock Get-HardwareStorageSample {
                [pscustomobject]@{
                    timestampUtc = [DateTime]::UtcNow.ToString('o')
                    monotonicOffsetMilliseconds = 0
                    queryDurationMilliseconds = 2
                    disks = @([pscustomobject]@{
                        instance = '0 C:'
                        transferLatencyMilliseconds = 1
                        readLatencyMilliseconds = 1
                        writeLatencyMilliseconds = 1
                        currentQueueLength = 0
                        averageQueueLength = 0
                        bytesPerSecond = 0
                        transfersPerSecond = 0
                        diskTimePercent = 0
                        idleTimePercent = 100
                    })
                }
            }
            Mock Start-Sleep { }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }

            $profile = Invoke-HardwareProfile `
                -Root $TestDrive `
                -Seconds 5 `
                -IntervalSeconds 5 `
                -CalibrationIterations 3

            $profile.observationOnly | Should -BeTrue
            $profile.summary.sampleCount | Should -Be 2
            $profile.summary.observedBusTypes | Should -Be @('SATA')
            Test-Path -LiteralPath $profile.evidencePath | Should -BeTrue
            $raw = Get-Content -LiteralPath $profile.evidencePath -Raw
            $raw | Should -Match 'hardware-storage-path-profile'
            $raw | Should -Not -Match 'serialNumber|uniqueId|pnpDeviceId'
            Should -Invoke Get-HardwareStorageSample -Times 2
        }

        It 'contains no workload generator or state-changing command' {
            $body = (Get-Command Invoke-HardwareProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'DiskSpd|winsat|fsutil|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|powercfg|Restart-Computer'
        }

        It 'rejects a sample interval that would exceed the requested window' {
            Mock Get-HardwareProfileSupport {
                [pscustomobject]@{ supported = $true; reason = 'supported' }
            }

            {
                Invoke-HardwareProfile -Root $TestDrive -Seconds 5 -IntervalSeconds 6 -CalibrationIterations 3
            } | Should -Throw '*sample interval cannot exceed*'
        }

        It 'routes the public action directly to the profiler' {
            $script:Action = 'HardwareProfile'
            $script:DataRoot = $TestDrive
            $script:DurationSeconds = 5
            $script:SampleIntervalSeconds = 1
            $script:HardwareCalibrationIterations = 3
            Mock Invoke-HardwareProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-HardwareProfile -Times 1
        }
    }

    Context 'Layer 3 firmware-boundary profile' {
        It 'captures documented firmware and SMBIOS fields without serial or setting data' {
            Mock Get-NativeFirmwareType {
                [pscustomobject]@{ rawValue = [uint32]2; name = 'Uefi'; source = 'test' }
            }
            Mock Get-CimInstance {
                [pscustomobject]@{
                    Manufacturer = 'HP'
                    SMBIOSBIOSVersion = 'T76 Ver. 01.24.02'
                    ReleaseDate = [datetime]'2025-01-01T00:00:00Z'
                    SMBIOSPresent = $true
                    SMBIOSMajorVersion = 3
                    SMBIOSMinorVersion = 3
                    EmbeddedControllerMajorVersion = [byte]1
                    EmbeddedControllerMinorVersion = [byte]2
                    Status = 'OK'
                    SerialNumber = 'must-not-be-collected'
                }
            }

            $snapshot = Get-FirmwareCoreSnapshot

            $snapshot.firmwareType.name | Should -Be 'Uefi'
            $snapshot.bios.smbiosBiosVersion | Should -Be 'T76 Ver. 01.24.02'
            $snapshot.bios.smbiosVersion | Should -Be '3.3'
            $snapshot.bios.embeddedControllerMajorVersionRaw | Should -Be 1
            ($snapshot.bios.PSObject.Properties.Name -contains 'serialNumber') | Should -BeFalse
        }

        It 'treats an unavailable Secure Boot privilege as evidence rather than a failed profile' {
            Mock Get-Command { [pscustomobject]@{ Name = 'Confirm-SecureBootUEFI' } } -ParameterFilter {
                $Name -eq 'Confirm-SecureBootUEFI'
            }
            Mock Confirm-SecureBootUEFI { throw [UnauthorizedAccessException]::new('denied') }

            $state = Get-SecureBootProfileState -FirmwareType Uefi

            $state.status | Should -Be 'Unavailable'
            $state.enabled | Should -BeNullOrEmpty
            $state.errorType | Should -Be 'UnauthorizedAccessException'
        }

        It 'writes bounded structured evidence without reading BIOS setting instances' {
            Mock Get-FirmwareProfileSupport {
                [pscustomobject]@{
                    supported = $true
                    provider = 'Win32_BIOS'
                    reason = 'supported'
                    missingProperties = @()
                    firmwareType = [pscustomobject]@{ rawValue = 2; name = 'Uefi'; source = 'test' }
                }
            }
            Mock Measure-FirmwareProfileObserver {
                [pscustomobject]@{
                    iterations = 3
                    durationMilliseconds = [pscustomobject]@{ count = 3; median = 1; p95 = 2; minimum = 1; maximum = 2 }
                    qualification = 'test'
                }
            }
            Mock Get-FirmwareCoreSnapshot {
                [pscustomobject]@{
                    timestampUtc = [DateTime]::UtcNow.ToString('o')
                    queryDurationMilliseconds = 2
                    firmwareType = [pscustomobject]@{ rawValue = 2; name = 'Uefi'; source = 'test' }
                    bios = [pscustomobject]@{
                        manufacturer = 'HP'
                        smbiosBiosVersion = 'T76 Ver. 01.24.02'
                        releaseDateUtc = '2025-01-01T00:00:00.0000000Z'
                        smbiosPresent = $true
                        smbiosVersion = '3.3'
                        embeddedControllerMajorVersionRaw = 1
                        embeddedControllerMinorVersionRaw = 2
                        status = 'OK'
                    }
                    redaction = 'test'
                }
            }
            Mock Get-SecureBootProfileState {
                [pscustomobject]@{
                    status = 'Read'
                    enabled = $true
                    errorType = $null
                    durationMilliseconds = 1
                }
            }
            Mock Get-HpBiosInterfaceState {
                [pscustomobject]@{
                    namespace = 'root/HP/InstrumentedBIOS'
                    status = 'MetadataAvailable'
                    classNames = @('HP_BIOSSetting', 'HP_BIOSSettingInterface')
                    settingInstancesRead = $false
                    writeInterfaceInvoked = $false
                    errorType = $null
                    durationMilliseconds = 1
                    qualification = 'test'
                }
            }
            Mock Get-WindowsEnvironment { [pscustomobject]@{ windows = [pscustomobject]@{ build = '26200' } } }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }

            $profile = Invoke-FirmwareProfile -Root $TestDrive -CalibrationIterations 3

            $profile.observationOnly | Should -BeTrue
            $profile.summary.firmwareType | Should -Be 'Uefi'
            $profile.summary.hpBiosClassCount | Should -Be 2
            $profile.hpBiosInterface.settingInstancesRead | Should -BeFalse
            Test-Path -LiteralPath $profile.evidencePath | Should -BeTrue
            $raw = Get-Content -LiteralPath $profile.evidencePath -Raw
            $raw | Should -Match 'firmware-boundary-profile'
            $raw | Should -Not -Match 'serialNumber|systemUuid|assetTag|settingValues'
        }

        It 'contains no firmware, Secure Boot, BIOS-setting, or Windows mutation command' {
            $body = (Get-Command Invoke-FirmwareProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'Set-SecureBootUEFI|Set-HPBIOS|HP_BIOSSettingInterface|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Restart-Computer|shutdown|powercfg'
        }

        It 'routes the public action directly to the profiler' {
            $script:Action = 'FirmwareProfile'
            $script:DataRoot = $TestDrive
            $script:FirmwareCalibrationIterations = 3
            Mock Invoke-FirmwareProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-FirmwareProfile -Times 1
        }
    }

    Context 'Layer 4 driver and OEM ownership profile' {
        It 'joins package, PnP health, and service state while redacting device identity' {
            Mock Get-CimInstance {
                if ($Query -match 'Win32_PnPSignedDriver') {
                    return [pscustomobject]@{
                        DeviceID = 'PCI\VEN_1234&DEV_5678\SERIAL-SECRET'
                        DeviceClass = 'DISPLAY'
                        DriverProviderName = 'Contoso Display'
                        DriverVersion = '1.2.3.4'
                        DriverDate = [datetime]'2026-01-01T00:00:00Z'
                        InfName = 'oem42.inf'
                        IsSigned = $true
                        Signer = 'Microsoft Windows Hardware Compatibility Publisher'
                    }
                }
                return [pscustomobject]@{
                    DeviceID = 'PCI\VEN_1234&DEV_5678\SERIAL-SECRET'
                    ConfigManagerErrorCode = 0
                    Status = 'OK'
                    Service = 'testdisplay'
                    PNPClass = 'Display'
                }
            }
            Mock Get-Service {
                [pscustomobject]@{ Status = 'Running'; StartType = 'System' }
            }

            $snapshot = Get-DriverCoreSnapshot -DeviceLimit 64

            @($snapshot.devices).Count | Should -Be 1
            $snapshot.devices[0].provider | Should -Be 'Contoso Display'
            $snapshot.devices[0].serviceStatus | Should -Be 'Running'
            $snapshot.devices[0].deviceKeySha256 | Should -Match '^[0-9a-f]{64}$'
            $raw = $snapshot | ConvertTo-Json -Depth 12
            $raw | Should -Not -Match 'VEN_1234|SERIAL-SECRET'
            Should -Invoke Get-Service -Times 1 -ParameterFilter { $Name -eq 'testdisplay' }
        }

        It 'fails safely instead of silently truncating an oversized device inventory' {
            Mock Get-CimInstance {
                1..65 | ForEach-Object { [pscustomobject]@{ DeviceID = "device-$_" } }
            } -ParameterFilter { $Query -match 'Win32_PnPSignedDriver' }

            { Get-DriverCoreSnapshot -DeviceLimit 64 } | Should -Throw '*above the configured safe limit*'
        }

        It 'writes bounded structured evidence without exposing raw hardware identifiers' {
            $snapshot = [pscustomobject]@{
                timestampUtc = [DateTime]::UtcNow.ToString('o')
                durationMilliseconds = 10
                devices = @([pscustomobject]@{
                    deviceKeySha256 = ('a' * 64); deviceClass = 'DISPLAY'; pnpClass = 'Display'
                    infName = 'oem42.inf'; provider = 'Contoso'; version = '1.2.3.4'
                    dateUtc = '2026-01-01T00:00:00.0000000Z'; isSigned = $true; signer = 'WHCP'
                    configManagerErrorCode = 0; pnpStatus = 'OK'; serviceName = 'testdisplay'
                    serviceStatus = 'Running'; serviceStartType = 'System'; serviceLookup = 'Read'
                })
                packages = @([pscustomobject]@{ infName = 'oem42.inf'; provider = 'Contoso'; version = '1.2.3.4'; deviceCount = 1 })
                providerSummary = @([pscustomobject]@{ provider = 'Contoso'; deviceCount = 1 })
                classSummary = @([pscustomobject]@{ deviceClass = 'DISPLAY'; deviceCount = 1 })
                redaction = 'test redaction'
            }
            Mock Get-DriverProfileSupport {
                [pscustomobject]@{ supported = $true; providers = @('test'); missingProperties = @(); serviceControllerAvailable = $true; reason = 'supported' }
            }
            Mock Measure-DriverProfileObserver {
                [pscustomobject]@{
                    iterations = 3
                    durationMilliseconds = [pscustomobject]@{ count = 3; median = 10; p95 = 12; minimum = 9; maximum = 12 }
                    finalSnapshot = $snapshot
                    qualification = 'test'
                }
            }
            Mock Get-DriverProfileEnvironment { [pscustomobject]@{ windows = [pscustomobject]@{ build = '26200' } } }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }

            $profile = Invoke-DriverProfile -Root $TestDrive -CalibrationIterations 3 -DeviceLimit 64

            $profile.observationOnly | Should -BeTrue
            $profile.summary.deviceRecordCount | Should -Be 1
            $profile.summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
            Test-Path -LiteralPath $profile.evidencePath | Should -BeTrue
            $raw = Get-Content -LiteralPath $profile.evidencePath -Raw
            $raw | Should -Match 'driver-oem-ownership-profile'
            $raw | Should -Not -Match 'DeviceID|hardwareId|deviceName|SERIAL-SECRET'
        }

        It 'contains no driver, service, device, or registry mutation command' {
            $body = (Get-Command Invoke-DriverProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'pnputil|Update-Driver|Add-WindowsDriver|Remove-WindowsDriver|Set-Service|Stop-Service|Start-Service|Disable-PnpDevice|Enable-PnpDevice|Set-ItemProperty|Remove-ItemProperty'
        }

        It 'routes the public action directly to the profiler' {
            $script:Action = 'DriverProfile'
            $script:DataRoot = $TestDrive
            $script:DriverCalibrationIterations = 3
            $script:DriverDeviceLimit = 64
            Mock Invoke-DriverProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-DriverProfile -Times 1
        }
    }

    Context 'Layer 5 kernel-pressure profile' {
        It 'normalizes one correlated counter sample and converts disk seconds to milliseconds' {
            $counterSamples = @(Get-KernelProfileCounterCatalog | ForEach-Object {
                $value = switch ($_.key) {
                    'dpcTimePercent' { 0.25 }
                    'interruptTimePercent' { 0.10 }
                    'dpcsQueuedPerSecond' { 400 }
                    'interruptsPerSecond' { 800 }
                    'contextSwitchesPerSecond' { 12000 }
                    'processorQueueLength' { 1 }
                    'pageReadsPerSecond' { 2 }
                    'pagesInputPerSecond' { 3 }
                    'availableMemoryMb' { 8192 }
                    'diskLatencyMilliseconds' { 0.005 }
                    'diskQueueLength' { 0.5 }
                    default { 30 }
                }
                [pscustomobject]@{ Path = "\\testhost$($_.path)"; CookedValue = $value }
            })
            $set = [pscustomobject]@{
                Timestamp = [datetime]'2026-07-31T10:00:00Z'
                CounterSamples = $counterSamples
            }

            $sample = ConvertFrom-KernelCounterSampleSet -SampleSet $set

            $sample.dpcTimePercent | Should -Be 0.25
            $sample.interruptsPerSecond | Should -Be 800
            $sample.diskLatencyMilliseconds | Should -Be 5
            $sample.availableMemoryMb | Should -Be 8192
        }

        It 'summarizes raw values and repeated block medians without a performance claim' {
            $blocks = @(1..3 | ForEach-Object {
                $blockNumber = $_
                $samples = @(1..3 | ForEach-Object {
                    [pscustomobject]@{
                        processorUtilityPercent = 20 + $blockNumber
                        dpcTimePercent = [double]$blockNumber / 10
                        interruptTimePercent = 0
                        dpcsQueuedPerSecond = 300 + $blockNumber
                        interruptsPerSecond = 700 + $blockNumber
                        contextSwitchesPerSecond = 10000 + $blockNumber
                        processorQueueLength = 0
                        pageReadsPerSecond = 1
                        pagesInputPerSecond = 1
                        availableMemoryMb = 8000
                        diskLatencyMilliseconds = 2
                        diskQueueLength = 0
                    }
                })
                [pscustomobject]@{
                    blockNumber = $blockNumber
                    samples = $samples
                    metrics = Get-KernelMetricDistributions -Samples $samples
                }
            })

            $summary = Get-KernelProfileSummary -Blocks $blocks

            $summary.blockCount | Should -Be 3
            $summary.sampleCount | Should -Be 9
            $summary.rawSampleDistributions.dpcTimePercent.median | Should -Be 0.2
            $summary.blockMedianDistributions.dpcTimePercent.median | Should -Be 0.2
            $summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
        }

        It 'writes bounded raw blocks, observer qualification, and trace-tool state' {
            Mock Get-KernelProfileSupport {
                [pscustomobject]@{ supported = $true; reason = 'supported'; requiredCounters = @('test'); missingCounters = @() }
            }
            Mock Measure-KernelCounterObserver {
                [pscustomobject]@{
                    iterations = 3
                    durationMilliseconds = [pscustomobject]@{ count = 3; median = 4; p95 = 5; minimum = 3; maximum = 5 }
                    qualification = 'test'
                }
            }
            Mock Get-KernelCounterBlock {
                $samples = @(1..$SamplesPerBlock | ForEach-Object {
                    [pscustomobject]@{
                        timestampUtc = [DateTime]::UtcNow.ToString('o')
                        processorUtilityPercent = 20; dpcTimePercent = 0.1; interruptTimePercent = 0
                        dpcsQueuedPerSecond = 300; interruptsPerSecond = 700
                        contextSwitchesPerSecond = 10000; processorQueueLength = 0
                        pageReadsPerSecond = 1; pagesInputPerSecond = 1; availableMemoryMb = 8000
                        diskLatencyMilliseconds = 2; diskQueueLength = 0
                    }
                })
                [pscustomobject]@{
                    blockNumber = $BlockNumber
                    sampleCount = $samples.Count
                    sampleIntervalSeconds = $SampleIntervalSeconds
                    expectedSamplingSpanMilliseconds = 2000
                    wallDurationMilliseconds = 2010
                    observerAndSchedulingExcessMilliseconds = 10
                    samples = $samples
                    metrics = Get-KernelMetricDistributions -Samples $samples
                }
            }
            Mock Get-KernelProfileEnvironment { [pscustomobject]@{ windows = [pscustomobject]@{ build = '26200' } } }
            Mock Get-KernelTraceToolState {
                [pscustomobject]@{
                    wprAvailable = $true; wprRecordingState = 'idle'; wpaAvailable = $false
                    wpaExporterAvailable = $false; automatedModuleAttributionReady = $false
                    traceStarted = $false; qualification = 'test'
                }
            }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }

            $profile = Invoke-KernelProfile `
                -Root $TestDrive `
                -BlockCount 3 `
                -SamplesPerBlock 3 `
                -SampleIntervalSeconds 1 `
                -CalibrationIterations 3

            $profile.observationOnly | Should -BeTrue
            $profile.summary.blockCount | Should -Be 3
            $profile.summary.sampleCount | Should -Be 9
            $profile.instrumentation.traceTools.traceStarted | Should -BeFalse
            $profile.summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
            Test-Path -LiteralPath $profile.evidencePath | Should -BeTrue
            (Get-Content -LiteralPath $profile.evidencePath -Raw) | Should -Match 'kernel-pressure-profile'
            Should -Invoke Get-KernelCounterBlock -Times 3
        }

        It 'contains no scheduler, interrupt, driver, service, registry, or power mutation command' {
            $body = (Get-Command Invoke-KernelProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|Start-Service|pnputil|powercfg|bcdedit|wpr\.exe.*-(start|stop|cancel)|Restart-Computer'
        }

        It 'routes the public action directly to the profiler' {
            $script:Action = 'KernelProfile'
            $script:DataRoot = $TestDrive
            $script:KernelBlockCount = 3
            $script:KernelSamplesPerBlock = 3
            $script:KernelSampleIntervalSeconds = 1
            $script:KernelCalibrationIterations = 3
            Mock Invoke-KernelProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-KernelProfile -Times 1
        }
    }

    Context 'Layer 6 power-policy truth map' {
        It 'maps documented user preferences and effective runtime modes without conflating them' {
            (ConvertTo-ConfiguredPowerModeName -Guid ([guid]'00000000-0000-0000-0000-000000000000')) | Should -Be 'Balanced'
            (ConvertTo-ConfiguredPowerModeName -Guid ([guid]'961cc777-2547-4f9d-8174-7d86181b8a7a')) | Should -Be 'BestEfficiency'
            (ConvertTo-ConfiguredPowerModeName -Guid ([guid]'ded574b5-45a0-4f42-8737-46345c09c238')) | Should -Be 'BestPerformance'
            (ConvertTo-EffectivePowerModeName -Value 4) | Should -Be 'MaxPerformance'
            (ConvertTo-EffectivePowerModeName -Value 99) | Should -Be 'Unknown'
        }

        It 'reads AC and DC values for all five documented processor-policy settings' {
            Mock Get-NativePowerPolicyValue {
                [pscustomobject]@{
                    ResultCode = [uint32]0
                    RegistryType = [uint32]4
                    SizeBytes = [uint32]4
                    Value = [uint32]$(if ($AcPower) { 33 } else { 50 })
                }
            }

            $settings = @(Get-ProcessorPowerPolicy -ActiveSchemeGuid ([guid]'381b4222-f694-41f0-9685-ff5bb260df2e'))

            $settings.Count | Should -Be 5
            @($settings | Where-Object { $_.supported }).Count | Should -Be 5
            $settings[0].ac.value | Should -Be 33
            $settings[0].dc.value | Should -Be 50
            Should -Invoke Get-NativePowerPolicyValue -Times 10
        }

        It 'summarizes repeated policy snapshots as a baseline rather than a gain claim' {
            $samples = @(1..3 | ForEach-Object {
                [pscustomobject]@{
                    queryDurationMilliseconds = 2 + $_
                    activeScheme = [pscustomobject]@{ guid = '381b4222-f694-41f0-9685-ff5bb260df2e' }
                    userAcMode = [pscustomobject]@{ name = 'BestPerformance' }
                    userDcMode = [pscustomobject]@{ name = 'BestEfficiency' }
                    effectiveMode = [pscustomobject]@{ name = 'MaxPerformance' }
                    systemPowerStatus = [pscustomobject]@{ acLineStatus = 'Online'; batterySaverOn = $false }
                }
            })
            $policy = @(Get-PowerPolicySettingCatalog | ForEach-Object { [pscustomobject]@{ supported = $true } })
            $ownership = [pscustomobject]@{ intelDynamicTuningService = [pscustomobject]@{ State = 'Running' } }

            $summary = Get-PowerProfileSummary -Samples $samples -ProcessorPolicy $policy -PlatformOwnership $ownership

            $summary.sampleCount | Should -Be 3
            $summary.consistentAcrossSamples | Should -BeTrue
            $summary.supportedProcessorSettingCount | Should -Be 5
            $summary.queryDurationMilliseconds.median | Should -Be 4
            $summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
        }

        It 'writes bounded raw snapshots, policy values, ownership, and observer qualification' {
            $snapshot = [pscustomobject]@{
                timestampUtc = '2026-07-31T13:00:00.0000000Z'
                queryDurationMilliseconds = 2
                activeScheme = [pscustomobject]@{ resultCode = 0; guid = '381b4222-f694-41f0-9685-ff5bb260df2e' }
                userAcMode = [pscustomobject]@{ resultCode = 0; guid = 'ded574b5-45a0-4f42-8737-46345c09c238'; name = 'BestPerformance' }
                userDcMode = [pscustomobject]@{ resultCode = 0; guid = '961cc777-2547-4f9d-8174-7d86181b8a7a'; name = 'BestEfficiency' }
                effectiveMode = [pscustomobject]@{ registerResultCode = 0; unregisterResultCode = 0; callbackReceived = $true; value = 4; name = 'MaxPerformance' }
                systemPowerStatus = [pscustomobject]@{ available = $true; acLineStatus = 'Online'; batterySaverOn = $false }
            }
            $policy = @(Get-PowerPolicySettingCatalog | ForEach-Object {
                [pscustomobject]@{
                    key = $_.key; alias = $_.alias; guid = $_.guid; unit = $_.unit
                    interpretation = $_.interpretation; supported = $true
                    ac = [pscustomobject]@{ resultCode = 0; registryType = 4; sizeBytes = 4; value = 33 }
                    dc = [pscustomobject]@{ resultCode = 0; registryType = 4; sizeBytes = 4; value = 50 }
                }
            })
            Mock Get-PowerProfileSupport { [pscustomobject]@{ supported = $true; reason = 'supported'; probe = $snapshot } }
            Mock Measure-PowerProfileObserver {
                [pscustomobject]@{ iterations = 3; durationMilliseconds = [pscustomobject]@{ count = 3; median = 2; p95 = 3; minimum = 1; maximum = 3 }; qualification = 'test' }
            }
            Mock Get-PowerModeSnapshot { return $snapshot }
            Mock Get-ProcessorPowerPolicy { return $policy }
            Mock Get-PowerPlatformOwnership {
                [pscustomobject]@{
                    queryDurationMilliseconds = 5
                    intelDynamicTuningService = [pscustomobject]@{ Name = 'esifsvc'; State = 'Running'; StartMode = 'Auto' }
                    intelDynamicTuningDriverGroups = @([pscustomobject]@{ role = 'Intel(R) Dynamic Tuning Manager'; provider = 'Intel'; version = '1.0'; signed = $true; count = 1 })
                    errors = @(); interpretation = 'test'
                }
            }
            Mock Get-PowerProfileEnvironment { [pscustomobject]@{ windows = [pscustomobject]@{ build = '26200' } } }
            Mock Start-Sleep { }
            Mock Write-StructuredEvent { }
            Mock Write-Host { }

            $profile = Invoke-PowerProfile `
                -Root $TestDrive `
                -SampleCount 3 `
                -SampleIntervalMilliseconds 100 `
                -CalibrationIterations 3 `
                -CallbackTimeoutMilliseconds 1000

            $profile.observationOnly | Should -BeTrue
            $profile.samples.Count | Should -Be 3
            $profile.processorPolicy.Count | Should -Be 5
            $profile.summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
            Test-Path -LiteralPath $profile.evidencePath | Should -BeTrue
            (Get-Content -LiteralPath $profile.evidencePath -Raw) | Should -Match 'power-policy-profile'
            Should -Invoke Get-PowerModeSnapshot -Times 3
        }

        It 'contains no power, OEM service, driver, registry, or reboot mutation command' {
            $body = (Get-Command Invoke-PowerProfile).ScriptBlock.ToString()
            $body | Should -Not -Match 'powercfg|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Set-Service|Stop-Service|Start-Service|pnputil|Restart-Computer|shutdown'
        }

        It 'routes the public action directly to the profiler' {
            $script:Action = 'PowerProfile'
            $script:DataRoot = $TestDrive
            $script:PowerProfileSampleCount = 3
            $script:PowerProfileSampleIntervalMilliseconds = 100
            $script:PowerProfileCalibrationIterations = 3
            $script:PowerProfileCallbackTimeoutMilliseconds = 1000
            Mock Invoke-PowerProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-PowerProfile -Times 1
        }
    }

    Context 'Layer 7 security protection activity profile' {
        It 'reads a fixed counter session without exposing process IDs or paths' {
            $records = @()
            foreach ($definition in @(
                @{ metric = 'cpuLogicalProcessorPercent'; value = 80 },
                @{ metric = 'readBytesPerSecond'; value = 1024 },
                @{ metric = 'writeBytesPerSecond'; value = 2048 },
                @{ metric = 'workingSetPrivateBytes'; value = 4096 }
            )) {
                $counter = [pscustomobject]@{ sample = [double]$definition.value }
                $counter | Add-Member -MemberType ScriptMethod -Name NextValue -Value { return $this.sample }
                $records += [pscustomobject]@{
                    processName = 'msmpeng'
                    role = 'Microsoft Defender Antivirus engine'
                    instance = 'MsMpEng'
                    metric = $definition.metric
                    counter = $counter
                }
            }
            $session = [pscustomobject]@{ records = $records }

            $sample = Get-SecurityCounterSnapshot -Session $session -LogicalProcessorCount 8

            $sample.status | Should -Be 'Measured'
            $sample.cpuLogicalProcessorPercent | Should -Be 80
            $sample.cpuMachinePercent | Should -Be 10
            $sample.readBytesPerSecond | Should -Be 1024
            $sample.writeBytesPerSecond | Should -Be 2048
            $sample.workingSetPrivateBytes | Should -Be 4096
            $sample.processes[0].PSObject.Properties.Name | Should -Not -Contain 'processId'
            $sample.processes[0].PSObject.Properties.Name | Should -Not -Contain 'path'
        }

        It 'summarizes repeated samples as a baseline rather than a gain' {
            $samples = @(
                [pscustomobject]@{ status = 'Measured'; observedProcessCount = 2; cpuLogicalProcessorPercent = 8; cpuMachinePercent = 1; readBytesPerSecond = 0; writeBytesPerSecond = 0; workingSetPrivateBytes = 200; queryDurationMilliseconds = 2 },
                [pscustomobject]@{ status = 'Measured'; observedProcessCount = 2; cpuLogicalProcessorPercent = 16; cpuMachinePercent = 2; readBytesPerSecond = 10; writeBytesPerSecond = 20; workingSetPrivateBytes = 220; queryDurationMilliseconds = 3 },
                [pscustomobject]@{ status = 'Measured'; observedProcessCount = 2; cpuLogicalProcessorPercent = 24; cpuMachinePercent = 3; readBytesPerSecond = 20; writeBytesPerSecond = 40; workingSetPrivateBytes = 240; queryDurationMilliseconds = 4 }
            )

            $summary = Get-SecurityProfileSummary -Samples $samples

            $summary.measuredSampleCount | Should -Be 3
            $summary.metrics.cpuMachinePercent.median | Should -Be 2
            $summary.metrics.workingSetPrivateBytes.median | Should -Be 220
            $summary.decision | Should -Be 'BaselineOnlyNoPerformanceClaim'
        }

        It 'collects only selected protection state and never asks for exclusions or rules' {
            Mock Get-MpComputerStatus {
                [pscustomobject]@{ AMServiceEnabled = $true; AntivirusEnabled = $true; AntispywareEnabled = $true; BehaviorMonitorEnabled = $true; IoavProtectionEnabled = $true; NISEnabled = $true; OnAccessProtectionEnabled = $true; RealTimeProtectionEnabled = $true; IsTamperProtected = $true; AMRunningMode = 'Normal'; AMProductVersion = '4.18'; AMEngineVersion = '1.1'; AntivirusSignatureVersion = '1.2' }
            }
            Mock Get-NetFirewallProfile {
                [pscustomobject]@{ Name = 'Public'; Enabled = $true; DefaultInboundAction = 'Block'; DefaultOutboundAction = 'Allow' }
            }
            Mock Get-CimInstance {
                [pscustomobject]@{ VirtualizationBasedSecurityStatus = 2; SecurityServicesConfigured = @(2); SecurityServicesRunning = @(1, 2); CodeIntegrityPolicyEnforcementStatus = 2; UsermodeCodeIntegrityPolicyEnforcementStatus = 2 }
            }

            $state = Get-SecurityProtectionState

            $state.defender.realTimeProtectionEnabled | Should -BeTrue
            $state.defender.isTamperProtected | Should -BeTrue
            $state.firewall.profiles[0].enabled | Should -BeTrue
            $state.deviceGuard.virtualizationBasedSecurityStatus | Should -Be 2
            $state.defender.PSObject.Properties.Name | Should -Not -Contain 'ExclusionPath'
            $state.firewall.profiles[0].PSObject.Properties.Name | Should -Not -Contain 'Rules'
        }

        It 'contains no security, firewall, service, policy, registry, or reboot mutation command' {
            $body = @(
                (Get-Command Invoke-SecurityProfile).ScriptBlock.ToString(),
                (Get-Command Get-SecurityProtectionState).ScriptBlock.ToString(),
                (Get-Command Get-SecurityCounterSnapshot).ScriptBlock.ToString()
            ) -join "`n"
            $body | Should -Not -Match 'Set-MpPreference|Add-MpPreference|Remove-MpPreference|Set-NetFirewall|Set-Service|Stop-Service|Start-Service|Set-ItemProperty|New-ItemProperty|Remove-ItemProperty|Restart-Computer|shutdown'
        }

        It 'routes the public action directly to the profiler' {
            $script:Action = 'SecurityProfile'
            $script:DataRoot = $TestDrive
            $script:DurationSeconds = 5
            $script:SecurityProfileSampleIntervalMilliseconds = 1000
            $script:SecurityProfileCalibrationIterations = 3
            Mock Invoke-SecurityProfile { }

            Invoke-ZBookPerfMain

            Should -Invoke Invoke-SecurityProfile -Times 1
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

        It 'shows the compact gray Lacksan mark and red UX-ROM accent only once per loaded script' {
            $script:SplashShown = $false
            Mock Write-Host { }

            Show-UxRomSplash
            Show-UxRomSplash

            $script:SplashShown | Should -BeTrue
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -match '\|_____' -and $ForegroundColor -eq 'Gray'
            }
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -eq '                    U X - R O M' -and $ForegroundColor -eq 'Red'
            }
            Should -Invoke Write-Host -Times 1 -ParameterFilter {
                $Object -match 'Loading the twelve performance layers'
            }
        }

        It 'does not redraw the startup art whenever the menu returns' {
            Mock Read-Host { return 'Q' }
            Mock Write-Host { }
            Mock Show-UxRomHeader { }

            Show-ZBookPerfMenu | Should -Be 'Q'

            Should -Invoke Show-UxRomHeader -Times 0
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
            Mock Invoke-ThermalProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'thermal.json') }
            }
            Mock Invoke-HardwareProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'hardware.json') }
            }
            Mock Invoke-FirmwareProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'firmware.json') }
            }
            Mock Invoke-DriverProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'drivers.json') }
            }
            Mock Invoke-KernelProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'kernel.json') }
            }
            Mock Invoke-PowerProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'power.json') }
            }
            Mock Invoke-SecurityProfile {
                [pscustomobject]@{ evidencePath = (Join-Path $TestDrive 'security.json') }
            }
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
                ThermalCalibration = 3; HardwareCalibration = 3; FirmwareCalibration = 3
                DriverCalibration = 3; DriverLimit = 64
                KernelBlocks = 3; KernelSamples = 3; KernelInterval = 1; KernelCalibration = 3
                PowerSamples = 3; PowerIntervalMilliseconds = 100; PowerCalibration = 3; PowerCallbackTimeout = 1000
                SecurityIntervalMilliseconds = 1000; SecurityCalibration = 3
                ShellRuns = 1; ShellWarmups = 0; ShellTimeout = 1000; ShellCalibration = 5
                WorkloadNames = @('explorer.exe'); WorkloadInterval = 1000; WorkloadCalibration = 3
                DependencyPaths = @($TestDrive); DependencyEndpoints = @()
                DependencyRuns = 1; DependencyTimeout = 250; DependencyCalibration = 3
            }

            $result = Invoke-FullSystemDiagnostics -Root $TestDrive -Runtime $runtime

            $result.observationOnly | Should -BeTrue
            $result.coveredLayers | Should -Be @(1, 2, 3, 4, 5, 6, 7, 10, 11, 12)
            $result.evidence.storagePath | Should -Match 'hardware.json'
            $result.evidence.firmwareBoundary | Should -Match 'firmware.json'
            $result.evidence.driverOwnership | Should -Match 'drivers.json'
            $result.evidence.kernelPressure | Should -Match 'kernel.json'
            $result.evidence.powerPolicy | Should -Match 'power.json'
            $result.evidence.securityActivity | Should -Match 'security.json'
            Test-Path -LiteralPath $result.evidence.systemBaseline | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $TestDrive 'measurements') | Should -BeTrue
            Should -Invoke Invoke-Measurement -Times 1
            Should -Invoke Invoke-ThermalProfile -Times 1
            Should -Invoke Invoke-HardwareProfile -Times 1
            Should -Invoke Invoke-FirmwareProfile -Times 1
            Should -Invoke Invoke-DriverProfile -Times 1
            Should -Invoke Invoke-KernelProfile -Times 1
            Should -Invoke Invoke-PowerProfile -Times 1
            Should -Invoke Invoke-SecurityProfile -Times 1
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

#requires -Version 5.1

<#
.SYNOPSIS
    Native PowerShell work-progress surface for interactive UX-ROM operations.

.DESCRIPTION
    Adds immediate, restrained Write-Progress feedback around long-running layer
    assessments and performance measurements. Redirected and automation runs stay
    quiet and deterministic. This file is dot-sourced after the core controller so
    the UI wrappers can preserve the core engineering behavior while improving the
    interactive work-in-progress surface.
#>

Set-StrictMode -Version 2.0

function Test-UxRomWorkProgressEnabled {
    if (Get-Command Test-UxRomAnimationEnabled -ErrorAction SilentlyContinue) {
        return [bool](Test-UxRomAnimationEnabled)
    }
    if ($Host.Name -ne 'ConsoleHost') { return $false }
    if (-not [Environment]::UserInteractive) { return $false }
    try {
        if ([Console]::IsOutputRedirected) { return $false }
    } catch {
        return $false
    }
    return $true
}

function Write-UxRomWorkProgress {
    param(
        [Parameter(Mandatory = $true)][string]$Activity,
        [string]$Status = '',
        [int]$PercentComplete = -1,
        [int]$SecondsRemaining = -1,
        [switch]$Completed
    )

    if (-not (Test-UxRomWorkProgressEnabled)) { return }

    if ($Completed) {
        Write-Progress -Activity $Activity -Completed
        return
    }

    $arguments = @{
        Activity = $Activity
        Status = $Status
        PercentComplete = $PercentComplete
    }
    if ($SecondsRemaining -ge 0) {
        $arguments.SecondsRemaining = $SecondsRemaining
    }
    Write-Progress @arguments
}

# Preserve the full core assessment behavior and add an immediate stock PowerShell
# progress surface before potentially slow profile initialization begins.
$script:UxRomCoreInvokeLayerAssessmentStep = ${function:Invoke-LayerAssessmentStep}
function Invoke-LayerAssessmentStep {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State,
        [int]$Seconds,
        [int]$Interval,
        [switch]$SkipTrace,
        [int]$ThermalCalibration,
        [int]$HardwareCalibration,
        [int]$FirmwareCalibration,
        [int]$DriverCalibration,
        [int]$DriverLimit,
        [int]$KernelBlocks,
        [int]$KernelSamples,
        [int]$KernelInterval,
        [int]$KernelCalibration,
        [int]$PowerSamples,
        [int]$PowerIntervalMilliseconds,
        [int]$PowerCalibration,
        [int]$PowerCallbackTimeout,
        [int]$SecurityIntervalMilliseconds,
        [int]$SecurityCalibration,
        [int]$ShellRuns,
        [int]$ShellWarmups,
        [int]$ShellTimeout,
        [int]$ShellCalibration,
        [string[]]$WorkloadNames,
        [int]$WorkloadInterval,
        [int]$WorkloadCalibration,
        [string[]]$DependencyPaths,
        [string[]]$DependencyEndpoints,
        [int]$DependencyRuns,
        [int]$DependencyTimeout,
        [int]$DependencyCalibration,
        [switch]$DryRun
    )

    $layer = Get-PerformanceLayer -Number ([int]$State.currentLayer)
    $activity = "Layer $($layer.number): $($layer.name)"
    Write-UxRomWorkProgress `
        -Activity $activity `
        -Status 'Running the required internal baseline'
    try {
        & $script:UxRomCoreInvokeLayerAssessmentStep @PSBoundParameters
    } finally {
        Write-UxRomWorkProgress -Activity $activity -Completed
    }
}

# Layer 5 contains several synchronous Get-Counter windows. Keep those exact
# measurement calls and evidence fields, while exposing each real phase through
# the native progress surface so the console never appears idle between actions.
function Invoke-KernelProfile {
    param(
        [string]$Root,
        [ValidateRange(3, 15)][int]$BlockCount,
        [ValidateRange(3, 60)][int]$SamplesPerBlock,
        [ValidateRange(1, 10)][int]$SampleIntervalSeconds,
        [ValidateRange(3, 25)][int]$CalibrationIterations
    )

    $activity = 'Layer 5 kernel-pressure profile'
    Write-UxRomWorkProgress -Activity $activity -Status 'Checking required performance counters'
    try {
        $support = Get-KernelProfileSupport
        if (-not $support.supported) {
            throw "Kernel-pressure profiling is unsupported: $($support.reason)"
        }

        Ensure-DataDirectories -Root $Root
        Write-UxRomWorkProgress `
            -Activity $activity `
            -Status "Calibrating counter observer ($CalibrationIterations runs)" `
            -PercentComplete 5
        $observer = Measure-KernelCounterObserver -Iterations $CalibrationIterations

        $blocks = @()
        $expectedBlockSeconds = [Math]::Max(1, (($SamplesPerBlock - 1) * $SampleIntervalSeconds))
        for ($blockNumber = 1; $blockNumber -le $BlockCount; $blockNumber++) {
            $blockStartPercent = 10 + [int][Math]::Floor((($blockNumber - 1) / [double]$BlockCount) * 65)
            $remainingSeconds = [int](($BlockCount - $blockNumber + 1) * $expectedBlockSeconds)
            Write-UxRomWorkProgress `
                -Activity $activity `
                -Status "Collecting block $blockNumber of $BlockCount ($SamplesPerBlock samples at ${SampleIntervalSeconds}s)" `
                -PercentComplete $blockStartPercent `
                -SecondsRemaining $remainingSeconds

            $blocks += Get-KernelCounterBlock `
                -BlockNumber $blockNumber `
                -SamplesPerBlock $SamplesPerBlock `
                -SampleIntervalSeconds $SampleIntervalSeconds

            $blockDonePercent = 10 + [int][Math]::Floor(($blockNumber / [double]$BlockCount) * 65)
            Write-UxRomWorkProgress `
                -Activity $activity `
                -Status "Completed block $blockNumber of $BlockCount" `
                -PercentComplete $blockDonePercent
        }

        Write-UxRomWorkProgress -Activity $activity -Status 'Reading Windows environment' -PercentComplete 80
        $environment = Get-KernelProfileEnvironment

        Write-UxRomWorkProgress -Activity $activity -Status 'Checking trace-tool availability' -PercentComplete 87
        $traceTools = Get-KernelTraceToolState

        Write-UxRomWorkProgress -Activity $activity -Status 'Calculating kernel-pressure summary' -PercentComplete 93
        $summary = Get-KernelProfileSummary -Blocks $blocks

        $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
        $runSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
        $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-$runSuffix-kernel-pressure-profile.json"
        $profile = [pscustomobject][ordered]@{
            schemaVersion = $script:SchemaVersion
            experimentId = $script:ExperimentId
            layer = 5
            kind = 'kernel-pressure-profile'
            capturedUtc = @($blocks[0].samples)[0].timestampUtc
            completedUtc = [DateTime]::UtcNow.ToString('o')
            observationOnly = $true
            support = $support
            environment = $environment
            requested = [pscustomobject][ordered]@{
                blockCount = $BlockCount
                samplesPerBlock = $SamplesPerBlock
                sampleIntervalSeconds = $SampleIntervalSeconds
                calibrationIterations = $CalibrationIterations
                maximumSamplingWindowSeconds = ($BlockCount * (($SamplesPerBlock - 1) * $SampleIntervalSeconds))
            }
            instrumentation = [pscustomobject][ordered]@{
                source = 'Local Windows performance counters through Get-Counter'
                timer = 'System.Diagnostics.Stopwatch'
                observerCalibration = $observer
                traceTools = $traceTools
                qualification = 'Each block retains its complete raw sample series, wall duration, expected inter-sample span, and combined observer/scheduling excess. Results are not overhead-corrected.'
            }
            collectionScope = 'Twelve aggregate counters only. No process, thread, stack, module, device, driver, file, path, network identity, command line, credential, or customer content is collected.'
            counterCatalog = @(Get-KernelProfileCounterCatalog)
            blocks = @($blocks)
            summary = $summary
            evidencePath = $evidencePath
        }

        Write-UxRomWorkProgress -Activity $activity -Status 'Saving kernel-pressure evidence' -PercentComplete 98
        $profile | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
        try {
            Write-StructuredEvent -Root $Root -Level Information -Event 'kernel-pressure-profile-complete' -Data @{
                evidencePath = $evidencePath
                blockCount = $summary.blockCount
                sampleCount = $summary.sampleCount
                dpcTimeMedianPercent = $summary.rawSampleDistributions.dpcTimePercent.median
                interruptTimeMedianPercent = $summary.rawSampleDistributions.interruptTimePercent.median
                observationOnly = $true
            }
        } catch {
            Write-Warning "The kernel profile was saved, but the optional event journal could not be updated ($($_.Exception.GetType().Name))."
        }

        Write-UxRomWorkProgress -Activity $activity -Status 'Complete' -PercentComplete 100
        Write-Host ''
        Write-Host 'Layer 5 kernel-pressure profile (observation only)' -ForegroundColor Cyan
        Write-Host "Blocks / samples: $($summary.blockCount) / $($summary.sampleCount)"
        Write-Host "DPC / interrupt time median (%): $($summary.rawSampleDistributions.dpcTimePercent.median) / $($summary.rawSampleDistributions.interruptTimePercent.median)"
        Write-Host "DPC queue / interrupt rate median: $($summary.rawSampleDistributions.dpcsQueuedPerSecond.median) / $($summary.rawSampleDistributions.interruptsPerSecond.median)"
        Write-Host "Context switches / processor queue median: $($summary.rawSampleDistributions.contextSwitchesPerSecond.median) / $($summary.rawSampleDistributions.processorQueueLength.median)"
        Write-Host "Disk latency / queue median: $($summary.rawSampleDistributions.diskLatencyMilliseconds.median) ms / $($summary.rawSampleDistributions.diskQueueLength.median)"
        Write-Host $summary.interpretation -ForegroundColor DarkYellow
        Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
        Write-Host 'No scheduler, interrupt, memory, storage, driver, service, registry, power, or Windows setting was changed.' -ForegroundColor DarkYellow
        return $profile
    } finally {
        Write-UxRomWorkProgress -Activity $activity -Completed
    }
}

# Replace only the presentation around the existing EXP-047 measurement contract.
# Collection, trace handling, evidence schema, session state, and summary behavior
# remain equivalent to the core implementation.
function Invoke-Measurement {
    param(
        [ValidateSet('baseline', 'after')][string]$Kind,
        [int]$Seconds,
        [int]$Interval,
        [string]$Root,
        [switch]$SkipTrace
    )

    $activity = "Capturing $Kind performance evidence"
    Write-UxRomWorkProgress -Activity $activity -Status 'Preparing measurement session'

    $trace = $null
    $stopwatch = $null
    try {
        Ensure-DataDirectories -Root $Root
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')

        Write-UxRomWorkProgress -Activity $activity -Status 'Reading Windows and hardware state'
        $environment = Get-WindowsEnvironment

        $traceStatus = if ($SkipTrace) {
            'Preparing performance counters'
        } else {
            'Starting Windows performance trace'
        }
        Write-UxRomWorkProgress -Activity $activity -Status $traceStatus
        $trace = Start-WprCapture -Root $Root -Stamp "$stamp-$Kind" -Skip:$SkipTrace

        $samples = New-Object System.Collections.ArrayList
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        try {
            while ($stopwatch.Elapsed.TotalSeconds -lt $Seconds) {
                [void]$samples.Add((Get-PerformanceSample))
                $elapsed = [Math]::Min([double]$Seconds, $stopwatch.Elapsed.TotalSeconds)
                $fraction = if ($Seconds -gt 0) { $elapsed / [double]$Seconds } else { 1.0 }
                $percent = [Math]::Min(90, [Math]::Max(10, 10 + [int][Math]::Floor($fraction * 80)))
                $remaining = [Math]::Max(0, [int][Math]::Ceiling($Seconds - $elapsed))
                $sampleWord = if ($samples.Count -eq 1) { 'sample' } else { 'samples' }
                Write-UxRomWorkProgress `
                    -Activity $activity `
                    -Status "$($samples.Count) $sampleWord captured" `
                    -PercentComplete $percent `
                    -SecondsRemaining $remaining
                if ($stopwatch.Elapsed.TotalSeconds -lt $Seconds) {
                    Start-Sleep -Seconds $Interval
                }
            }
        } finally {
            if ($stopwatch) { $stopwatch.Stop() }
            Write-UxRomWorkProgress -Activity $activity -Status 'Finalizing Windows performance trace' -PercentComplete 92
            if ($null -ne $trace) {
                $trace = Stop-WprCapture -Trace $trace
            }
        }

        Write-UxRomWorkProgress -Activity $activity -Status 'Calculating measurement summary' -PercentComplete 96
        $summary = Get-MeasurementSummary -Samples @($samples) -Environment $environment
        $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-$Kind.json"
        $measurement = [pscustomobject][ordered]@{
            schemaVersion = $script:SchemaVersion
            experimentId = $script:ExperimentId
            kind = $Kind
            requestedDurationSeconds = $Seconds
            actualDurationSeconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
            sampleIntervalSeconds = $Interval
            instrumentation = 'Get-Counter with CIM fallback; per-process CIM snapshots; optional WPR GeneralProfile + CPU + DiskIO'
            instrumentationQualification = 'This sampling adds CPU and I/O overhead. Treat it as diagnostic evidence, not a zero-overhead benchmark.'
            environment = $environment
            trace = $trace
            samples = @($samples)
            summary = $summary
            evidencePath = $evidencePath
        }

        Write-UxRomWorkProgress -Activity $activity -Status 'Saving evidence' -PercentComplete 98
        $measurement | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8

        $sessionPath = Join-Path $Root 'session.json'
        $session = if (Test-Path -LiteralPath $sessionPath) {
            Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
        } else {
            [pscustomobject][ordered]@{ schemaVersion = $script:SchemaVersion; baselinePath = $null; afterPath = $null }
        }
        if ($Kind -eq 'baseline') { $session.baselinePath = $evidencePath } else { $session.afterPath = $evidencePath }
        $session | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $sessionPath -Encoding UTF8
        Write-StructuredEvent -Root $Root -Level Information -Event 'measurement-complete' -Data @{ kind = $Kind; evidencePath = $evidencePath; traceStatus = $trace.status }

        Write-UxRomWorkProgress -Activity $activity -Status 'Complete' -PercentComplete 100
        Show-MeasurementSummary -Measurement $measurement
        return $measurement
    } finally {
        Write-UxRomWorkProgress -Activity $activity -Completed
    }
}

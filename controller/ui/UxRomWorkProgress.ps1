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

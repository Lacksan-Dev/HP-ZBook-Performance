#requires -Version 5.1

<#
.SYNOPSIS
    Lacksan UX-ROM bootstrap and self-managed enrollment maintenance entrypoint.

.DESCRIPTION
    Preserves the existing UX-ROM performance controller while adding EXP-137,
    an explicitly operator-authorized self-managed Workplace/MDM cleanup path.
    The cleanup captures enrollment state, removes captured enrollment artifacts,
    reruns EXP-071, reboots once, resumes automatically, and retains evidence.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Menu', 'FullDiagnostics', 'ApplyAll', 'LayerWorkflow', 'LayerMap', 'Analyze', 'Watch', 'ThermalProfile', 'HardwareProfile', 'FirmwareProfile', 'DriverProfile', 'KernelProfile', 'PowerProfile', 'SecurityProfile', 'ShellProfile', 'WorkloadProfile', 'DependencyProfile', 'Enhance', 'Remeasure', 'Revert', 'Status', 'EnrollmentCleanup', 'EnrollmentCleanupCheck', 'EnrollmentCleanupRollback')]
    [string]$Action = 'Menu',

    [switch]$FullDiagnostics,
    [switch]$ApplyAll,
    [switch]$LayerWorkflow,
    [switch]$Analyze,
    [switch]$Watch,
    [switch]$ThermalProfile,
    [switch]$HardwareProfile,
    [switch]$FirmwareProfile,
    [switch]$DriverProfile,
    [switch]$KernelProfile,
    [switch]$PowerProfile,
    [switch]$SecurityProfile,
    [switch]$ShellProfile,
    [switch]$WorkloadProfile,
    [switch]$DependencyProfile,
    [switch]$Enhance,
    [switch]$Remeasure,
    [switch]$Revert,
    [switch]$EnrollmentCleanup,

    [Alias('Candidate')]
    [ValidateSet('', 'PowerAc', 'MmcssResponsiveness', 'NtfsLastAccess', 'VisualEffects', 'FastStartupDiagnostic')]
    [string]$EnhancementCandidate,

    [ValidateRange(5, 3600)]
    [int]$DurationSeconds = 30,

    [ValidateRange(1, 60)]
    [int]$SampleIntervalSeconds = 2,

    [ValidateRange(1, 25)]
    [int]$Top = 8,

    [ValidateRange(0, 100000)]
    [int]$WatchMaxSamples = 0,

    [ValidateRange(3, 25)]
    [int]$ThermalCalibrationIterations = 5,

    [ValidateRange(3, 25)]
    [int]$HardwareCalibrationIterations = 5,

    [ValidateRange(3, 25)]
    [int]$FirmwareCalibrationIterations = 5,

    [ValidateRange(3, 25)]
    [int]$DriverCalibrationIterations = 3,

    [ValidateRange(64, 2048)]
    [int]$DriverDeviceLimit = 512,

    [ValidateRange(3, 15)]
    [int]$KernelBlockCount = 3,

    [ValidateRange(3, 60)]
    [int]$KernelSamplesPerBlock = 5,

    [ValidateRange(1, 10)]
    [int]$KernelSampleIntervalSeconds = 1,

    [ValidateRange(3, 25)]
    [int]$KernelCalibrationIterations = 3,

    [ValidateRange(3, 30)]
    [int]$PowerProfileSampleCount = 5,

    [ValidateRange(100, 5000)]
    [int]$PowerProfileSampleIntervalMilliseconds = 500,

    [ValidateRange(3, 25)]
    [int]$PowerProfileCalibrationIterations = 5,

    [ValidateRange(100, 5000)]
    [int]$PowerProfileCallbackTimeoutMilliseconds = 1000,

    [ValidateRange(250, 5000)]
    [int]$SecurityProfileSampleIntervalMilliseconds = 2000,

    [ValidateRange(3, 25)]
    [int]$SecurityProfileCalibrationIterations = 5,

    [ValidateRange(1, 25)]
    [int]$ShellRunCount = 5,

    [ValidateRange(0, 5)]
    [int]$ShellWarmupRunCount = 1,

    [ValidateRange(1000, 30000)]
    [int]$ShellTimeoutMilliseconds = 10000,

    [ValidateRange(5, 100)]
    [int]$ShellProbeCalibrationIterations = 25,

    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$')]
    [string[]]$WorkloadProcessName = @('explorer.exe'),

    [ValidateRange(250, 5000)]
    [int]$WorkloadSampleIntervalMilliseconds = 1000,

    [ValidateRange(3, 25)]
    [int]$WorkloadCalibrationIterations = 5,

    [string[]]$DependencyPath = @(),
    [string[]]$DependencyEndpoint = @(),

    [ValidateRange(1, 10)]
    [int]$DependencyProbeRunCount = 3,

    [ValidateRange(100, 10000)]
    [int]$DependencyTimeoutMilliseconds = 1500,

    [ValidateRange(3, 25)]
    [int]$DependencyCalibrationIterations = 5,

    [string]$DataRoot = 'C:\ProgramData\ZBookPerf',

    [switch]$NoTrace,
    [switch]$Diagnostic,
    [switch]$LabTier2Confirmed,
    [switch]$SelfManagedEnrollmentConfirmed,
    [switch]$NoReboot,
    [string]$EnrollmentStatePath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:BootstrapVersion = '2026.08.02.1'
$script:RawRoot = 'https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main'

function Resolve-UxRomComponent {
    param(
        [Parameter(Mandatory=$true)][string]$RelativePath,
        [Parameter(Mandatory=$true)][string]$CacheName
    )
    $basePath = if ([string]::IsNullOrWhiteSpace([string]$PSScriptRoot)) {
        (Get-Location).Path
    } else {
        $PSScriptRoot
    }
    $local = Join-Path $basePath $RelativePath
    if (Test-Path -LiteralPath $local) { return $local }

    $cacheRoot = Join-Path $DataRoot 'runtime'
    if (-not (Test-Path -LiteralPath $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null }
    $cache = Join-Path $cacheRoot $CacheName
    $uri = "$script:RawRoot/$($RelativePath.Replace('\','/'))"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $cache
    } catch {
        if (-not (Test-Path -LiteralPath $cache)) { throw }
        Write-Warning "Using cached UX-ROM component because refresh failed: $cache"
    }
    return $cache
}

function Invoke-EnrollmentMaintenance {
    param([ValidateSet('Start','Check','Rollback')][string]$Mode)
    $helper = Resolve-UxRomComponent -RelativePath 'controller\maintenance\UxRomEnrollmentCleanup.ps1' -CacheName 'UxRomEnrollmentCleanup.ps1'
    $arguments = @{
        Action = $Mode
        Root = $DataRoot
        SelfManagedConfirmed = [bool]$SelfManagedEnrollmentConfirmed
        LabTier2Confirmed = [bool]$LabTier2Confirmed
        NoReboot = [bool]$NoReboot
    }
    if ($EnrollmentStatePath) { $arguments.StatePath = $EnrollmentStatePath }
    & $helper @arguments -WhatIf:$WhatIfPreference -Confirm:$false
}

if ($EnrollmentCleanup) { $Action = 'EnrollmentCleanup' }

if ($Action -eq 'EnrollmentCleanup') {
    Invoke-EnrollmentMaintenance -Mode Start
    return
}
if ($Action -eq 'EnrollmentCleanupCheck') {
    Invoke-EnrollmentMaintenance -Mode Check
    return
}
if ($Action -eq 'EnrollmentCleanupRollback') {
    if (-not $EnrollmentStatePath) { throw '-EnrollmentStatePath is required for EnrollmentCleanupRollback.' }
    Invoke-EnrollmentMaintenance -Mode Rollback
    return
}

$core = Resolve-UxRomComponent -RelativePath 'controller\core\ZBookPerf.Core.ps1' -CacheName 'ZBookPerf.Core.ps1'
$forward = @{}
foreach ($key in $PSBoundParameters.Keys) {
    if ($key -notin @('EnrollmentCleanup','SelfManagedEnrollmentConfirmed','NoReboot','EnrollmentStatePath')) {
        $forward[$key] = $PSBoundParameters[$key]
    }
}

if ($MyInvocation.InvocationName -eq '.') {
    . $core @forward
} else {
    & $core @forward
}

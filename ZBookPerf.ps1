#requires -Version 5.1

<#
.SYNOPSIS
    Lacksan UX-ROM performance controller and self-managed enrollment maintenance entrypoint.

.DESCRIPTION
    Preserves the UX-ROM ASCII console and twelve-layer performance interface while
    adding EXP-137 as an integrated maintenance choice. Interactive launches render
    an animated bootstrap, component-fetch indicator, ASCII splash, layer-indexing
    sequence, command-surface transition, native PowerShell runtime progress, and
    the machine Physical Validation / Stable Promotion surface. Redirected and
    automation launches remain fast and deterministic.
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

$script:BootstrapVersion = '2026.08.02.5'
$script:RawRoot = 'https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main'

function Test-UxRomAnimationEnabled {
    if ($Host.Name -ne 'ConsoleHost') { return $false }
    try {
        if ([Console]::IsOutputRedirected) { return $false }
    } catch {
        return $false
    }
    return $true
}

function Write-UxRomAnimatedStage {
    param(
        [Parameter(Mandatory=$true)][string]$Label,
        [ValidateRange(2, 60)][int]$Frames = 10,
        [ValidateRange(10, 250)][int]$DelayMilliseconds = 35,
        [ValidateRange(10, 40)][int]$Width = 22
    )

    if (-not (Test-UxRomAnimationEnabled)) {
        Write-Host "$Label..." -ForegroundColor DarkGray
        return
    }

    $spinner = @('|','/','-','\')
    for ($frame = 0; $frame -lt $Frames; $frame++) {
        $filled = [Math]::Max(1, [Math]::Min($Width, [int][Math]::Ceiling((($frame + 1) / [double]$Frames) * $Width)))
        $bar = ('#' * $filled) + ('.' * ($Width - $filled))
        $line = '  {0} {1,-30} [{2}]' -f $spinner[$frame % $spinner.Count], $Label.ToUpperInvariant(), $bar
        Write-Host ("`r{0,-78}" -f $line) -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Milliseconds $DelayMilliseconds
    }
    $done = '  + {0,-30} [{1}]' -f $Label.ToUpperInvariant(), ('#' * $Width)
    Write-Host ("`r{0,-78}" -f $done) -ForegroundColor Green
}

function Invoke-UxRomAnimatedDownload {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$OutFile,
        [Parameter(Mandatory=$true)][string]$Label
    )

    if (-not (Test-UxRomAnimationEnabled)) {
        Write-Host "$Label..." -ForegroundColor DarkGray
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $OutFile
        return
    }

    $temporary = "$OutFile.download"
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    $client = New-Object Net.WebClient
    $spinner = @('|','/','-','\')
    $width = 24
    $tick = 0
    try {
        $task = $client.DownloadFileTaskAsync([Uri]$Uri, $temporary)
        while (-not $task.IsCompleted) {
            $track = New-Object char[] $width
            for ($i = 0; $i -lt $width; $i++) { $track[$i] = '.' }
            $track[$tick % $width] = '>'
            $sizeKb = 0
            if (Test-Path -LiteralPath $temporary) {
                $sizeKb = [Math]::Round((Get-Item -LiteralPath $temporary).Length / 1KB, 1)
            }
            $line = '  {0} {1,-24} [{2}] {3,7} KB' -f $spinner[$tick % $spinner.Count], $Label.ToUpperInvariant(), (-join $track), $sizeKb
            Write-Host ("`r{0,-90}" -f $line) -NoNewline -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 70
            $tick++
        }
        $task.GetAwaiter().GetResult()
        Move-Item -LiteralPath $temporary -Destination $OutFile -Force
        $finalKb = [Math]::Round((Get-Item -LiteralPath $OutFile).Length / 1KB, 1)
        $done = '  + {0,-24} [{1}] {2,7} KB' -f $Label.ToUpperInvariant(), ('#' * $width), $finalKb
        Write-Host ("`r{0,-90}" -f $done) -ForegroundColor Green
    } catch {
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        throw
    } finally {
        $client.Dispose()
    }
}

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
        Invoke-UxRomAnimatedDownload -Uri $uri -OutFile $cache -Label "Fetching $CacheName"
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

if (Test-UxRomAnimationEnabled) {
    Write-Host ''
    Write-Host 'LACKSAN UX-ROM BOOTSTRAP' -ForegroundColor Red
    Write-UxRomAnimatedStage -Label 'Initializing session' -Frames 7 -DelayMilliseconds 28
}

$core = Resolve-UxRomComponent -RelativePath 'controller\core\ZBookPerf.Core.ps1' -CacheName 'ZBookPerf.Core.ps1'
Write-UxRomAnimatedStage -Label 'Verifying controller' -Frames 7 -DelayMilliseconds 28

$forward = @{}
foreach ($key in $PSBoundParameters.Keys) {
    if ($key -notin @('EnrollmentCleanup','SelfManagedEnrollmentConfirmed','NoReboot','EnrollmentStatePath')) {
        $forward[$key] = $PSBoundParameters[$key]
    }
}

# Dot-source the existing controller so its full feature set remains available.
. $core @forward

# Runtime progress is a presentation-only overlay. It uses native Write-Progress and
# preserves the controller's evidence, measurement, and rollback behavior.
$workProgress = Resolve-UxRomComponent -RelativePath 'controller\ui\UxRomWorkProgress.ps1' -CacheName 'UxRomWorkProgress.ps1'
. $workProgress

# Direct layer selection must always run an integrated assessment even when the older
# EXP-047 candidate array is empty.
$layerIntegration = Resolve-UxRomComponent -RelativePath 'controller\ui\UxRomLayerIntegration.ps1' -CacheName 'UxRomLayerIntegration.ps1'
. $layerIntegration

# Human-approved release lane. The component discovers validation-ready providers from
# main and records physical results locally before any machine-specific Stable claim.
$stableValidation = Resolve-UxRomComponent -RelativePath 'controller\release\UxRomStableValidation.ps1' -CacheName 'UxRomStableValidation.ps1'
. $stableValidation

Write-UxRomAnimatedStage -Label 'Mounting performance core' -Frames 8 -DelayMilliseconds 28

# Interactive splash override. Automation and redirected launches use the original,
# immediate core splash so tests and scripted callers stay deterministic.
function Show-UxRomSplash {
    if ($script:SplashShown) { return }
    $script:SplashShown = $true
    Write-Host ''

    if (-not (Test-UxRomAnimationEnabled)) {
        Show-UxRomHeader
        Write-Host 'Loading the twelve performance layers...' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    $logoLines = @(
        '   _        _    ____ _  __ ____    _    _   _',
        '  | |      / \  / ___| |/ // ___|  / \  | \ | |',
        "  | |     / _ \| |   | ' / \___ \ / _ \ |  \| |",
        '  | |___ / ___ \ |___| . \  ___) / ___ \| |\  |',
        '  |_____/_/   \_\____|_|\_\|____/_/   \_\_| \_|'
    )
    foreach ($line in $logoLines) {
        Write-Host $line -ForegroundColor Gray
        Start-Sleep -Milliseconds 32
    }

    for ($pulse = 0; $pulse -lt 4; $pulse++) {
        $tone = if (($pulse % 2) -eq 0) { 'Red' } else { 'DarkRed' }
        Write-Host ("`r{0,-70}" -f '                    U X - R O M') -NoNewline -ForegroundColor $tone
        Start-Sleep -Milliseconds 85
    }
    Write-Host ("`r{0,-70}" -f '                    U X - R O M') -ForegroundColor Red
    Write-Host 'Windows performance-layer controller  ' -ForegroundColor DarkGray -NoNewline
    Write-Host $script:ProductVersion -ForegroundColor Red

    $layers = @(Get-PerformanceLayerCatalog)
    $width = 28
    for ($index = 0; $index -lt $layers.Count; $index++) {
        $complete = $index + 1
        $filled = [Math]::Max(1, [int][Math]::Ceiling(($complete / [double]$layers.Count) * $width))
        $bar = ('#' * $filled) + ('.' * ($width - $filled))
        $label = 'INDEXING LAYER {0:00}/{1:00}  {2,-24} [{3}]' -f $complete, $layers.Count, ([string]$layers[$index].name), $bar
        Write-Host ("`r{0,-105}" -f $label) -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 42
    }
    Write-Host ("`r{0,-105}" -f ('PERFORMANCE MAP ONLINE'.PadRight(44) + '[' + ('#' * $width) + ']')) -ForegroundColor Green
    Write-UxRomAnimatedStage -Label 'Rendering command surface' -Frames 9 -DelayMilliseconds 30
    Write-Host ''
}

# EXP-137 and the machine Stable-validation lane are integrated into the same product UI.
function Show-ZBookPerfMenu {
    do {
        Write-Host ''
        Write-Host 'D. Full system diagnostics - one read-only pass across every integrated check' -ForegroundColor White
        Write-Host ''
        foreach ($layer in Get-PerformanceLayerCatalog) {
            Write-Host ("{0,2}. {1}" -f $layer.number, $layer.name) -ForegroundColor White
            Write-Host ("    {0}" -f $layer.description) -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host 'A. Apply all eligible tweaks - one measured, reversible synergy batch' -ForegroundColor Yellow
        Write-Host 'V. Physical Validation / Stable Promotion - run merged providers on this machine' -ForegroundColor Green
        Write-Host 'E. Self-managed enrollment cleanup - capture, clean, reboot, verify, resume EXP-071' -ForegroundColor Yellow
        Write-Host 'K. Keep the measured layer change and continue'
        Write-Host 'R. Revert the active layer change or latest synergy batch'
        Write-Host 'S. Show workflow, build, WPR, and support status'
        Write-Host 'M. Maintenance and direct measurement tools'
        Write-Host 'Q. Quit'
        $choice = Read-Host 'Choose diagnostics, a layer, or an action'
        if ($choice -in @('v','V')) {
            Show-UxRomStableValidationMenu -Root $DataRoot
            continue
        }
        if ($choice -in @('e','E')) {
            Write-Host ''
            Write-Host 'EXP-137 self-managed enrollment cleanup' -ForegroundColor Cyan
            Invoke-EnrollmentMaintenance -Mode Start
            continue
        }
        return $choice
    } while ($true)
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-ZBookPerfMain
}

#requires -Version 5.1

<#
.SYNOPSIS
    Lacksan UX-ROM performance-layer controller for supported Windows systems.

.DESCRIPTION
    EXP-047 records Windows performance evidence and applies supported,
    reversible experiments through a twelve-layer workflow. Machine-wide
    candidates require an administrator console and explicit confirmation that
    the computer is a recoverable Tier 2 lab system. The optional synergy batch
    contains only supported, non-reboot experiments and preserves one journal
    entry per change plus a batch rollback record.

    No argument opens the interactive console. Automation can use -Action or
    the equivalent action switches.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Menu', 'FullDiagnostics', 'ApplyAll', 'LayerWorkflow', 'LayerMap', 'Analyze', 'Watch', 'ThermalProfile', 'HardwareProfile', 'FirmwareProfile', 'DriverProfile', 'KernelProfile', 'ShellProfile', 'WorkloadProfile', 'DependencyProfile', 'Enhance', 'Remeasure', 'Revert', 'Status')]
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
    [switch]$ShellProfile,
    [switch]$WorkloadProfile,
    [switch]$DependencyProfile,
    [switch]$Enhance,
    [switch]$Remeasure,
    [switch]$Revert,

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
    [switch]$LabTier2Confirmed
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ExperimentId = 'EXP-047'
$script:SchemaVersion = 1
$script:ProductName = 'Lacksan UX-ROM'
$script:ProductVersion = '2026.07.31.3'
$script:LayerWorkflowSchemaVersion = 1
$script:SplashShown = $false
$script:LoadedFrom = if ([string]::IsNullOrWhiteSpace([string]$PSCommandPath)) {
    'in-memory content'
} else {
    $PSCommandPath
}
$script:HighPerformanceScheme = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:ProcessorSubgroup = '54533251-82be-4824-96c1-47b60b740d00'
$script:PowerSettings = [ordered]@{
    PROCTHROTTLEMIN = '893dee8e-2bef-41e0-89c6-b55d0929964c'
    PROCTHROTTLEMAX = 'bc5038f7-23e0-4960-96da-33abaf5935ec'
    PERFBOOSTMODE    = 'be337238-0d82-4146-a960-4f3749d470c7'
    CPMINCORES       = '0cc5b647-c1df-4637-891a-dec35c318583'
}
$script:PowerTargets = [ordered]@{
    PROCTHROTTLEMIN = 100
    PROCTHROTTLEMAX = 100
    PERFBOOSTMODE    = 2
    CPMINCORES       = 100
}
$script:MmcssPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$script:FastStartupPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$script:MachineCandidates = @('PowerAc', 'MmcssResponsiveness', 'NtfsLastAccess', 'FastStartupDiagnostic')

function New-HorizontalBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$Value,
        [double]$Maximum = 100,
        [ValidateRange(1, 80)]
        [int]$Width = 24,
        [string]$FilledCharacter = '#',
        [string]$EmptyCharacter = '-'
    )

    if ($Maximum -le 0) { $Maximum = 1 }
    $bounded = [Math]::Max(0, [Math]::Min($Value, $Maximum))
    $filled = [int][Math]::Round(($bounded / $Maximum) * $Width, 0, [MidpointRounding]::AwayFromZero)
    return (($FilledCharacter * $filled) + ($EmptyCharacter * ($Width - $filled)))
}

function ConvertTo-Sparkline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [double[]]$Values
    )

    if (-not $Values -or $Values.Count -eq 0) { return '' }
    $characters = @(0x2581, 0x2582, 0x2583, 0x2584, 0x2585, 0x2586, 0x2587, 0x2588)
    $minimum = ($Values | Measure-Object -Minimum).Minimum
    $maximum = ($Values | Measure-Object -Maximum).Maximum
    if ($maximum -eq $minimum) {
        return -join ($Values | ForEach-Object { [char]$characters[3] })
    }

    return -join ($Values | ForEach-Object {
        $index = [int][Math]::Round((($_ - $minimum) / ($maximum - $minimum)) * ($characters.Count - 1))
        [char]$characters[[Math]::Max(0, [Math]::Min($index, $characters.Count - 1))]
    })
}

function ConvertTo-ChangeLogJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    return ($InputObject | ConvertTo-Json -Depth 20)
}

function ConvertFrom-ChangeLogJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Json
    )

    if ([string]::IsNullOrWhiteSpace($Json)) {
        throw 'The change-log JSON is empty.'
    }
    return ($Json | ConvertFrom-Json)
}

function Get-Median {
    [CmdletBinding()]
    param([double[]]$Values)

    $items = @($Values | Where-Object { $null -ne $_ } | Sort-Object)
    if ($items.Count -eq 0) { return 0.0 }
    $middle = [int][Math]::Floor($items.Count / 2)
    if (($items.Count % 2) -eq 1) { return [double]$items[$middle] }
    return ([double]$items[$middle - 1] + [double]$items[$middle]) / 2
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-DataDirectories {
    param([string]$Root)

    foreach ($path in @($Root, (Join-Path $Root 'traces'), (Join-Path $Root 'measurements'))) {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Write-StructuredEvent {
    param(
        [string]$Root,
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level,
        [string]$Event,
        [hashtable]$Data = @{}
    )

    Ensure-DataDirectories -Root $Root
    $record = [ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        level = $Level
        event = $Event
        data = $Data
    }
    Add-Content -LiteralPath (Join-Path $Root 'events.jsonl') -Value ($record | ConvertTo-Json -Compress -Depth 12) -Encoding UTF8
}

function Invoke-NativeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$AllowFailure
    )

    # Windows PowerShell 5.1 wraps text written to a native process's stderr
    # stream in NativeCommandError records. The script-wide Stop preference
    # must not turn that text into a terminating PowerShell error before the
    # native exit code can be inspected.
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $outputText = @($output | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord] -and $_.Exception) {
            $_.Exception.Message
        } else {
            [string]$_
        }
    })
    $result = [pscustomobject]@{
        FilePath = $FilePath
        Arguments = $Arguments
        ExitCode = $exitCode
        Output = ($outputText -join [Environment]::NewLine)
    }
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "$FilePath exited with code $exitCode. $($result.Output)"
    }
    return $result
}

function Get-RegistryValueState {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $state = [ordered]@{ Path = $Path; Name = $Name; Exists = $false; Kind = $null; Value = $null }
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]$state }
    try {
        $key = Get-Item -LiteralPath $Path
        $state.Kind = $key.GetValueKind($Name).ToString()
        $state.Value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $state.Exists = $true
    } catch [System.ArgumentException] {
        $state.Exists = $false
    }
    return [pscustomobject]$state
}

function Set-RegistryValueFromState {
    param([Parameter(Mandatory = $true)][object]$State)

    if ($State.Exists) {
        if (-not (Test-Path -LiteralPath $State.Path)) {
            New-Item -Path $State.Path -Force | Out-Null
        }
        New-ItemProperty -LiteralPath $State.Path -Name $State.Name -Value $State.Value -PropertyType $State.Kind -Force | Out-Null
    } elseif (Test-Path -LiteralPath $State.Path) {
        Remove-ItemProperty -LiteralPath $State.Path -Name $State.Name -ErrorAction SilentlyContinue
    }
}

function Test-RegistryValueMatchesState {
    param([Parameter(Mandatory = $true)][object]$Expected)

    $current = Get-RegistryValueState -Path $Expected.Path -Name $Expected.Name
    if ([bool]$current.Exists -ne [bool]$Expected.Exists) { return $false }
    if (-not $current.Exists) { return $true }
    return ($current.Kind -eq $Expected.Kind -and [string]$current.Value -eq [string]$Expected.Value)
}

function Get-ChangeLog {
    param([string]$Root)

    $path = Join-Path $Root 'changes.json'
    if (-not (Test-Path -LiteralPath $path)) {
        return [pscustomobject][ordered]@{
            schemaVersion = $script:SchemaVersion
            experimentId = $script:ExperimentId
            computerName = $env:COMPUTERNAME
            entries = @()
        }
    }
    $log = ConvertFrom-ChangeLogJson -Json (Get-Content -LiteralPath $path -Raw)
    if ([int]$log.schemaVersion -ne $script:SchemaVersion) {
        throw "Unsupported changes.json schema version: $($log.schemaVersion)"
    }
    return $log
}

function Save-ChangeLog {
    param([string]$Root, [object]$Log)

    Ensure-DataDirectories -Root $Root
    $path = Join-Path $Root 'changes.json'
    $temporary = "$path.tmp"
    ConvertTo-ChangeLogJson -InputObject $Log | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $path -Force
}

function Get-WindowsEnvironment {
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $edgeVersion = $null
    foreach ($edgePath in @(
        "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )) {
        if ($edgePath -and (Test-Path -LiteralPath $edgePath)) {
            $edgeVersion = (Get-Item -LiteralPath $edgePath).VersionInfo.ProductVersion
            break
        }
    }

    $activeScheme = Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/getactivescheme') -AllowFailure
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1
    $thermal = @()
    try {
        $thermal = @(Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop | ForEach-Object {
            [Math]::Round(($_.CurrentTemperature / 10) - 273.15, 1)
        })
    } catch {
        $thermal = @()
    }

    $drivers = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceClass -in @('DISPLAY', 'NET', 'SCSIADAPTER', 'HDC') } |
        Select-Object DeviceClass, DeviceName, DriverProviderName, DriverVersion, DriverDate)

    return [pscustomobject][ordered]@{
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        windows = [ordered]@{
            caption = $operatingSystem.Caption
            version = $operatingSystem.Version
            build = $operatingSystem.BuildNumber
        }
        computer = [ordered]@{
            manufacturer = $computer.Manufacturer
            model = $computer.Model
            totalPhysicalMemoryBytes = [uint64]$computer.TotalPhysicalMemory
        }
        bios = [ordered]@{
            version = @($bios.SMBIOSBIOSVersion) -join '; '
            releaseDate = $bios.ReleaseDate
        }
        processor = [ordered]@{
            name = $processor.Name
            cores = $processor.NumberOfCores
            logicalProcessors = $processor.NumberOfLogicalProcessors
            maxClockMHz = $processor.MaxClockSpeed
            currentClockMHz = $processor.CurrentClockSpeed
        }
        edgeVersion = $edgeVersion
        power = [ordered]@{
            activeScheme = $activeScheme.Output.Trim()
            batteryStatus = if ($battery) { $battery.BatteryStatus } else { $null }
            estimatedChargeRemaining = if ($battery) { $battery.EstimatedChargeRemaining } else { $null }
            systemPowerStatus = Get-SystemPowerStatusState
        }
        thermalZoneCelsius = $thermal
        physicalDisks = if (Get-Command 'Get-PhysicalDisk' -ErrorAction SilentlyContinue) {
            @(Get-PhysicalDisk -ErrorAction SilentlyContinue | Select-Object FriendlyName, MediaType, BusType, HealthStatus, OperationalStatus)
        } else { @() }
        networkAdapters = if (Get-Command 'Get-NetAdapter' -ErrorAction SilentlyContinue) {
            @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, LinkSpeed, DriverInformation)
        } else { @() }
        relevantDrivers = $drivers
    }
}

function Get-PerformanceSample {
    $timestamp = [DateTime]::UtcNow.ToString('o')
    $cpuTotal = 0.0
    $perCore = @()
    $dpc = 0.0
    $interrupt = 0.0
    $diskQueue = 0.0
    $diskSeconds = 0.0
    $memoryCommitted = 0.0
    $memoryAvailableMb = 0.0
    $counterSource = 'Get-Counter'

    $counterPaths = @(
        '\Processor Information(*)\% Processor Utility',
        '\Processor Information(_Total)\% DPC Time',
        '\Processor Information(_Total)\% Interrupt Time',
        '\PhysicalDisk(_Total)\Current Disk Queue Length',
        '\PhysicalDisk(_Total)\Avg. Disk sec/Transfer',
        '\Memory\% Committed Bytes In Use',
        '\Memory\Available MBytes'
    )

    try {
        $samples = (Get-Counter -Counter $counterPaths -MaxSamples 1 -ErrorAction Stop).CounterSamples
        foreach ($sample in $samples) {
            $path = $sample.Path.ToLowerInvariant()
            if ($path -like '*processor information(_total)*% processor utility') {
                $cpuTotal = [double]$sample.CookedValue
            } elseif ($path -like '*processor information(_total)*% dpc time') {
                $dpc = [double]$sample.CookedValue
            } elseif ($path -like '*processor information(_total)*% interrupt time') {
                $interrupt = [double]$sample.CookedValue
            } elseif ($path -like '*processor information(*% processor utility') {
                $perCore += [pscustomobject]@{ Instance = $sample.InstanceName; Value = [Math]::Round([double]$sample.CookedValue, 2) }
            } elseif ($path -like '*physicaldisk(_total)*current disk queue length') {
                $diskQueue = [double]$sample.CookedValue
            } elseif ($path -like '*physicaldisk(_total)*avg. disk sec/transfer') {
                $diskSeconds = [double]$sample.CookedValue
            } elseif ($path -like '*memory*% committed bytes in use') {
                $memoryCommitted = [double]$sample.CookedValue
            } elseif ($path -like '*memory*available mbytes') {
                $memoryAvailableMb = [double]$sample.CookedValue
            }
        }
    } catch {
        $counterSource = 'CIM fallback'
        $processor = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor |
            Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
        $memory = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory
        $disk = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk |
            Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
        $cpuTotal = [double]$processor.PercentProcessorTime
        $dpc = [double]$processor.PercentDPCTime
        $interrupt = [double]$processor.PercentInterruptTime
        $diskQueue = [double]$disk.CurrentDiskQueueLength
        $diskSeconds = [double]$disk.AvgDisksecPerTransfer
        $memoryAvailableMb = [double]$memory.AvailableMBytes
        if ([double]$memory.CommitLimit -gt 0) {
            $memoryCommitted = ([double]$memory.CommittedBytes / [double]$memory.CommitLimit) * 100
        }
    }

    $processes = @(Get-CimInstance -ClassName Win32_PerfFormattedData_PerfProc_Process -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @('_Total', 'Idle') } |
        Select-Object Name, IDProcess, PercentProcessorTime, IODataBytesPersec, WorkingSetPrivate)

    $temperatures = @()
    try {
        $temperatures = @(Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
            ForEach-Object { [Math]::Round(($_.CurrentTemperature / 10) - 273.15, 1) })
    } catch {
        $temperatures = @()
    }

    return [pscustomobject][ordered]@{
        timestampUtc = $timestamp
        source = $counterSource
        cpuUtilityPercent = [Math]::Round($cpuTotal, 2)
        perCore = $perCore
        dpcPercent = [Math]::Round($dpc, 3)
        interruptPercent = [Math]::Round($interrupt, 3)
        diskQueueLength = [Math]::Round($diskQueue, 3)
        diskLatencyMs = [Math]::Round($diskSeconds * 1000, 3)
        memoryCommittedPercent = [Math]::Round($memoryCommitted, 2)
        memoryAvailableMb = [Math]::Round($memoryAvailableMb, 0)
        thermalZoneCelsius = $temperatures
        processes = $processes
    }
}

function Get-MeasurementSummary {
    param([object[]]$Samples, [object]$Environment)

    $cpu = @($Samples | ForEach-Object { [double]$_.cpuUtilityPercent })
    $dpc = @($Samples | ForEach-Object { [double]$_.dpcPercent })
    $interrupt = @($Samples | ForEach-Object { [double]$_.interruptPercent })
    $diskQueue = @($Samples | ForEach-Object { [double]$_.diskQueueLength })
    $diskLatency = @($Samples | ForEach-Object { [double]$_.diskLatencyMs })
    $memory = @($Samples | ForEach-Object { [double]$_.memoryCommittedPercent })
    $temperatures = @($Samples | ForEach-Object { @($_.thermalZoneCelsius) } | Where-Object { $null -ne $_ })

    $processRows = @($Samples | ForEach-Object { @($_.processes) })
    $topCpu = @($processRows | Group-Object Name | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            MedianCpu = [Math]::Round((Get-Median -Values @($_.Group | ForEach-Object { [double]$_.PercentProcessorTime })), 2)
        }
    } | Sort-Object MedianCpu -Descending | Select-Object -First $Top)
    $topIo = @($processRows | Group-Object Name | ForEach-Object {
        [pscustomobject]@{
            Name = $_.Name
            MedianIoBytesPerSec = [Math]::Round((Get-Median -Values @($_.Group | ForEach-Object { [double]$_.IODataBytesPersec })), 0)
        }
    } | Sort-Object MedianIoBytesPerSec -Descending | Select-Object -First $Top)

    $metrics = [ordered]@{
        cpuMedianPercent = [Math]::Round((Get-Median $cpu), 2)
        cpuMaximumPercent = if ($cpu.Count) { [Math]::Round(($cpu | Measure-Object -Maximum).Maximum, 2) } else { 0 }
        dpcMedianPercent = [Math]::Round((Get-Median $dpc), 3)
        interruptMedianPercent = [Math]::Round((Get-Median $interrupt), 3)
        diskQueueMedian = [Math]::Round((Get-Median $diskQueue), 3)
        diskLatencyMedianMs = [Math]::Round((Get-Median $diskLatency), 3)
        memoryCommittedMedianPercent = [Math]::Round((Get-Median $memory), 2)
        maximumThermalZoneCelsius = if ($temperatures.Count) { [Math]::Round(($temperatures | Measure-Object -Maximum).Maximum, 1) } else { $null }
    }

    $findings = New-PerformanceFindings -Metrics $metrics -TopCpu $topCpu -Environment $Environment
    return [pscustomobject][ordered]@{
        metrics = [pscustomobject]$metrics
        topCpu = $topCpu
        topIo = $topIo
        findings = $findings
        cpuSparkline = ConvertTo-Sparkline -Values $cpu
    }
}

function New-PerformanceFindings {
    param([object]$Metrics, [object[]]$TopCpu, [object]$Environment)

    $findings = New-Object System.Collections.ArrayList
    if ($Metrics.cpuMedianPercent -ge 80) {
        [void]$findings.Add([pscustomobject]@{
            classification = 'CPU-bound'
            evidence = "Median CPU utility was $($Metrics.cpuMedianPercent)%."
            nextCandidate = 'PowerAc'
        })
    }
    if ($Metrics.diskLatencyMedianMs -ge 20 -or $Metrics.diskQueueMedian -ge 2) {
        [void]$findings.Add([pscustomobject]@{
            classification = 'I/O-bound'
            evidence = "Median disk latency was $($Metrics.diskLatencyMedianMs) ms and queue length was $($Metrics.diskQueueMedian)."
            nextCandidate = 'Observation only: inspect the ETL and minifilter stack.'
        })
    }
    if ($Metrics.maximumThermalZoneCelsius -ne $null -and $Metrics.maximumThermalZoneCelsius -ge 90) {
        $current = [double]$Environment.processor.currentClockMHz
        $maximum = [double]$Environment.processor.maxClockMHz
        $classification = if ($maximum -gt 0 -and $current -lt ($maximum * 0.8)) { 'Thermal-throttling risk' } else { 'High thermal reading' }
        [void]$findings.Add([pscustomobject]@{
            classification = $classification
            evidence = "Maximum reported ACPI thermal-zone temperature was $($Metrics.maximumThermalZoneCelsius) C. ACPI zone readings may not be the CPU package temperature."
            nextCandidate = 'Physical and thermal inspection before any power change.'
        })
    }
    if ($TopCpu.Count -gt 0 -and $Metrics.cpuMedianPercent -ge 25) {
        [void]$findings.Add([pscustomobject]@{
            classification = 'Possible background interference'
            evidence = "The highest sampled process group was $($TopCpu[0].Name) with median counter value $($TopCpu[0].MedianCpu)."
            nextCandidate = 'Inspect the process and its documented role; do not disable it from this finding alone.'
        })
    }
    if ($findings.Count -eq 0) {
        [void]$findings.Add([pscustomobject]@{
            classification = 'No dominant sampled bottleneck'
            evidence = 'The short counter window did not cross the conservative CPU, disk, or thermal screening thresholds.'
            nextCandidate = 'Use a WPR trace around the exact slow interaction.'
        })
    }
    return @($findings)
}

function Show-MeasurementSummary {
    param([object]$Measurement)

    $m = $Measurement.summary.metrics
    Write-Host ''
    Write-Host "ZBookPerf $($Measurement.kind) measurement" -ForegroundColor Cyan
    Write-Host ("CPU     [{0}] {1,6:N1}%  {2}" -f (New-HorizontalBar -Value $m.cpuMedianPercent), $m.cpuMedianPercent, $Measurement.summary.cpuSparkline)
    Write-Host ("Memory  [{0}] {1,6:N1}%" -f (New-HorizontalBar -Value $m.memoryCommittedMedianPercent), $m.memoryCommittedMedianPercent)
    Write-Host ("DPC/ISR median: {0:N3}% / {1:N3}%" -f $m.dpcMedianPercent, $m.interruptMedianPercent)
    Write-Host ("Disk latency/queue median: {0:N3} ms / {1:N3}" -f $m.diskLatencyMedianMs, $m.diskQueueMedian)
    if ($null -ne $m.maximumThermalZoneCelsius) {
        Write-Host ("Maximum ACPI thermal-zone reading: {0:N1} C" -f $m.maximumThermalZoneCelsius)
    } else {
        Write-Host 'Maximum ACPI thermal-zone reading: unavailable'
    }
    Write-Host ''
    Write-Host 'Top sampled CPU process groups' -ForegroundColor Yellow
    $Measurement.summary.topCpu | Format-Table Name, MedianCpu -AutoSize | Out-Host
    Write-Host 'Top sampled I/O process groups' -ForegroundColor Yellow
    $Measurement.summary.topIo | Format-Table Name, MedianIoBytesPerSec -AutoSize | Out-Host
    Write-Host 'Screening findings' -ForegroundColor Yellow
    $Measurement.summary.findings | Format-Table classification, evidence, nextCandidate -Wrap -AutoSize | Out-Host
    Write-Host "Evidence: $($Measurement.evidencePath)" -ForegroundColor DarkGray
    if ($Measurement.trace.status -ne 'captured') {
        Write-Host "ETW trace: $($Measurement.trace.status) - $($Measurement.trace.reason)" -ForegroundColor DarkYellow
    } else {
        Write-Host "ETW trace: $($Measurement.trace.etlPath)" -ForegroundColor DarkGray
    }
}

function Get-ThermalProfileSupport {
    $className = 'Win32_PerfFormattedData_Counters_ProcessorInformation'
    $requiredProperties = @(
        'Name',
        'PercentProcessorTime',
        'PercentProcessorUtility',
        'PercentProcessorPerformance',
        'ProcessorFrequency',
        'PercentofMaximumFrequency',
        'PercentPerformanceLimit',
        'PerformanceLimitFlags'
    )
    try {
        $counterClass = Get-CimClass -Namespace 'root/cimv2' -ClassName $className -ErrorAction Stop
        $availableProperties = @($counterClass.CimClassProperties | ForEach-Object { $_.Name })
        $missingProperties = @($requiredProperties | Where-Object { $_ -notin $availableProperties })
        if ($missingProperties.Count -gt 0) {
            return [pscustomobject][ordered]@{
                supported = $false
                provider = $className
                reason = "The Processor Information provider is missing: $($missingProperties -join ', ')."
                missingProperties = $missingProperties
                thermalZoneSupported = $false
                thermalZoneStatus = 'NotProbed'
                thermalZoneErrorType = $null
            }
        }

        $probe = Get-CimInstance `
            -Namespace 'root/cimv2' `
            -ClassName $className `
            -Filter "Name='_Total'" `
            -OperationTimeoutSec 5 `
            -ErrorAction Stop |
            Select-Object -First 1
        if (-not $probe) {
            return [pscustomobject][ordered]@{
                supported = $false
                provider = $className
                reason = 'The Processor Information provider did not return its _Total instance.'
                missingProperties = @()
                thermalZoneSupported = $false
                thermalZoneStatus = 'NotProbed'
                thermalZoneErrorType = $null
            }
        }
    } catch {
        return [pscustomobject][ordered]@{
            supported = $false
            provider = $className
            reason = "The Processor Information provider could not be queried ($($_.Exception.GetType().Name))."
            missingProperties = @()
            thermalZoneSupported = $false
            thermalZoneStatus = 'NotProbed'
            thermalZoneErrorType = $null
        }
    }

    $thermalZoneSupported = $false
    $thermalZoneStatus = 'Unavailable'
    $thermalZoneErrorType = $null
    try {
        $thermalZoneProbe = @(Get-CimInstance `
            -Namespace 'root/wmi' `
            -ClassName 'MSAcpi_ThermalZoneTemperature' `
            -OperationTimeoutSec 5 `
            -ErrorAction Stop)
        $thermalZoneSupported = $thermalZoneProbe.Count -gt 0
        $thermalZoneStatus = if ($thermalZoneSupported) { 'Read' } else { 'NoInstances' }
    } catch {
        $thermalZoneErrorType = $_.Exception.GetType().Name
    }

    return [pscustomobject][ordered]@{
        supported = $true
        provider = $className
        reason = 'The inbox Processor Information counterset exposes the required performance-limit signals.'
        missingProperties = @()
        thermalZoneSupported = $thermalZoneSupported
        thermalZoneStatus = $thermalZoneStatus
        thermalZoneErrorType = $thermalZoneErrorType
    }
}

function Get-ThermalPerformanceSample {
    param(
        [double]$MonotonicOffsetMilliseconds = 0,
        [switch]$IncludeThermalZone
    )

    $queryTimer = [Diagnostics.Stopwatch]::StartNew()
    $processor = Get-CimInstance `
        -Namespace 'root/cimv2' `
        -ClassName 'Win32_PerfFormattedData_Counters_ProcessorInformation' `
        -Filter "Name='_Total'" `
        -OperationTimeoutSec 5 `
        -ErrorAction Stop |
        Select-Object -First 1
    if (-not $processor) {
        throw 'The Processor Information provider did not return its _Total instance.'
    }

    $thermalZones = @()
    $thermalZoneStatus = 'SkippedUnavailableAtPreflight'
    $thermalZoneError = $null
    if ($IncludeThermalZone) {
        try {
            $thermalZones = @(Get-CimInstance `
                -Namespace 'root/wmi' `
                -ClassName 'MSAcpi_ThermalZoneTemperature' `
                -OperationTimeoutSec 5 `
                -ErrorAction Stop |
                ForEach-Object {
                    [Math]::Round(([double]$_.CurrentTemperature / 10) - 273.15, 1)
                })
            $thermalZoneStatus = if ($thermalZones.Count -gt 0) { 'Read' } else { 'NoInstances' }
        } catch {
            $thermalZoneStatus = 'UnavailableDuringCollection'
            $thermalZoneError = $_.Exception.GetType().Name
        }
    }
    $queryTimer.Stop()

    return [pscustomobject][ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        monotonicOffsetMilliseconds = [Math]::Round($MonotonicOffsetMilliseconds, 3)
        processorTimePercent = [double]$processor.PercentProcessorTime
        processorUtilityPercent = [double]$processor.PercentProcessorUtility
        processorPerformancePercent = [double]$processor.PercentProcessorPerformance
        processorFrequencyMHz = [double]$processor.ProcessorFrequency
        percentOfMaximumFrequency = [double]$processor.PercentofMaximumFrequency
        performanceLimitPercent = [double]$processor.PercentPerformanceLimit
        performanceLimitFlags = [uint32]$processor.PerformanceLimitFlags
        acpiThermalZoneStatus = $thermalZoneStatus
        acpiThermalZoneCelsius = @($thermalZones)
        acpiThermalZoneErrorType = $thermalZoneError
        queryDurationMilliseconds = [Math]::Round($queryTimer.Elapsed.TotalMilliseconds, 3)
    }
}

function Measure-ThermalProfileObserver {
    param(
        [ValidateRange(3, 25)][int]$Iterations,
        [switch]$IncludeThermalZone
    )

    [void](Get-ThermalPerformanceSample -IncludeThermalZone:$IncludeThermalZone)
    $durations = @()
    for ($index = 0; $index -lt $Iterations; $index++) {
        $sample = Get-ThermalPerformanceSample -IncludeThermalZone:$IncludeThermalZone
        $durations += [double]$sample.queryDurationMilliseconds
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        durationMilliseconds = Get-WorkloadDistribution -Values $durations
        qualification = 'Times the complete local Processor Information query plus the bounded ACPI-zone query attempt after one warmup.'
    }
}

function Get-ThermalProfileSummary {
    param([Parameter(Mandatory = $true)][object[]]$Samples)

    if ($Samples.Count -eq 0) {
        throw 'The thermal-envelope profile requires at least one completed sample.'
    }
    $limited = @($Samples | Where-Object { [double]$_.performanceLimitPercent -lt 100 })
    $flagged = @($Samples | Where-Object { [uint32]$_.performanceLimitFlags -ne 0 })
    $temperatures = @($Samples | ForEach-Object {
        @($_.acpiThermalZoneCelsius) | ForEach-Object { [double]$_ }
    })
    $status = if ($limited.Count -gt 0 -or $flagged.Count -gt 0) {
        'ProcessorPerformanceLimitObserved'
    } else {
        'NoProcessorPerformanceLimitObserved'
    }

    return [pscustomobject][ordered]@{
        sampleCount = $Samples.Count
        status = $status
        processorTimePercent = Get-WorkloadDistribution -Values @($Samples | ForEach-Object { [double]$_.processorTimePercent })
        processorUtilityPercent = Get-WorkloadDistribution -Values @($Samples | ForEach-Object { [double]$_.processorUtilityPercent })
        processorPerformancePercent = Get-WorkloadDistribution -Values @($Samples | ForEach-Object { [double]$_.processorPerformancePercent })
        processorFrequencyMHz = Get-WorkloadDistribution -Values @($Samples | ForEach-Object { [double]$_.processorFrequencyMHz })
        performanceLimitPercent = Get-WorkloadDistribution -Values @($Samples | ForEach-Object { [double]$_.performanceLimitPercent })
        limitedSampleCount = $limited.Count
        nonzeroLimitFlagSampleCount = $flagged.Count
        observedLimitFlagValues = @($flagged | ForEach-Object { [uint32]$_.performanceLimitFlags } | Sort-Object -Unique)
        acpiThermalZoneReadSampleCount = @($Samples | Where-Object acpiThermalZoneStatus -eq 'Read').Count
        acpiThermalZoneCelsius = Get-WorkloadDistribution -Values $temperatures
        queryDurationMilliseconds = Get-WorkloadDistribution -Values @($Samples | ForEach-Object { [double]$_.queryDurationMilliseconds })
        interpretation = if ($status -eq 'ProcessorPerformanceLimitObserved') {
            'Windows reported a processor performance limit during this passive window. The counter alone does not prove that temperature caused the limit.'
        } else {
            'Windows reported no processor performance limit during this passive window. This does not prove that the cooling system is healthy under a different workload.'
        }
        decision = 'BaselineOnlyNoPerformanceClaim'
    }
}

function Invoke-ThermalProfile {
    param(
        [string]$Root,
        [ValidateRange(5, 3600)][int]$Seconds,
        [ValidateRange(1, 60)][int]$IntervalSeconds,
        [ValidateRange(3, 25)][int]$CalibrationIterations
    )

    $support = Get-ThermalProfileSupport
    if (-not $support.supported) {
        throw "Thermal-envelope profiling is unsupported: $($support.reason)"
    }
    if ($IntervalSeconds -gt $Seconds) {
        throw 'The thermal-envelope sample interval cannot exceed the requested duration.'
    }
    Ensure-DataDirectories -Root $Root
    $observer = Measure-ThermalProfileObserver `
        -Iterations $CalibrationIterations `
        -IncludeThermalZone:$support.thermalZoneSupported
    $environment = Get-WindowsEnvironment
    $profileStartUtc = [DateTime]::UtcNow.ToString('o')
    $runTimer = [Diagnostics.Stopwatch]::StartNew()
    $sampleCount = [Math]::Max(2, [int][Math]::Floor($Seconds / $IntervalSeconds) + 1)
    $samples = @()
    for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) {
        $samples += Get-ThermalPerformanceSample `
            -MonotonicOffsetMilliseconds $runTimer.Elapsed.TotalMilliseconds `
            -IncludeThermalZone:$support.thermalZoneSupported
        if ($sampleIndex -lt ($sampleCount - 1)) {
            $nextTargetMilliseconds = ($sampleIndex + 1) * $IntervalSeconds * 1000
            $remainingMilliseconds = $nextTargetMilliseconds - $runTimer.Elapsed.TotalMilliseconds
            if ($remainingMilliseconds -gt 0) {
                Start-Sleep -Milliseconds ([int][Math]::Ceiling($remainingMilliseconds))
            }
        }
    }
    $runTimer.Stop()

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    $runSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-$runSuffix-thermal-envelope-profile.json"
    $profile = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        layer = 1
        kind = 'thermal-envelope-profile'
        capturedUtc = $profileStartUtc
        completedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        support = $support
        environment = $environment
        requested = [pscustomobject][ordered]@{
            durationSeconds = $Seconds
            intervalSeconds = $IntervalSeconds
            sampleCount = $sampleCount
            calibrationIterations = $CalibrationIterations
            cimOperationTimeoutSeconds = 5
        }
        instrumentation = [pscustomobject][ordered]@{
            processorSource = 'Win32_PerfFormattedData_Counters_ProcessorInformation _Total'
            thermalZoneSource = 'MSAcpi_ThermalZoneTemperature only when the one-time preflight query succeeds; readings remain unidentified ACPI zones'
            timer = 'System.Diagnostics.Stopwatch'
            observerCalibration = $observer
            actualProfileDurationMilliseconds = [Math]::Round($runTimer.Elapsed.TotalMilliseconds, 3)
            qualification = 'Passive local counter reads only. No load is generated, no thermal limit reason is inferred, and inaccessible ACPI data is recorded by exception type only.'
        }
        collectionScope = 'Records aggregate CPU performance-limit, frequency, utility, and anonymous ACPI-zone values when available. It records no process list, sensor identity, file content, user content, credential, or network destination.'
        samples = @($samples)
        summary = Get-ThermalProfileSummary -Samples @($samples)
        evidencePath = $evidencePath
    }
    $profile | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    try {
        Write-StructuredEvent -Root $Root -Level Information -Event 'thermal-envelope-profile-complete' -Data @{
            evidencePath = $evidencePath
            status = $profile.summary.status
            sampleCount = $profile.summary.sampleCount
            limitedSampleCount = $profile.summary.limitedSampleCount
            observationOnly = $true
        }
    } catch {
        Write-Warning "The thermal-envelope profile was saved, but the optional event journal could not be updated ($($_.Exception.GetType().Name))."
    }

    Write-Host ''
    Write-Host 'Layer 1 thermal-envelope profile (observation only)' -ForegroundColor Cyan
    Write-Host "Processor-limit status: $($profile.summary.status)"
    Write-Host "Performance limit: minimum $($profile.summary.performanceLimitPercent.minimum)% across $($profile.summary.sampleCount) samples"
    Write-Host "Processor performance median: $($profile.summary.processorPerformancePercent.median)%"
    if ($profile.summary.acpiThermalZoneCelsius.count -gt 0) {
        Write-Host "Unidentified ACPI thermal-zone maximum: $($profile.summary.acpiThermalZoneCelsius.maximum) C"
    } else {
        Write-Host 'Unidentified ACPI thermal-zone readings: unavailable'
    }
    Write-Host $profile.summary.interpretation -ForegroundColor DarkYellow
    Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
    Write-Host 'No workload or Windows setting was changed and no performance-gain claim was made.' -ForegroundColor DarkYellow
    return $profile
}

function Get-HardwareProfileSupport {
    $className = 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk'
    $requiredProperties = @(
        'Name',
        'AvgDisksecPerTransfer',
        'AvgDisksecPerRead',
        'AvgDisksecPerWrite',
        'CurrentDiskQueueLength',
        'AvgDiskQueueLength',
        'DiskBytesPersec',
        'DiskTransfersPersec',
        'PercentDiskTime',
        'PercentIdleTime'
    )
    try {
        $counterClass = Get-CimClass -Namespace 'root/cimv2' -ClassName $className -ErrorAction Stop
        $availableProperties = @($counterClass.CimClassProperties | ForEach-Object { $_.Name })
        $missingProperties = @($requiredProperties | Where-Object { $_ -notin $availableProperties })
        if ($missingProperties.Count -gt 0) {
            return [pscustomobject][ordered]@{
                supported = $false
                provider = $className
                reason = "The PhysicalDisk provider is missing: $($missingProperties -join ', ')."
                missingProperties = $missingProperties
                physicalDiskInventoryAvailable = [bool](Get-Command 'Get-PhysicalDisk' -ErrorAction SilentlyContinue)
            }
        }

        $probe = @(Get-CimInstance `
            -Namespace 'root/cimv2' `
            -ClassName $className `
            -OperationTimeoutSec 5 `
            -ErrorAction Stop |
            Where-Object { $_.Name -ne '_Total' })
        if ($probe.Count -eq 0) {
            return [pscustomobject][ordered]@{
                supported = $false
                provider = $className
                reason = 'The PhysicalDisk provider returned no per-disk instances.'
                missingProperties = @()
                physicalDiskInventoryAvailable = [bool](Get-Command 'Get-PhysicalDisk' -ErrorAction SilentlyContinue)
            }
        }
    } catch {
        return [pscustomobject][ordered]@{
            supported = $false
            provider = $className
            reason = "The PhysicalDisk provider could not be queried ($($_.Exception.GetType().Name))."
            missingProperties = @()
            physicalDiskInventoryAvailable = [bool](Get-Command 'Get-PhysicalDisk' -ErrorAction SilentlyContinue)
        }
    }

    return [pscustomobject][ordered]@{
        supported = $true
        provider = $className
        reason = 'The inbox formatted PhysicalDisk provider exposes per-disk latency, queue, throughput, and activity signals.'
        missingProperties = @()
        physicalDiskInventoryAvailable = [bool](Get-Command 'Get-PhysicalDisk' -ErrorAction SilentlyContinue)
    }
}

function Get-HardwareStorageInventory {
    $inventoryStatus = 'Unavailable'
    $inventoryErrorType = $null
    $physicalDisks = @()
    if (Get-Command 'Get-PhysicalDisk' -ErrorAction SilentlyContinue) {
        try {
            $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
                [pscustomobject][ordered]@{
                    deviceId = [string]$_.DeviceId
                    friendlyName = [string]$_.FriendlyName
                    manufacturer = [string]$_.Manufacturer
                    model = [string]$_.Model
                    firmwareVersion = [string]$_.FirmwareVersion
                    mediaType = [string]$_.MediaType
                    busType = [string]$_.BusType
                    sizeBytes = [uint64]$_.Size
                    healthStatus = [string]$_.HealthStatus
                    operationalStatus = @($_.OperationalStatus | ForEach-Object { [string]$_ })
                }
            })
            $inventoryStatus = if ($physicalDisks.Count -gt 0) { 'Read' } else { 'NoInstances' }
        } catch {
            $inventoryErrorType = $_.Exception.GetType().Name
        }
    }

    $controllerStatus = 'Unavailable'
    $controllerErrorType = $null
    $controllers = @()
    try {
        $controllers = @(Get-CimInstance `
            -Namespace 'root/cimv2' `
            -ClassName 'Win32_PnPSignedDriver' `
            -OperationTimeoutSec 5 `
            -ErrorAction Stop |
            Where-Object { $_.DeviceClass -in @('SCSIADAPTER', 'HDC') } |
            Select-Object DeviceClass, DeviceName, DriverProviderName, DriverVersion, DriverDate)
        $controllerStatus = if ($controllers.Count -gt 0) { 'Read' } else { 'NoInstances' }
    } catch {
        $controllerErrorType = $_.Exception.GetType().Name
    }

    return [pscustomobject][ordered]@{
        physicalDiskStatus = $inventoryStatus
        physicalDiskErrorType = $inventoryErrorType
        physicalDisks = @($physicalDisks)
        controllerDriverStatus = $controllerStatus
        controllerDriverErrorType = $controllerErrorType
        controllerDrivers = @($controllers)
        redaction = 'Physical-disk serial numbers, unique IDs, PNP IDs, volume labels, paths, files, and user content are not collected.'
    }
}

function Get-HardwareStorageSample {
    param([double]$MonotonicOffsetMilliseconds = 0)

    $queryTimer = [Diagnostics.Stopwatch]::StartNew()
    $instances = @(Get-CimInstance `
        -Namespace 'root/cimv2' `
        -ClassName 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk' `
        -OperationTimeoutSec 5 `
        -ErrorAction Stop |
        Where-Object { $_.Name -ne '_Total' })
    if ($instances.Count -eq 0) {
        throw 'The PhysicalDisk provider returned no per-disk instances.'
    }
    $disks = @($instances | ForEach-Object {
        [pscustomobject][ordered]@{
            instance = [string]$_.Name
            transferLatencyMilliseconds = [Math]::Round(([double]$_.AvgDisksecPerTransfer * 1000), 4)
            readLatencyMilliseconds = [Math]::Round(([double]$_.AvgDisksecPerRead * 1000), 4)
            writeLatencyMilliseconds = [Math]::Round(([double]$_.AvgDisksecPerWrite * 1000), 4)
            currentQueueLength = [Math]::Round([double]$_.CurrentDiskQueueLength, 4)
            averageQueueLength = [Math]::Round([double]$_.AvgDiskQueueLength, 4)
            bytesPerSecond = [Math]::Round([double]$_.DiskBytesPersec, 0)
            transfersPerSecond = [Math]::Round([double]$_.DiskTransfersPersec, 4)
            diskTimePercent = [Math]::Round([double]$_.PercentDiskTime, 4)
            idleTimePercent = [Math]::Round([double]$_.PercentIdleTime, 4)
        }
    })
    $queryTimer.Stop()

    return [pscustomobject][ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        monotonicOffsetMilliseconds = [Math]::Round($MonotonicOffsetMilliseconds, 3)
        queryDurationMilliseconds = [Math]::Round($queryTimer.Elapsed.TotalMilliseconds, 3)
        disks = @($disks)
    }
}

function Measure-HardwareProfileObserver {
    param([ValidateRange(3, 25)][int]$Iterations)

    [void](Get-HardwareStorageSample)
    $durations = @()
    for ($index = 0; $index -lt $Iterations; $index++) {
        $sample = Get-HardwareStorageSample
        $durations += [double]$sample.queryDurationMilliseconds
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        durationMilliseconds = Get-WorkloadDistribution -Values $durations
        qualification = 'Times the complete local per-disk formatted-counter query after one warmup. It generates no storage workload.'
    }
}

function Get-HardwareProfileSummary {
    param(
        [Parameter(Mandatory = $true)][object[]]$Samples,
        [Parameter(Mandatory = $true)][object]$Inventory
    )

    if ($Samples.Count -eq 0) {
        throw 'The hardware storage-path profile requires at least one completed sample.'
    }
    $rows = @($Samples | ForEach-Object { @($_.disks) })
    $diskSummaries = @($rows | Group-Object instance | ForEach-Object {
        $group = @($_.Group)
        [pscustomobject][ordered]@{
            instance = $_.Name
            sampleCount = $group.Count
            transferLatencyMilliseconds = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.transferLatencyMilliseconds })
            readLatencyMilliseconds = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.readLatencyMilliseconds })
            writeLatencyMilliseconds = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.writeLatencyMilliseconds })
            currentQueueLength = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.currentQueueLength })
            averageQueueLength = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.averageQueueLength })
            bytesPerSecond = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.bytesPerSecond })
            transfersPerSecond = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.transfersPerSecond })
            diskTimePercent = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.diskTimePercent })
            idleTimePercent = Get-WorkloadDistribution -Values @($group | ForEach-Object { [double]$_.idleTimePercent })
        }
    })
    $busTypes = @($Inventory.physicalDisks | ForEach-Object { [string]$_.busType } | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    } | Sort-Object -Unique)

    return [pscustomobject][ordered]@{
        sampleCount = $Samples.Count
        observedDiskCount = @($diskSummaries).Count
        observedBusTypes = $busTypes
        disks = $diskSummaries
        queryDurationMilliseconds = Get-WorkloadDistribution -Values @($Samples | ForEach-Object { [double]$_.queryDurationMilliseconds })
        interpretation = 'This passive window records the installed storage transport and observed latency, queue, throughput, and activity distributions. Transport type alone does not prove a bottleneck, and an idle window is not a storage benchmark.'
        decision = 'BaselineOnlyNoPerformanceClaim'
    }
}

function Invoke-HardwareProfile {
    param(
        [string]$Root,
        [ValidateRange(5, 3600)][int]$Seconds,
        [ValidateRange(1, 60)][int]$IntervalSeconds,
        [ValidateRange(3, 25)][int]$CalibrationIterations
    )

    $support = Get-HardwareProfileSupport
    if (-not $support.supported) {
        throw "Hardware storage-path profiling is unsupported: $($support.reason)"
    }
    if ($IntervalSeconds -gt $Seconds) {
        throw 'The hardware profile sample interval cannot exceed the requested duration.'
    }
    Ensure-DataDirectories -Root $Root
    $inventory = Get-HardwareStorageInventory
    $observer = Measure-HardwareProfileObserver -Iterations $CalibrationIterations
    $environment = Get-WindowsEnvironment
    $profileStartUtc = [DateTime]::UtcNow.ToString('o')
    $runTimer = [Diagnostics.Stopwatch]::StartNew()
    $sampleCount = [Math]::Max(2, [int][Math]::Floor($Seconds / $IntervalSeconds) + 1)
    $samples = @()
    for ($sampleIndex = 0; $sampleIndex -lt $sampleCount; $sampleIndex++) {
        $samples += Get-HardwareStorageSample -MonotonicOffsetMilliseconds $runTimer.Elapsed.TotalMilliseconds
        if ($sampleIndex -lt ($sampleCount - 1)) {
            $nextTargetMilliseconds = ($sampleIndex + 1) * $IntervalSeconds * 1000
            $remainingMilliseconds = $nextTargetMilliseconds - $runTimer.Elapsed.TotalMilliseconds
            if ($remainingMilliseconds -gt 0) {
                Start-Sleep -Milliseconds ([int][Math]::Ceiling($remainingMilliseconds))
            }
        }
    }
    $runTimer.Stop()

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    $runSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-$runSuffix-hardware-storage-path-profile.json"
    $profile = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        layer = 2
        kind = 'hardware-storage-path-profile'
        capturedUtc = $profileStartUtc
        completedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        support = $support
        environment = $environment
        inventory = $inventory
        requested = [pscustomobject][ordered]@{
            durationSeconds = $Seconds
            intervalSeconds = $IntervalSeconds
            sampleCount = $sampleCount
            calibrationIterations = $CalibrationIterations
            cimOperationTimeoutSeconds = 5
        }
        instrumentation = [pscustomobject][ordered]@{
            counterSource = 'Win32_PerfFormattedData_PerfDisk_PhysicalDisk per-disk instances'
            inventorySource = 'Get-PhysicalDisk when the inbox Storage module is available; storage controller drivers from Win32_PnPSignedDriver'
            timer = 'System.Diagnostics.Stopwatch'
            observerCalibration = $observer
            actualProfileDurationMilliseconds = [Math]::Round($runTimer.Elapsed.TotalMilliseconds, 3)
            qualification = 'Passive local inventory and formatted-counter reads only. No file is opened, no synthetic I/O is generated, and no Windows setting is changed.'
        }
        collectionScope = 'Records storage model, firmware, media and bus class, health, storage-controller driver metadata, and aggregate per-disk performance counters. It excludes serial numbers, unique IDs, PNP IDs, volume labels, paths, files, user content, credentials, and network destinations.'
        samples = @($samples)
        summary = Get-HardwareProfileSummary -Samples @($samples) -Inventory $inventory
        evidencePath = $evidencePath
    }
    $profile | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    try {
        Write-StructuredEvent -Root $Root -Level Information -Event 'hardware-storage-path-profile-complete' -Data @{
            evidencePath = $evidencePath
            sampleCount = $profile.summary.sampleCount
            observedDiskCount = $profile.summary.observedDiskCount
            observedBusTypes = @($profile.summary.observedBusTypes)
            observationOnly = $true
        }
    } catch {
        Write-Warning "The hardware profile was saved, but the optional event journal could not be updated ($($_.Exception.GetType().Name))."
    }

    Write-Host ''
    Write-Host 'Layer 2 storage-path bottleneck profile (observation only)' -ForegroundColor Cyan
    Write-Host "Installed storage bus types: $(if ($profile.summary.observedBusTypes.Count) { $profile.summary.observedBusTypes -join ', ' } else { 'unavailable' })"
    foreach ($disk in $profile.summary.disks) {
        Write-Host ("{0} - median transfer latency {1} ms, queue {2}, throughput {3} B/s" -f `
            $disk.instance, `
            $disk.transferLatencyMilliseconds.median, `
            $disk.currentQueueLength.median, `
            $disk.bytesPerSecond.median)
    }
    Write-Host $profile.summary.interpretation -ForegroundColor DarkYellow
    Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
    Write-Host 'No storage workload or Windows setting was changed and no performance-gain claim was made.' -ForegroundColor DarkYellow
    return $profile
}

function Get-NativeFirmwareType {
    if (-not ('Lacksan.UxRom.FirmwareNative' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace Lacksan.UxRom
{
    public static class FirmwareNative
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetFirmwareType(out UInt32 firmwareType);
    }
}
'@
    }

    [uint32]$firmwareType = 0
    if (-not [Lacksan.UxRom.FirmwareNative]::GetFirmwareType([ref]$firmwareType)) {
        $errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "GetFirmwareType failed with Win32 error $errorCode."
    }
    $name = switch ($firmwareType) {
        1 { 'Bios' }
        2 { 'Uefi' }
        3 { 'MaxNotImplemented' }
        default { 'Unknown' }
    }
    return [pscustomobject][ordered]@{
        rawValue = $firmwareType
        name = $name
        source = 'Kernel32 GetFirmwareType'
    }
}

function Get-FirmwareProfileSupport {
    $className = 'Win32_BIOS'
    $requiredProperties = @(
        'Manufacturer',
        'SMBIOSBIOSVersion',
        'ReleaseDate',
        'SMBIOSPresent',
        'SMBIOSMajorVersion',
        'SMBIOSMinorVersion',
        'EmbeddedControllerMajorVersion',
        'EmbeddedControllerMinorVersion',
        'Status'
    )
    try {
        $firmwareType = Get-NativeFirmwareType
    } catch {
        return [pscustomobject][ordered]@{
            supported = $false
            provider = $className
            reason = "The documented GetFirmwareType API could not be queried ($($_.Exception.GetType().Name))."
            missingProperties = @()
            firmwareType = $null
        }
    }

    try {
        $biosClass = Get-CimClass -Namespace 'root/cimv2' -ClassName $className -ErrorAction Stop
        $availableProperties = @($biosClass.CimClassProperties | ForEach-Object { $_.Name })
        $missingProperties = @($requiredProperties | Where-Object { $_ -notin $availableProperties })
        if ($missingProperties.Count -gt 0) {
            return [pscustomobject][ordered]@{
                supported = $false
                provider = $className
                reason = "The BIOS provider is missing: $($missingProperties -join ', ')."
                missingProperties = $missingProperties
                firmwareType = $firmwareType
            }
        }
    } catch {
        return [pscustomobject][ordered]@{
            supported = $false
            provider = $className
            reason = "The BIOS provider could not be inspected ($($_.Exception.GetType().Name))."
            missingProperties = @()
            firmwareType = $firmwareType
        }
    }

    return [pscustomobject][ordered]@{
        supported = $true
        provider = $className
        reason = 'The documented firmware-type API and inbox BIOS provider expose the required read-only boundary signals.'
        missingProperties = @()
        firmwareType = $firmwareType
    }
}

function Get-FirmwareCoreSnapshot {
    $queryTimer = [Diagnostics.Stopwatch]::StartNew()
    $firmwareType = Get-NativeFirmwareType
    $bios = Get-CimInstance `
        -Namespace 'root/cimv2' `
        -ClassName 'Win32_BIOS' `
        -OperationTimeoutSec 5 `
        -ErrorAction Stop |
        Select-Object -First 1
    if (-not $bios) {
        throw 'The BIOS provider returned no instance.'
    }
    $queryTimer.Stop()

    $releaseDate = if ($bios.ReleaseDate -is [datetime]) {
        ([datetime]$bios.ReleaseDate).ToUniversalTime().ToString('o')
    } else {
        [string]$bios.ReleaseDate
    }
    return [pscustomobject][ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        queryDurationMilliseconds = [Math]::Round($queryTimer.Elapsed.TotalMilliseconds, 3)
        firmwareType = $firmwareType
        bios = [pscustomobject][ordered]@{
            manufacturer = [string]$bios.Manufacturer
            smbiosBiosVersion = [string]$bios.SMBIOSBIOSVersion
            releaseDateUtc = $releaseDate
            smbiosPresent = [bool]$bios.SMBIOSPresent
            smbiosVersion = '{0}.{1}' -f $bios.SMBIOSMajorVersion, $bios.SMBIOSMinorVersion
            embeddedControllerMajorVersionRaw = [uint16]$bios.EmbeddedControllerMajorVersion
            embeddedControllerMinorVersionRaw = [uint16]$bios.EmbeddedControllerMinorVersion
            status = [string]$bios.Status
        }
        redaction = 'BIOS serial number, system serial number, UUID, asset tag, firmware variables, setting values, passwords, keys, and certificates are not collected.'
    }
}

function Measure-FirmwareProfileObserver {
    param([ValidateRange(3, 25)][int]$Iterations)

    [void](Get-FirmwareCoreSnapshot)
    $durations = @()
    for ($index = 0; $index -lt $Iterations; $index++) {
        $snapshot = Get-FirmwareCoreSnapshot
        $durations += [double]$snapshot.queryDurationMilliseconds
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        durationMilliseconds = Get-WorkloadDistribution -Values $durations
        qualification = 'Times the documented GetFirmwareType call plus the bounded Win32_BIOS query after one warmup. Optional Secure Boot and HP metadata probes report their own wall time.'
    }
}

function Get-SecureBootProfileState {
    param([Parameter(Mandatory = $true)][string]$FirmwareType)

    $timer = [Diagnostics.Stopwatch]::StartNew()
    $command = Get-Command 'Confirm-SecureBootUEFI' -ErrorAction SilentlyContinue
    if (-not $command) {
        $timer.Stop()
        return [pscustomobject][ordered]@{
            status = 'CmdletUnavailable'
            enabled = $null
            errorType = $null
            durationMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds, 3)
        }
    }
    if ($FirmwareType -ne 'Uefi') {
        $timer.Stop()
        return [pscustomobject][ordered]@{
            status = 'NotApplicableToBootMode'
            enabled = $null
            errorType = $null
            durationMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds, 3)
        }
    }

    try {
        $enabled = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
        $status = 'Read'
        $errorType = $null
    } catch {
        $enabled = $null
        $status = 'Unavailable'
        $errorType = $_.Exception.GetType().Name
    }
    $timer.Stop()
    return [pscustomobject][ordered]@{
        status = $status
        enabled = $enabled
        errorType = $errorType
        durationMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds, 3)
    }
}

function Get-HpBiosInterfaceState {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $namespace = 'root/HP/InstrumentedBIOS'
    try {
        $classNames = @(Get-CimClass `
            -Namespace $namespace `
            -OperationTimeoutSec 5 `
            -ErrorAction Stop |
            Where-Object { $_.CimClassName -like 'HP_BIOS*' } |
            ForEach-Object { [string]$_.CimClassName } |
            Sort-Object -Unique)
        $status = if ($classNames.Count -gt 0) { 'MetadataAvailable' } else { 'NoHpBiosClasses' }
        $errorType = $null
    } catch {
        $classNames = @()
        $status = 'Unavailable'
        $errorType = $_.Exception.GetType().Name
    }
    $timer.Stop()
    return [pscustomobject][ordered]@{
        namespace = $namespace
        status = $status
        classNames = @($classNames)
        settingInstancesRead = $false
        writeInterfaceInvoked = $false
        errorType = $errorType
        durationMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds, 3)
        qualification = 'Class metadata only. BIOS setting names, values, passwords, and methods are not queried or invoked.'
    }
}

function Invoke-FirmwareProfile {
    param(
        [string]$Root,
        [ValidateRange(3, 25)][int]$CalibrationIterations
    )

    $support = Get-FirmwareProfileSupport
    if (-not $support.supported) {
        throw "Firmware-boundary profiling is unsupported: $($support.reason)"
    }
    Ensure-DataDirectories -Root $Root
    $observer = Measure-FirmwareProfileObserver -Iterations $CalibrationIterations
    $snapshot = Get-FirmwareCoreSnapshot
    $secureBoot = Get-SecureBootProfileState -FirmwareType $snapshot.firmwareType.name
    $hpBios = Get-HpBiosInterfaceState
    $environment = Get-WindowsEnvironment

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    $runSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-$runSuffix-firmware-boundary-profile.json"
    $profile = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        layer = 3
        kind = 'firmware-boundary-profile'
        capturedUtc = $snapshot.timestampUtc
        completedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        support = $support
        environment = $environment
        firmware = $snapshot
        secureBoot = $secureBoot
        hpBiosInterface = $hpBios
        requested = [pscustomobject][ordered]@{
            calibrationIterations = $CalibrationIterations
            cimOperationTimeoutSeconds = 5
        }
        instrumentation = [pscustomobject][ordered]@{
            coreSource = 'Kernel32 GetFirmwareType plus Win32_BIOS'
            optionalSources = 'Confirm-SecureBootUEFI when present and UEFI; root/HP/InstrumentedBIOS class metadata'
            timer = 'System.Diagnostics.Stopwatch'
            observerCalibration = $observer
            finalCoreQueryMilliseconds = $snapshot.queryDurationMilliseconds
            secureBootProbeMilliseconds = $secureBoot.durationMilliseconds
            hpBiosMetadataProbeMilliseconds = $hpBios.durationMilliseconds
            qualification = 'Read-only local API, CIM metadata, BIOS inventory, and Secure Boot status attempt. No firmware variable or BIOS setting instance is read or written.'
        }
        collectionScope = 'Records boot firmware type, BIOS/SMBIOS and raw embedded-controller version fields, Secure Boot query state, and HP BIOS class names. It excludes serials, UUIDs, asset tags, firmware variables, BIOS setting values, passwords, keys, certificates, files, content, credentials, and destinations.'
        summary = [pscustomobject][ordered]@{
            firmwareType = $snapshot.firmwareType.name
            biosVersion = $snapshot.bios.smbiosBiosVersion
            biosReleaseDateUtc = $snapshot.bios.releaseDateUtc
            smbiosVersion = $snapshot.bios.smbiosVersion
            embeddedControllerVersionRaw = '{0}.{1}' -f $snapshot.bios.embeddedControllerMajorVersionRaw, $snapshot.bios.embeddedControllerMinorVersionRaw
            secureBootStatus = $secureBoot.status
            secureBootEnabled = $secureBoot.enabled
            hpBiosInterfaceStatus = $hpBios.status
            hpBiosClassCount = @($hpBios.classNames).Count
            queryDurationMilliseconds = $snapshot.queryDurationMilliseconds
            interpretation = 'This profile establishes the documented firmware boundary and available management metadata. It does not measure pre-OS firmware duration, prove a BIOS setting is optimal, or authorize a firmware or Secure Boot change.'
            decision = 'BaselineOnlyNoPerformanceClaim'
        }
        evidencePath = $evidencePath
    }
    $profile | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    try {
        Write-StructuredEvent -Root $Root -Level Information -Event 'firmware-boundary-profile-complete' -Data @{
            evidencePath = $evidencePath
            firmwareType = $profile.summary.firmwareType
            biosVersion = $profile.summary.biosVersion
            secureBootStatus = $profile.summary.secureBootStatus
            hpBiosInterfaceStatus = $profile.summary.hpBiosInterfaceStatus
            observationOnly = $true
        }
    } catch {
        Write-Warning "The firmware profile was saved, but the optional event journal could not be updated ($($_.Exception.GetType().Name))."
    }

    Write-Host ''
    Write-Host 'Layer 3 firmware-boundary profile (observation only)' -ForegroundColor Cyan
    Write-Host "Boot mode: $($profile.summary.firmwareType)"
    Write-Host "BIOS: $($profile.summary.biosVersion), released $($profile.summary.biosReleaseDateUtc)"
    Write-Host "SMBIOS / embedded-controller fields: $($profile.summary.smbiosVersion) / $($profile.summary.embeddedControllerVersionRaw)"
    Write-Host "Secure Boot query: $($profile.summary.secureBootStatus)"
    Write-Host "HP BIOS WMI metadata: $($profile.summary.hpBiosInterfaceStatus) ($($profile.summary.hpBiosClassCount) classes)"
    Write-Host $profile.summary.interpretation -ForegroundColor DarkYellow
    Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
    Write-Host 'No BIOS setting, firmware variable, Secure Boot state, or Windows setting was changed.' -ForegroundColor DarkYellow
    return $profile
}

function Get-DriverProfileSupport {
    $requirements = [ordered]@{
        Win32_PnPSignedDriver = @(
            'DeviceID', 'DeviceClass', 'DriverProviderName', 'DriverVersion',
            'DriverDate', 'InfName', 'IsSigned', 'Signer'
        )
        Win32_PnPEntity = @('DeviceID', 'ConfigManagerErrorCode', 'Status', 'Service', 'PNPClass')
    }
    $missing = New-Object System.Collections.ArrayList
    foreach ($className in $requirements.Keys) {
        try {
            $class = Get-CimClass -Namespace 'root/cimv2' -ClassName $className -ErrorAction Stop
            $available = @($class.CimClassProperties | ForEach-Object { [string]$_.Name })
            foreach ($property in $requirements[$className]) {
                if ($property -notin $available) {
                    [void]$missing.Add("$className.$property")
                }
            }
        } catch {
            [void]$missing.Add("$className.<provider-unavailable>")
        }
    }

    return [pscustomobject][ordered]@{
        supported = ($missing.Count -eq 0)
        providers = @($requirements.Keys)
        missingProperties = @($missing)
        serviceControllerAvailable = [bool](Get-Command 'Get-Service' -ErrorAction SilentlyContinue)
        reason = if ($missing.Count -eq 0) {
            'The inbox Plug and Play signed-driver and device providers expose the required read-only package, ownership, and health fields.'
        } else {
            "Required read-only provider fields are unavailable: $(@($missing) -join ', ')."
        }
    }
}

function Get-DriverServiceStates {
    param([string[]]$Names)

    $states = @{}
    foreach ($name in @($Names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)) {
        try {
            $service = Get-Service -Name $name -ErrorAction Stop
            $states[$name] = [pscustomobject][ordered]@{
                status = [string]$service.Status
                startType = [string]$service.StartType
                lookup = 'Read'
            }
        } catch {
            $states[$name] = [pscustomobject][ordered]@{
                status = $null
                startType = $null
                lookup = 'Unavailable'
            }
        }
    }
    return $states
}

function Get-DriverCoreSnapshot {
    param([ValidateRange(64, 2048)][int]$DeviceLimit)

    $timer = [Diagnostics.Stopwatch]::StartNew()
    $signedDrivers = @(Get-CimInstance `
        -Namespace 'root/cimv2' `
        -Query 'SELECT DeviceID, DeviceClass, DriverProviderName, DriverVersion, DriverDate, InfName, IsSigned, Signer FROM Win32_PnPSignedDriver' `
        -OperationTimeoutSec 20 `
        -ErrorAction Stop)
    if ($signedDrivers.Count -gt $DeviceLimit) {
        throw "The signed-driver provider returned $($signedDrivers.Count) records, above the configured safe limit of $DeviceLimit. Raise -DriverDeviceLimit within its supported bound and retry."
    }
    $entities = @(Get-CimInstance `
        -Namespace 'root/cimv2' `
        -Query 'SELECT DeviceID, ConfigManagerErrorCode, Status, Service, PNPClass FROM Win32_PnPEntity' `
        -OperationTimeoutSec 20 `
        -ErrorAction Stop)

    $entityById = @{}
    foreach ($entity in $entities) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entity.DeviceID)) {
            $entityById[[string]$entity.DeviceID] = $entity
        }
    }
    $serviceNames = @($entities | ForEach-Object { [string]$_.Service } | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    } | Sort-Object -Unique)
    $serviceStates = Get-DriverServiceStates -Names $serviceNames
    $captureSalt = [guid]::NewGuid().ToString('N')
    $devices = New-Object System.Collections.ArrayList

    foreach ($driver in $signedDrivers) {
        $rawDeviceId = [string]$driver.DeviceID
        $entity = if ($entityById.ContainsKey($rawDeviceId)) { $entityById[$rawDeviceId] } else { $null }
        $serviceName = if ($entity) { [string]$entity.Service } else { $null }
        $serviceState = if ($serviceName -and $serviceStates.ContainsKey($serviceName)) {
            $serviceStates[$serviceName]
        } else {
            [pscustomobject]@{ status = $null; startType = $null; lookup = 'NotDeclared' }
        }
        $driverDateUtc = if ($driver.DriverDate -is [datetime]) {
            ([datetime]$driver.DriverDate).ToUniversalTime().ToString('o')
        } else {
            [string]$driver.DriverDate
        }
        [void]$devices.Add([pscustomobject][ordered]@{
            deviceKeySha256 = Get-RedactedDependencyHash -Value "$captureSalt|$rawDeviceId"
            deviceClass = [string]$driver.DeviceClass
            pnpClass = if ($entity) { [string]$entity.PNPClass } else { $null }
            infName = [string]$driver.InfName
            provider = [string]$driver.DriverProviderName
            version = [string]$driver.DriverVersion
            dateUtc = $driverDateUtc
            isSigned = [bool]$driver.IsSigned
            signer = [string]$driver.Signer
            configManagerErrorCode = if ($entity) { [int]$entity.ConfigManagerErrorCode } else { $null }
            pnpStatus = if ($entity) { [string]$entity.Status } else { 'EntityNotMatched' }
            serviceName = $serviceName
            serviceStatus = $serviceState.status
            serviceStartType = $serviceState.startType
            serviceLookup = $serviceState.lookup
        })
    }
    $timer.Stop()

    $packages = @($devices | Group-Object -Property {
        '{0}|{1}|{2}|{3}|{4}' -f $_.infName, $_.provider, $_.version, $_.dateUtc, $_.deviceClass
    } | ForEach-Object {
        $first = @($_.Group)[0]
        [pscustomobject][ordered]@{
            infName = $first.infName
            provider = $first.provider
            version = $first.version
            dateUtc = $first.dateUtc
            deviceClass = $first.deviceClass
            isSigned = (@($_.Group | Where-Object isSigned).Count -eq @($_.Group).Count)
            signer = $first.signer
            deviceCount = @($_.Group).Count
            problemDeviceCount = @($_.Group | Where-Object { $_.configManagerErrorCode -ne $null -and $_.configManagerErrorCode -ne 0 }).Count
            declaredServices = @($_.Group.serviceName | Where-Object { $_ } | Sort-Object -Unique)
        }
    } | Sort-Object provider, deviceClass, infName, version)

    return [pscustomobject][ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        durationMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds, 3)
        devices = @($devices)
        packages = @($packages)
        providerSummary = @($devices | Group-Object provider | ForEach-Object {
            [pscustomobject][ordered]@{ provider = $_.Name; deviceCount = @($_.Group).Count }
        } | Sort-Object -Property @{ Expression = 'deviceCount'; Descending = $true }, provider)
        classSummary = @($devices | Group-Object deviceClass | ForEach-Object {
            [pscustomobject][ordered]@{ deviceClass = $_.Name; deviceCount = @($_.Group).Count }
        } | Sort-Object -Property @{ Expression = 'deviceCount'; Descending = $true }, deviceClass)
        redaction = 'Device and hardware identifiers are replaced with capture-local salted SHA-256 keys. Device names, descriptions, locations, paths, serials, command lines, and customer content are not collected. The salt is discarded, so device keys cannot be correlated across captures.'
    }
}

function Measure-DriverProfileObserver {
    param(
        [ValidateRange(3, 25)][int]$Iterations,
        [ValidateRange(64, 2048)][int]$DeviceLimit
    )

    [void](Get-DriverCoreSnapshot -DeviceLimit $DeviceLimit)
    $durations = @()
    $snapshot = $null
    for ($index = 0; $index -lt $Iterations; $index++) {
        $snapshot = Get-DriverCoreSnapshot -DeviceLimit $DeviceLimit
        $durations += [double]$snapshot.durationMilliseconds
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        durationMilliseconds = Get-WorkloadDistribution -Values $durations
        finalSnapshot = $snapshot
        qualification = 'Times the bounded signed-driver and Plug and Play CIM queries, exact driver-service lookups, redaction, and aggregation after one warmup. It does not measure driver execution cost.'
    }
}

function Get-DriverProfileEnvironment {
    $source = Get-WindowsEnvironment
    return [pscustomobject][ordered]@{
        capturedUtc = $source.capturedUtc
        windows = $source.windows
        computer = $source.computer
        bios = $source.bios
        processor = $source.processor
        edgeVersion = $source.edgeVersion
        power = $source.power
        thermalZoneCelsius = $source.thermalZoneCelsius
        redaction = 'Storage device names, network adapter names and descriptions, and the general environment driver-name list are omitted here. Package ownership is represented only by the bounded redacted profile.'
    }
}

function Invoke-DriverProfile {
    param(
        [string]$Root,
        [ValidateRange(3, 25)][int]$CalibrationIterations,
        [ValidateRange(64, 2048)][int]$DeviceLimit
    )

    $support = Get-DriverProfileSupport
    if (-not $support.supported) {
        throw "Driver/OEM ownership profiling is unsupported: $($support.reason)"
    }
    Ensure-DataDirectories -Root $Root
    $observer = Measure-DriverProfileObserver -Iterations $CalibrationIterations -DeviceLimit $DeviceLimit
    $snapshot = $observer.finalSnapshot
    $environment = Get-DriverProfileEnvironment
    $devices = @($snapshot.devices)

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    $runSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-$runSuffix-driver-oem-ownership-profile.json"
    $profile = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        layer = 4
        kind = 'driver-oem-ownership-profile'
        capturedUtc = $snapshot.timestampUtc
        completedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        support = $support
        environment = $environment
        requested = [pscustomobject][ordered]@{
            calibrationIterations = $CalibrationIterations
            deviceLimit = $DeviceLimit
            cimOperationTimeoutSeconds = 20
        }
        instrumentation = [pscustomobject][ordered]@{
            sources = 'Win32_PnPSignedDriver, Win32_PnPEntity, and exact Get-Service driver-service lookups'
            timer = 'System.Diagnostics.Stopwatch'
            observerCalibration = [pscustomobject][ordered]@{
                iterations = $observer.iterations
                durationMilliseconds = $observer.durationMilliseconds
                qualification = $observer.qualification
            }
            qualification = 'This inventory reports static package ownership, PnP health, and service-controller state. It does not measure DPC/ISR latency, package age suitability, update availability, or driver execution overhead.'
        }
        collectionScope = $snapshot.redaction
        devices = @($devices)
        packages = @($snapshot.packages)
        providerSummary = @($snapshot.providerSummary)
        classSummary = @($snapshot.classSummary)
        summary = [pscustomobject][ordered]@{
            deviceRecordCount = $devices.Count
            packageCount = @($snapshot.packages).Count
            providerCount = @($snapshot.providerSummary).Count
            problemDeviceCount = @($devices | Where-Object { $_.configManagerErrorCode -ne $null -and $_.configManagerErrorCode -ne 0 }).Count
            unsignedDeviceRecordCount = @($devices | Where-Object { -not $_.isSigned }).Count
            serviceReadCount = @($devices | Where-Object { $_.serviceLookup -eq 'Read' }).Count
            serviceUnavailableCount = @($devices | Where-Object { $_.serviceLookup -eq 'Unavailable' }).Count
            interpretation = 'This map identifies which signed packages and driver services own detected Plug and Play devices. A provider, date, stopped demand driver, or static status alone does not prove overhead, incompatibility, or an update need.'
            decision = 'BaselineOnlyNoPerformanceClaim'
        }
        evidencePath = $evidencePath
    }
    $profile | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    try {
        Write-StructuredEvent -Root $Root -Level Information -Event 'driver-oem-ownership-profile-complete' -Data @{
            evidencePath = $evidencePath
            deviceRecordCount = $profile.summary.deviceRecordCount
            packageCount = $profile.summary.packageCount
            problemDeviceCount = $profile.summary.problemDeviceCount
            observationOnly = $true
        }
    } catch {
        Write-Warning "The driver profile was saved, but the optional event journal could not be updated ($($_.Exception.GetType().Name))."
    }

    Write-Host ''
    Write-Host 'Layer 4 driver and OEM ownership profile (observation only)' -ForegroundColor Cyan
    Write-Host "Devices / packages / providers: $($profile.summary.deviceRecordCount) / $($profile.summary.packageCount) / $($profile.summary.providerCount)"
    Write-Host "PnP problem records / unsigned records: $($profile.summary.problemDeviceCount) / $($profile.summary.unsignedDeviceRecordCount)"
    Write-Host "Driver-service reads / unavailable: $($profile.summary.serviceReadCount) / $($profile.summary.serviceUnavailableCount)"
    Write-Host $profile.summary.interpretation -ForegroundColor DarkYellow
    Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
    Write-Host 'No driver package, service, device, OEM component, or Windows setting was changed.' -ForegroundColor DarkYellow
    return $profile
}

function Get-KernelProfileCounterCatalog {
    return @(
        [pscustomobject]@{ key = 'processorUtilityPercent'; path = '\Processor Information(_Total)\% Processor Utility'; unit = 'percent' },
        [pscustomobject]@{ key = 'dpcTimePercent'; path = '\Processor Information(_Total)\% DPC Time'; unit = 'percent' },
        [pscustomobject]@{ key = 'interruptTimePercent'; path = '\Processor Information(_Total)\% Interrupt Time'; unit = 'percent' },
        [pscustomobject]@{ key = 'dpcsQueuedPerSecond'; path = '\Processor Information(_Total)\DPCs Queued/sec'; unit = 'per-second' },
        [pscustomobject]@{ key = 'interruptsPerSecond'; path = '\Processor Information(_Total)\Interrupts/sec'; unit = 'per-second' },
        [pscustomobject]@{ key = 'contextSwitchesPerSecond'; path = '\System\Context Switches/sec'; unit = 'per-second' },
        [pscustomobject]@{ key = 'processorQueueLength'; path = '\System\Processor Queue Length'; unit = 'count' },
        [pscustomobject]@{ key = 'pageReadsPerSecond'; path = '\Memory\Page Reads/sec'; unit = 'per-second' },
        [pscustomobject]@{ key = 'pagesInputPerSecond'; path = '\Memory\Pages Input/sec'; unit = 'per-second' },
        [pscustomobject]@{ key = 'availableMemoryMb'; path = '\Memory\Available MBytes'; unit = 'megabytes' },
        [pscustomobject]@{ key = 'diskLatencyMilliseconds'; path = '\PhysicalDisk(_Total)\Avg. Disk sec/Transfer'; unit = 'milliseconds' },
        [pscustomobject]@{ key = 'diskQueueLength'; path = '\PhysicalDisk(_Total)\Current Disk Queue Length'; unit = 'count' }
    )
}

function Get-KernelProfileSupport {
    $counterCommand = Get-Command 'Get-Counter' -ErrorAction SilentlyContinue
    if (-not $counterCommand) {
        return [pscustomobject][ordered]@{
            supported = $false
            reason = 'Get-Counter is unavailable on this Windows host.'
            requiredCounters = @()
            missingCounters = @()
        }
    }

    $catalog = @(Get-KernelProfileCounterCatalog)
    $paths = @($catalog.path)
    try {
        $probe = Get-Counter -Counter $paths -MaxSamples 1 -ErrorAction Stop
        $observedPaths = @($probe.CounterSamples | ForEach-Object { [string]$_.Path })
        $missing = @($catalog | Where-Object {
            $requiredSuffix = ([string]$_.path).ToLowerInvariant()
            -not @($observedPaths | Where-Object { ([string]$_).ToLowerInvariant().EndsWith($requiredSuffix) }).Count
        } | ForEach-Object { [string]$_.path })
    } catch {
        return [pscustomobject][ordered]@{
            supported = $false
            reason = "The required local performance-counter set could not be read ($($_.Exception.GetType().Name)). Counter names are localized and this build requires every declared path."
            requiredCounters = $paths
            missingCounters = $paths
        }
    }

    return [pscustomobject][ordered]@{
        supported = ($missing.Count -eq 0)
        reason = if ($missing.Count -eq 0) {
            'The complete local DPC/ISR, scheduling, memory-paging, and disk-pressure counter set is readable.'
        } else {
            "Required counter paths were not returned: $($missing -join ', ')."
        }
        requiredCounters = $paths
        missingCounters = $missing
    }
}

function ConvertFrom-KernelCounterSampleSet {
    param([Parameter(Mandatory = $true)][object]$SampleSet)

    $catalog = @(Get-KernelProfileCounterCatalog)
    $values = [ordered]@{}
    foreach ($item in $catalog) { $values[$item.key] = $null }
    foreach ($sample in @($SampleSet.CounterSamples)) {
        $samplePath = ([string]$sample.Path).ToLowerInvariant()
        foreach ($item in $catalog) {
            if ($samplePath.EndsWith(([string]$item.path).ToLowerInvariant())) {
                $value = [double]$sample.CookedValue
                if ($item.key -eq 'diskLatencyMilliseconds') { $value *= 1000 }
                $values[$item.key] = [Math]::Round($value, 4)
                break
            }
        }
    }

    $timestamp = if ($SampleSet.Timestamp -is [datetime]) {
        ([datetime]$SampleSet.Timestamp).ToUniversalTime().ToString('o')
    } else {
        [DateTime]::UtcNow.ToString('o')
    }
    return [pscustomobject][ordered]@{
        timestampUtc = $timestamp
        processorUtilityPercent = $values.processorUtilityPercent
        dpcTimePercent = $values.dpcTimePercent
        interruptTimePercent = $values.interruptTimePercent
        dpcsQueuedPerSecond = $values.dpcsQueuedPerSecond
        interruptsPerSecond = $values.interruptsPerSecond
        contextSwitchesPerSecond = $values.contextSwitchesPerSecond
        processorQueueLength = $values.processorQueueLength
        pageReadsPerSecond = $values.pageReadsPerSecond
        pagesInputPerSecond = $values.pagesInputPerSecond
        availableMemoryMb = $values.availableMemoryMb
        diskLatencyMilliseconds = $values.diskLatencyMilliseconds
        diskQueueLength = $values.diskQueueLength
    }
}

function Get-KernelMetricDistributions {
    param([Parameter(Mandatory = $true)][object[]]$Samples)

    $metrics = [ordered]@{}
    foreach ($item in Get-KernelProfileCounterCatalog) {
        $values = @($Samples | ForEach-Object {
            $value = $_.($item.key)
            if ($null -ne $value) { [double]$value }
        })
        $metrics[$item.key] = Get-WorkloadDistribution -Values $values
    }
    return [pscustomobject]$metrics
}

function Get-KernelCounterBlock {
    param(
        [ValidateRange(1, 15)][int]$BlockNumber,
        [ValidateRange(3, 60)][int]$SamplesPerBlock,
        [ValidateRange(1, 10)][int]$SampleIntervalSeconds
    )

    $paths = @((Get-KernelProfileCounterCatalog).path)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $sampleSets = @(Get-Counter `
        -Counter $paths `
        -SampleInterval $SampleIntervalSeconds `
        -MaxSamples $SamplesPerBlock `
        -ErrorAction Stop)
    $timer.Stop()
    $samples = @($sampleSets | ForEach-Object { ConvertFrom-KernelCounterSampleSet -SampleSet $_ })
    if ($samples.Count -ne $SamplesPerBlock) {
        throw "Kernel-pressure block $BlockNumber returned $($samples.Count) samples; $SamplesPerBlock were required."
    }
    $expectedSpanMilliseconds = [double](($SamplesPerBlock - 1) * $SampleIntervalSeconds * 1000)
    return [pscustomobject][ordered]@{
        blockNumber = $BlockNumber
        sampleCount = $samples.Count
        sampleIntervalSeconds = $SampleIntervalSeconds
        expectedSamplingSpanMilliseconds = $expectedSpanMilliseconds
        wallDurationMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds, 4)
        observerAndSchedulingExcessMilliseconds = [Math]::Round(($timer.Elapsed.TotalMilliseconds - $expectedSpanMilliseconds), 4)
        samples = @($samples)
        metrics = Get-KernelMetricDistributions -Samples @($samples)
    }
}

function Measure-KernelCounterObserver {
    param([ValidateRange(3, 25)][int]$Iterations)

    $paths = @((Get-KernelProfileCounterCatalog).path)
    [void](Get-Counter -Counter $paths -MaxSamples 1 -ErrorAction Stop)
    $durations = @()
    for ($index = 0; $index -lt $Iterations; $index++) {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        [void](Get-Counter -Counter $paths -MaxSamples 1 -ErrorAction Stop)
        $timer.Stop()
        $durations += $timer.Elapsed.TotalMilliseconds
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        durationMilliseconds = Get-WorkloadDistribution -Values $durations
        qualification = 'Times one complete 12-counter local snapshot after one warmup. Block wall time and expected inter-sample span are retained separately; measured values are not overhead-corrected.'
    }
}

function Get-KernelTraceToolState {
    $programFilesX86 = ${env:ProgramFiles(x86)}
    $wptRoot = if ($programFilesX86) {
        Join-Path $programFilesX86 'Windows Kits\10\Windows Performance Toolkit'
    }
    else {
        $null
    }
    $wprAvailable = [bool](Get-Command 'wpr.exe' -ErrorAction SilentlyContinue)
    $wpaAvailable = [bool](Get-Command 'wpa.exe' -ErrorAction SilentlyContinue) -or
        [bool]($wptRoot -and (Test-Path -LiteralPath (Join-Path $wptRoot 'wpa.exe')))
    $exporterAvailable = [bool](Get-Command 'wpaexporter.exe' -ErrorAction SilentlyContinue) -or
        [bool]($wptRoot -and (Test-Path -LiteralPath (Join-Path $wptRoot 'wpaexporter.exe')))
    $wprState = if ($wprAvailable) { Get-WprRecordingState } else { [pscustomobject]@{ state = 'unavailable' } }
    return [pscustomobject][ordered]@{
        wprAvailable = $wprAvailable
        wprRecordingState = [string]$wprState.state
        wpaAvailable = $wpaAvailable
        wpaExporterAvailable = $exporterAvailable
        automatedModuleAttributionReady = ($wprAvailable -and $exporterAvailable)
        traceStarted = $false
        qualification = 'This profile does not start, stop, cancel, or export an ETW session. WPR/WPA is the documented next step for module and function attribution during a declared slow interval.'
    }
}

function Get-KernelProfileEnvironment {
    $source = Get-WindowsEnvironment
    $adapterStates = @($source.networkAdapters | Group-Object Status | ForEach-Object {
        [pscustomobject][ordered]@{ status = $_.Name; count = @($_.Group).Count }
    })
    return [pscustomobject][ordered]@{
        capturedUtc = $source.capturedUtc
        windows = $source.windows
        computer = $source.computer
        bios = $source.bios
        processor = $source.processor
        edgeVersion = $source.edgeVersion
        power = $source.power
        thermalZoneCelsius = $source.thermalZoneCelsius
        networkConditions = [pscustomobject][ordered]@{
            physicalAdapterCount = @($source.networkAdapters).Count
            statusCounts = $adapterStates
            namesAndAddressesCollected = $false
        }
        workload = 'Passive local system-pressure window; no application was launched or controlled.'
        redaction = 'Process lists, storage names, network adapter names, descriptions, addresses, driver names, paths, command lines, and customer content are omitted.'
    }
}

function Get-KernelProfileSummary {
    param([Parameter(Mandatory = $true)][object[]]$Blocks)

    $allSamples = @($Blocks | ForEach-Object { @($_.samples) })
    $blockMedianDistributions = [ordered]@{}
    foreach ($item in Get-KernelProfileCounterCatalog) {
        $blockMedians = @($Blocks | ForEach-Object {
            $metric = $_.metrics.($item.key)
            if ($null -ne $metric.median) { [double]$metric.median }
        })
        $blockMedianDistributions[$item.key] = Get-WorkloadDistribution -Values $blockMedians
    }
    return [pscustomobject][ordered]@{
        blockCount = $Blocks.Count
        sampleCount = $allSamples.Count
        rawSampleDistributions = Get-KernelMetricDistributions -Samples $allSamples
        blockMedianDistributions = [pscustomobject]$blockMedianDistributions
        interpretation = 'These correlated counters screen for scheduler, interrupt, paging, and storage pressure. They do not identify a responsible module, prove a latency cause, or replace workflow-scoped WPR/WPA DPC/ISR duration and stack analysis.'
        decision = 'BaselineOnlyNoPerformanceClaim'
    }
}

function Invoke-KernelProfile {
    param(
        [string]$Root,
        [ValidateRange(3, 15)][int]$BlockCount,
        [ValidateRange(3, 60)][int]$SamplesPerBlock,
        [ValidateRange(1, 10)][int]$SampleIntervalSeconds,
        [ValidateRange(3, 25)][int]$CalibrationIterations
    )

    $support = Get-KernelProfileSupport
    if (-not $support.supported) {
        throw "Kernel-pressure profiling is unsupported: $($support.reason)"
    }
    Ensure-DataDirectories -Root $Root
    $observer = Measure-KernelCounterObserver -Iterations $CalibrationIterations
    $blocks = @()
    for ($blockNumber = 1; $blockNumber -le $BlockCount; $blockNumber++) {
        $blocks += Get-KernelCounterBlock `
            -BlockNumber $blockNumber `
            -SamplesPerBlock $SamplesPerBlock `
            -SampleIntervalSeconds $SampleIntervalSeconds
    }
    $environment = Get-KernelProfileEnvironment
    $traceTools = Get-KernelTraceToolState
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
}

function Get-WprRecordingState {
    if (-not (Get-Command 'wpr.exe' -ErrorAction SilentlyContinue)) {
        return [pscustomobject][ordered]@{
            available = $false
            state = 'unavailable'
            raw = $null
        }
    }

    $status = Invoke-NativeCommand -FilePath 'wpr.exe' -Arguments @('-status') -AllowFailure
    $state = 'unknown'
    if ($status.ExitCode -eq 0) {
        if ($status.Output -match '(?i)\bWPR is not recording\b') {
            $state = 'idle'
        } elseif (
            $status.Output -match '(?i)\bWPR recording is in progress\b' -or
            $status.Output -match '(?i)\bActively recording collectors\b'
        ) {
            $state = 'recording'
        }
    }

    return [pscustomobject][ordered]@{
        available = $true
        state = $state
        raw = $status.Output
    }
}

function Get-WprBusyGuidance {
    return 'An existing WPR recording is active and was preserved. In an elevated console, inspect it with "wpr -status"; save it with "wpr -stop C:\Temp\existing-trace.etl"; discard it with "wpr -cancel"; or rerun ZBookPerf Analyze with -NoTrace.'
}

function Start-WprCapture {
    param([string]$Root, [string]$Stamp, [switch]$Skip)

    $trace = [ordered]@{
        status = 'not-started'
        reason = $null
        etlPath = $null
        csvPath = $null
        summaryPath = $null
        existingRecordingPreserved = $false
    }
    if ($Skip) {
        $trace.status = 'skipped'
        $trace.reason = 'Tracing was disabled with -NoTrace.'
        return [pscustomobject]$trace
    }
    if (-not (Get-Command 'wpr.exe' -ErrorAction SilentlyContinue)) {
        $trace.status = 'unavailable'
        $trace.reason = 'wpr.exe was not found. Install the Windows Performance Toolkit from the Windows ADK.'
        return [pscustomobject]$trace
    }
    if (-not (Test-IsAdministrator)) {
        $trace.status = 'skipped'
        $trace.reason = 'WPR kernel tracing requires an elevated console; counters were captured instead.'
        return [pscustomobject]$trace
    }

    $recordingState = Get-WprRecordingState
    if ($recordingState.state -eq 'recording') {
        $trace.status = 'busy'
        $trace.reason = Get-WprBusyGuidance
        $trace.existingRecordingPreserved = $true
        return [pscustomobject]$trace
    }
    if ($recordingState.state -ne 'idle') {
        $trace.status = 'status-unavailable'
        $trace.reason = 'ZBookPerf could not prove that WPR was idle, so it did not start or cancel a trace. Run "wpr -status" in an elevated console, or rerun Analyze with -NoTrace.'
        return [pscustomobject]$trace
    }

    $start = Invoke-NativeCommand -FilePath 'wpr.exe' -Arguments @('-start', 'GeneralProfile', '-start', 'CPU', '-start', 'DiskIO', '-filemode') -AllowFailure
    if ($start.ExitCode -ne 0) {
        if ($start.Output -match '(?i)0xc5583001|profiles are already running') {
            $trace.status = 'busy'
            $trace.reason = Get-WprBusyGuidance
            $trace.existingRecordingPreserved = $true
            return [pscustomobject]$trace
        }
        $trace.status = 'failed-to-start'
        $trace.reason = $start.Output
        return [pscustomobject]$trace
    }
    $trace.status = 'recording'
    $trace.etlPath = Join-Path (Join-Path $Root 'traces') "$Stamp.etl"
    return [pscustomobject]$trace
}

function Stop-WprCapture {
    param([object]$Trace)

    if ($Trace.status -ne 'recording') { return $Trace }
    $stop = Invoke-NativeCommand -FilePath 'wpr.exe' -Arguments @('-stop', $Trace.etlPath) -AllowFailure
    if ($stop.ExitCode -ne 0) {
        [void](Invoke-NativeCommand -FilePath 'wpr.exe' -Arguments @('-cancel') -AllowFailure)
        $Trace.status = 'failed-to-stop'
        $Trace.reason = $stop.Output
        return $Trace
    }
    $Trace.status = 'captured'
    if (Get-Command 'tracerpt.exe' -ErrorAction SilentlyContinue) {
        $Trace.csvPath = [IO.Path]::ChangeExtension($Trace.etlPath, '.csv')
        $Trace.summaryPath = [IO.Path]::ChangeExtension($Trace.etlPath, '.summary.txt')
        $conversion = Invoke-NativeCommand -FilePath 'tracerpt.exe' -Arguments @($Trace.etlPath, '-of', 'CSV', '-o', $Trace.csvPath, '-summary', $Trace.summaryPath, '-y') -AllowFailure
        if ($conversion.ExitCode -ne 0) {
            $Trace.reason = "ETL captured; tracerpt conversion failed: $($conversion.Output)"
        }
    }
    return $Trace
}

function Invoke-Measurement {
    param(
        [ValidateSet('baseline', 'after')][string]$Kind,
        [int]$Seconds,
        [int]$Interval,
        [string]$Root,
        [switch]$SkipTrace
    )

    Ensure-DataDirectories -Root $Root
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $environment = Get-WindowsEnvironment
    $trace = Start-WprCapture -Root $Root -Stamp "$stamp-$Kind" -Skip:$SkipTrace
    $samples = New-Object System.Collections.ArrayList
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        while ($stopwatch.Elapsed.TotalSeconds -lt $Seconds) {
            [void]$samples.Add((Get-PerformanceSample))
            $percent = [Math]::Min(100, [int](($stopwatch.Elapsed.TotalSeconds / $Seconds) * 100))
            Write-Progress -Activity "Capturing $Kind performance evidence" -Status "$($samples.Count) samples" -PercentComplete $percent
            if ($stopwatch.Elapsed.TotalSeconds -lt $Seconds) {
                Start-Sleep -Seconds $Interval
            }
        }
    } finally {
        $stopwatch.Stop()
        Write-Progress -Activity "Capturing $Kind performance evidence" -Completed
        $trace = Stop-WprCapture -Trace $trace
    }

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
    Show-MeasurementSummary -Measurement $measurement
    return $measurement
}

function Show-MeasurementComparison {
    param([string]$Root)

    $sessionPath = Join-Path $Root 'session.json'
    if (-not (Test-Path -LiteralPath $sessionPath)) { throw 'No measurement session exists. Run Analyze first.' }
    $session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
    if (-not $session.baselinePath -or -not $session.afterPath) { throw 'Both baseline and after measurements are required.' }
    $baseline = Get-Content -LiteralPath $session.baselinePath -Raw | ConvertFrom-Json
    $after = Get-Content -LiteralPath $session.afterPath -Raw | ConvertFrom-Json

    $rows = @(
        [pscustomobject]@{ Metric = 'CPU median (%)'; Baseline = $baseline.summary.metrics.cpuMedianPercent; After = $after.summary.metrics.cpuMedianPercent },
        [pscustomobject]@{ Metric = 'DPC median (%)'; Baseline = $baseline.summary.metrics.dpcMedianPercent; After = $after.summary.metrics.dpcMedianPercent },
        [pscustomobject]@{ Metric = 'ISR median (%)'; Baseline = $baseline.summary.metrics.interruptMedianPercent; After = $after.summary.metrics.interruptMedianPercent },
        [pscustomobject]@{ Metric = 'Disk latency median (ms)'; Baseline = $baseline.summary.metrics.diskLatencyMedianMs; After = $after.summary.metrics.diskLatencyMedianMs },
        [pscustomobject]@{ Metric = 'Disk queue median'; Baseline = $baseline.summary.metrics.diskQueueMedian; After = $after.summary.metrics.diskQueueMedian },
        [pscustomobject]@{ Metric = 'Memory committed median (%)'; Baseline = $baseline.summary.metrics.memoryCommittedMedianPercent; After = $after.summary.metrics.memoryCommittedMedianPercent }
    ) | ForEach-Object {
        $_ | Add-Member -NotePropertyName Delta -NotePropertyValue ([Math]::Round(([double]$_.After - [double]$_.Baseline), 3)) -PassThru
    }

    Write-Host ''
    Write-Host 'Baseline versus after (negative is not automatically better for every metric)' -ForegroundColor Cyan
    $rows | Format-Table -AutoSize | Out-Host
    Write-Host 'A change is not accepted from one short pair. Repeat controlled runs and compare medians, variability, errors, and side effects.' -ForegroundColor DarkYellow
}

function Invoke-LiveWatch {
    param([int]$Interval, [int]$MaximumSamples)

    Write-Host 'Live watch: press Q to stop.' -ForegroundColor Cyan
    $count = 0
    while ($true) {
        $sample = Get-PerformanceSample
        Clear-Host
        Write-Host "ZBookPerf live watch  $($sample.timestampUtc)" -ForegroundColor Cyan
        Write-Host ("CPU    [{0}] {1,6:N1}%" -f (New-HorizontalBar $sample.cpuUtilityPercent), $sample.cpuUtilityPercent)
        Write-Host ("Memory [{0}] {1,6:N1}%" -f (New-HorizontalBar $sample.memoryCommittedPercent), $sample.memoryCommittedPercent)
        Write-Host ("Disk: {0:N2} ms, queue {1:N2}    DPC/ISR: {2:N3}% / {3:N3}%" -f $sample.diskLatencyMs, $sample.diskQueueLength, $sample.dpcPercent, $sample.interruptPercent)
        $sample.processes | Sort-Object PercentProcessorTime -Descending | Select-Object -First $Top Name, IDProcess, PercentProcessorTime, IODataBytesPersec, WorkingSetPrivate | Format-Table -AutoSize | Out-Host
        Write-Host 'Press Q to stop.' -ForegroundColor DarkGray
        $count++
        if ($MaximumSamples -gt 0 -and $count -ge $MaximumSamples) { break }
        $deadline = (Get-Date).AddSeconds($Interval)
        while ((Get-Date) -lt $deadline) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq [ConsoleKey]::Q) { return }
            }
            Start-Sleep -Milliseconds 100
        }
    }
}

function Get-PowerSchemeGuid {
    param([string]$Output)
    $match = [regex]::Match($Output, '([0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12})')
    if (-not $match.Success) { throw "Could not parse a power-scheme GUID from: $Output" }
    return $match.Groups[1].Value.ToLowerInvariant()
}

function Get-PowerAcValue {
    param([string]$SchemeGuid, [string]$SettingAlias)

    $query = Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/query', $SchemeGuid, 'SUB_PROCESSOR', $SettingAlias)
    $match = [regex]::Match($query.Output, 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)')
    if (-not $match.Success) { throw "Could not read the AC value for $SettingAlias in scheme $SchemeGuid." }
    return [Convert]::ToInt32($match.Groups[1].Value, 16)
}

function Get-PowerCandidateSupport {
    $schemes = Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/list') -AllowFailure
    if ($schemes.ExitCode -ne 0) {
        return [pscustomobject][ordered]@{
            supported = $false
            modernStandbyDetected = $null
            reason = "powercfg could not enumerate power schemes: $($schemes.Output)"
        }
    }

    $sleepStates = Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/availablesleepstates') -AllowFailure
    $modernStandby = (
        $sleepStates.ExitCode -eq 0 -and
        $sleepStates.Output -match '(?i)Standby \(S0 Low Power Idle\)'
    )
    $highPerformanceListed = $schemes.Output -match [regex]::Escape($script:HighPerformanceScheme)

    if (-not $highPerformanceListed) {
        $reason = 'The built-in High performance plan is not enumerated by powercfg.'
        if ($modernStandby) {
            $reason += ' This PC uses Modern Standby, where the Balanced plan and Windows Power mode are the supported performance surface.'
        }
        $reason += ' ZBookPerf will not create or activate a substitute plan.'
        return [pscustomobject][ordered]@{
            supported = $false
            modernStandbyDetected = [bool]$modernStandby
            reason = $reason
        }
    }

    return [pscustomobject][ordered]@{
        supported = $true
        modernStandbyDetected = [bool]$modernStandby
        reason = 'The built-in High performance plan is enumerated and can be captured before application.'
    }
}

function Get-PowerCandidateState {
    $support = Get-PowerCandidateSupport
    if (-not $support.supported) {
        throw "PowerAc is unsupported on this PC. $($support.reason) No setting was changed."
    }
    $active = Get-PowerSchemeGuid -Output (Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/getactivescheme')).Output

    $values = [ordered]@{}
    $attributes = [ordered]@{}
    foreach ($alias in $script:PowerSettings.Keys) {
        $values[$alias] = Get-PowerAcValue -SchemeGuid $script:HighPerformanceScheme -SettingAlias $alias
        $path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$($script:ProcessorSubgroup)\$($script:PowerSettings[$alias])"
        $attributes[$alias] = Get-RegistryValueState -Path $path -Name 'Attributes'
    }
    $autonomous = $null
    try {
        $autonomous = Get-PowerAcValue -SchemeGuid $script:HighPerformanceScheme -SettingAlias 'PERFAUTONOMOUS'
    } catch {
        $autonomous = $null
    }

    return [pscustomobject][ordered]@{
        activeSchemeGuid = $active
        targetSchemeGuid = $script:HighPerformanceScheme
        acValues = [pscustomobject]$values
        attributeStates = [pscustomobject]$attributes
        autonomousMode = $autonomous
    }
}

function Test-PowerCandidateApplied {
    foreach ($alias in $script:PowerTargets.Keys) {
        if ((Get-PowerAcValue -SchemeGuid $script:HighPerformanceScheme -SettingAlias $alias) -ne [int]$script:PowerTargets[$alias]) {
            return $false
        }
    }
    $active = Get-PowerSchemeGuid -Output (Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/getactivescheme')).Output
    return ($active -eq $script:HighPerformanceScheme)
}

function Apply-PowerCandidate {
    foreach ($alias in $script:PowerTargets.Keys) {
        [void](Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('-attributes', 'SUB_PROCESSOR', $alias, '-ATTRIB_HIDE'))
        [void](Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/setacvalueindex', $script:HighPerformanceScheme, 'SUB_PROCESSOR', $alias, [string]$script:PowerTargets[$alias]))
    }
    [void](Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/setactive', $script:HighPerformanceScheme))
}

function Restore-PowerCandidate {
    param([object]$Original)

    foreach ($alias in $script:PowerTargets.Keys) {
        [void](Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/setacvalueindex', $Original.targetSchemeGuid, 'SUB_PROCESSOR', $alias, [string]$Original.acValues.$alias))
        Set-RegistryValueFromState -State $Original.attributeStates.$alias
    }
    [void](Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/setactive', $Original.activeSchemeGuid))
}

function Get-NtfsLastAccessState {
    $result = Invoke-NativeCommand -FilePath 'fsutil.exe' -Arguments @('behavior', 'query', 'disablelastaccess')
    $match = [regex]::Match($result.Output, 'DisableLastAccess\s*=\s*([0-3])')
    if (-not $match.Success) { throw "Could not parse the NTFS last-access state: $($result.Output)" }
    return [pscustomobject][ordered]@{ value = [int]$match.Groups[1].Value; raw = $result.Output }
}

function Set-NtfsLastAccessState {
    param([int]$Value)
    [void](Invoke-NativeCommand -FilePath 'fsutil.exe' -Arguments @('behavior', 'set', 'disablelastaccess', [string]$Value))
}

function Initialize-SystemParametersInfo {
    if ('ZBookPerf.NativeMethods' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ZBookPerf {
    public static class NativeMethods {
        [DllImport("user32.dll", EntryPoint = "SystemParametersInfo", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SystemParametersInfoGet(uint action, uint parameter, ref bool value, uint flags);

        [DllImport("user32.dll", EntryPoint = "SystemParametersInfo", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool SystemParametersInfoSet(uint action, uint parameter, IntPtr value, uint flags);
    }
}
'@
}

function Get-VisualEffectsState {
    Initialize-SystemParametersInfo
    $settings = [ordered]@{
        UIEffects = @{ Get = 0x103E; Set = 0x103F }
        ClientAreaAnimation = @{ Get = 0x1042; Set = 0x1043 }
        MenuAnimation = @{ Get = 0x1002; Set = 0x1003 }
        TooltipAnimation = @{ Get = 0x1016; Set = 0x1017 }
        SelectionFade = @{ Get = 0x1014; Set = 0x1015 }
        ComboBoxAnimation = @{ Get = 0x1004; Set = 0x1005 }
        ListBoxSmoothScrolling = @{ Get = 0x1006; Set = 0x1007 }
    }
    $values = [ordered]@{}
    foreach ($name in $settings.Keys) {
        $value = $false
        if (-not [ZBookPerf.NativeMethods]::SystemParametersInfoGet([uint32]$settings[$name].Get, 0, [ref]$value, 0)) {
            throw "SystemParametersInfo could not read $name. Win32 error: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
        $values[$name] = $value
    }
    return [pscustomobject][ordered]@{ values = [pscustomobject]$values }
}

function Set-VisualEffectsState {
    param([object]$Values)
    Initialize-SystemParametersInfo
    $setActions = [ordered]@{
        UIEffects = 0x103F
        ClientAreaAnimation = 0x1043
        MenuAnimation = 0x1003
        TooltipAnimation = 0x1017
        SelectionFade = 0x1015
        ComboBoxAnimation = 0x1005
        ListBoxSmoothScrolling = 0x1007
    }
    foreach ($name in $setActions.Keys) {
        $value = if ([bool]$Values.$name) { 1 } else { 0 }
        if (-not [ZBookPerf.NativeMethods]::SystemParametersInfoSet([uint32]$setActions[$name], [uint32]$value, [IntPtr]::Zero, 0x03)) {
            throw "SystemParametersInfo could not set $name. Win32 error: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
    }
}

function Initialize-Layer10NativeMethods {
    if ('ZBookPerf.Layer10NativeMethods' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ZBookPerf {
    [StructLayout(LayoutKind.Sequential)]
    public struct SystemPowerStatus {
        public byte ACLineStatus;
        public byte BatteryFlag;
        public byte BatteryLifePercent;
        public byte SystemStatusFlag;
        public UInt32 BatteryLifeTime;
        public UInt32 BatteryFullLifeTime;
    }

    public static class Layer10NativeMethods {
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetSystemPowerStatus(out SystemPowerStatus status);
    }
}
'@
}

function Get-SystemPowerStatusState {
    Initialize-Layer10NativeMethods
    $status = New-Object ZBookPerf.SystemPowerStatus
    if (-not [ZBookPerf.Layer10NativeMethods]::GetSystemPowerStatus([ref]$status)) {
        return [pscustomobject][ordered]@{
            available = $false
            error = "GetSystemPowerStatus failed with Win32 error $([Runtime.InteropServices.Marshal]::GetLastWin32Error())."
        }
    }

    $acLineStatus = switch ([int]$status.ACLineStatus) {
        0 { 'Offline' }
        1 { 'Online' }
        default { 'Unknown' }
    }
    return [pscustomobject][ordered]@{
        available = $true
        acLineStatus = $acLineStatus
        batteryFlag = [int]$status.BatteryFlag
        batteryLifePercent = if ($status.BatteryLifePercent -eq 255) { $null } else { [int]$status.BatteryLifePercent }
        batterySaverOn = ([int]$status.SystemStatusFlag -eq 1)
    }
}

function Get-UiSettingsState {
    try {
        $null = [Windows.UI.ViewManagement.UISettings, Windows.UI.ViewManagement, ContentType = WindowsRuntime]
        $settings = New-Object Windows.UI.ViewManagement.UISettings
        return [pscustomobject][ordered]@{
            available = $true
            source = 'Windows.UI.ViewManagement.UISettings'
            animationsEnabled = [bool]$settings.AnimationsEnabled
            transparencyEffectsEnabled = [bool]$settings.AdvancedEffectsEnabled
            messageDurationSeconds = [uint32]$settings.MessageDuration
        }
    } catch {
        return [pscustomobject][ordered]@{
            available = $false
            source = 'Windows.UI.ViewManagement.UISettings'
            errorType = $_.Exception.GetType().FullName
        }
    }
}

function Get-ManagementJoinContext {
    $context = [ordered]@{
        dsregcmdAvailable = $false
        azureAdJoined = $null
        domainJoined = $null
        workplaceJoined = $null
        mdmEnrollmentUrlPresent = $null
    }
    if (-not (Get-Command 'dsregcmd.exe' -ErrorAction SilentlyContinue)) {
        return [pscustomobject]$context
    }

    $context.dsregcmdAvailable = $true
    $result = Invoke-NativeCommand -FilePath 'dsregcmd.exe' -Arguments @('/status') -AllowFailure
    if ($result.ExitCode -ne 0) { return [pscustomobject]$context }

    foreach ($mapping in @(
        @{ Name = 'azureAdJoined'; Pattern = '(?m)^\s*AzureAdJoined\s*:\s*(YES|NO)\s*$' },
        @{ Name = 'domainJoined'; Pattern = '(?m)^\s*DomainJoined\s*:\s*(YES|NO)\s*$' },
        @{ Name = 'workplaceJoined'; Pattern = '(?m)^\s*WorkplaceJoined\s*:\s*(YES|NO)\s*$' }
    )) {
        $match = [regex]::Match($result.Output, $mapping.Pattern)
        if ($match.Success) { $context[$mapping.Name] = ($match.Groups[1].Value -eq 'YES') }
    }
    $mdmMatch = [regex]::Match($result.Output, '(?m)^\s*MdmUrl\s*:\s*(.*?)\s*$')
    if ($mdmMatch.Success) {
        $context.mdmEnrollmentUrlPresent = -not [string]::IsNullOrWhiteSpace($mdmMatch.Groups[1].Value)
    }
    return [pscustomobject]$context
}

function Get-RsopPolicyOrigin {
    param(
        [Parameter(Mandatory = $true)][string]$RegistryKey,
        [Parameter(Mandatory = $true)][string]$ValueName
    )

    try {
        $settings = @(Get-CimInstance -Namespace 'root/rsop/computer' -ClassName RSOP_RegistryPolicySetting -ErrorAction Stop)
        $normalizedKey = $RegistryKey.TrimStart('\')
        $matches = @($settings | Where-Object {
            ([string]$_.KeyName).TrimStart('\') -ieq $normalizedKey -and
            [string]$_.ValueName -ieq $ValueName
        })
        return [pscustomobject][ordered]@{
            available = $true
            groupPolicyMatchCount = $matches.Count
        }
    } catch {
        return [pscustomobject][ordered]@{
            available = $false
            groupPolicyMatchCount = 0
            errorType = $_.Exception.GetType().FullName
        }
    }
}

function Get-DocumentedPolicyState {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$RegistryPath,
        [Parameter(Mandatory = $true)][string]$RegistryKey,
        [Parameter(Mandatory = $true)][string]$ValueName,
        [Parameter(Mandatory = $true)][int]$DocumentedDefault,
        [Parameter(Mandatory = $true)][string]$PolicyCsp
    )

    $state = Get-RegistryValueState -Path $RegistryPath -Name $ValueName
    $rsop = Get-RsopPolicyOrigin -RegistryKey $RegistryKey -ValueName $ValueName
    $origin = if (-not $state.Exists) {
        'NotConfiguredAtDocumentedPolicyPath'
    } elseif ($rsop.available -and $rsop.groupPolicyMatchCount -gt 0) {
        'GroupPolicy'
    } else {
        'ConfiguredAtDocumentedPolicyPath;DeliveryAuthorityUnresolved'
    }

    return [pscustomobject][ordered]@{
        name = $Name
        scope = 'Device'
        policyCsp = $PolicyCsp
        documentedDefault = $DocumentedDefault
        configured = [bool]$state.Exists
        configuredValue = if ($state.Exists) { $state.Value } else { $null }
        registryKind = if ($state.Exists) { $state.Kind } else { $null }
        managementOrigin = $origin
        deliveryAuthorityResolved = ($origin -in @('GroupPolicy', 'NotConfiguredAtDocumentedPolicyPath'))
        rsopAvailable = [bool]$rsop.available
        mutationEligible = $false
        note = 'Inventory only. A configured policy is never changed by ShellProfile.'
    }
}

function Get-AppPackageInventory {
    param([Parameter(Mandatory = $true)][string[]]$Names)

    if (-not (Get-Command 'Get-AppxPackage' -ErrorAction SilentlyContinue)) {
        return [pscustomobject][ordered]@{
            available = $false
            packages = @()
        }
    }

    $packages = @()
    foreach ($name in $Names) {
        try {
            $items = @(Get-AppxPackage -Name $name -ErrorAction Stop)
            if ($items.Count -eq 0) {
                $packages += [pscustomobject][ordered]@{ name = $name; installed = $false; version = $null; status = $null }
            } else {
                foreach ($item in $items) {
                    $packages += [pscustomobject][ordered]@{
                        name = $name
                        installed = $true
                        version = [string]$item.Version
                        status = [string]$item.Status
                    }
                }
            }
        } catch {
            $packages += [pscustomobject][ordered]@{
                name = $name
                installed = $null
                version = $null
                status = 'QueryFailed'
                errorType = $_.Exception.GetType().FullName
            }
        }
    }
    return [pscustomobject][ordered]@{
        available = $true
        packages = @($packages)
    }
}

function Get-PerformanceToolInventory {
    $tools = @()
    foreach ($name in @('wpr.exe', 'wpa.exe', 'wpaexporter.exe')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        $version = $null
        if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source)) {
            $version = (Get-Item -LiteralPath $command.Source).VersionInfo.ProductVersion
        }
        $tools += [pscustomobject][ordered]@{
            name = $name
            available = [bool]$command
            productVersion = $version
        }
    }
    return @($tools)
}

function Get-ShellLayerInventory {
    $visualEffects = $null
    try {
        $visualEffects = Get-VisualEffectsState
    } catch {
        $visualEffects = [pscustomobject][ordered]@{
            available = $false
            errorType = $_.Exception.GetType().FullName
        }
    }

    return [pscustomobject][ordered]@{
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        uiSettings = Get-UiSettingsState
        visualEffects = $visualEffects
        managementContext = Get-ManagementJoinContext
        policies = @(
            Get-DocumentedPolicyState `
                -Name 'Widgets' `
                -RegistryPath 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' `
                -RegistryKey 'SOFTWARE\Policies\Microsoft\Dsh' `
                -ValueName 'AllowNewsAndInterests' `
                -DocumentedDefault 1 `
                -PolicyCsp './Device/Vendor/MSFT/Policy/Config/NewsAndInterests/AllowNewsAndInterests'
            Get-DocumentedPolicyState `
                -Name 'WindowsGameRecordingAndBroadcasting' `
                -RegistryPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' `
                -RegistryKey 'SOFTWARE\Policies\Microsoft\Windows\GameDVR' `
                -ValueName 'AllowGameDVR' `
                -DocumentedDefault 1 `
                -PolicyCsp './Device/Vendor/MSFT/Policy/Config/ApplicationManagement/AllowGameDVR'
        )
        packages = Get-AppPackageInventory -Names @('Microsoft.XboxGamingOverlay', 'MicrosoftWindows.Client.WebExperience')
        performanceTools = Get-PerformanceToolInventory
    }
}

function New-ShellApplication {
    return (New-Object -ComObject Shell.Application)
}

function Get-ShellWindowHandleSnapshot {
    param([Parameter(Mandatory = $true)][object]$ShellApplication)

    $items = @()
    $windows = $ShellApplication.Windows()
    for ($index = 0; $index -lt [int]$windows.Count; $index++) {
        $window = $null
        try {
            $window = $windows.Item($index)
            if ($null -eq $window) { continue }
            $items += [pscustomobject][ordered]@{
                hwnd = [int64]$window.HWND
                busy = [bool]$window.Busy
                readyState = [int]$window.ReadyState
                window = $window
            }
        } catch {
            continue
        }
    }
    return @($items)
}

function Get-NewReadyShellWindow {
    param(
        [Parameter(Mandatory = $true)][object]$ShellApplication,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][int64[]]$ExistingHandles,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $normalizedTarget = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
    $snapshot = @(Get-ShellWindowHandleSnapshot -ShellApplication $ShellApplication)
    return @($snapshot | Where-Object {
        if ($_.hwnd -in $ExistingHandles -or $_.busy -or $_.readyState -ne 4) { return $false }
        try {
            $windowPath = [Uri]::UnescapeDataString(([Uri]$_.window.LocationURL).LocalPath)
            return ([IO.Path]::GetFullPath($windowPath).TrimEnd('\') -ieq $normalizedTarget)
        } catch {
            return $false
        }
    } | Select-Object -First 1)
}

function Get-Percentile {
    param(
        [Parameter(Mandatory = $true)][double[]]$Values,
        [ValidateRange(0, 100)][double]$Percentile
    )

    $items = @($Values | Sort-Object)
    if ($items.Count -eq 0) { return 0.0 }
    $index = [int][Math]::Ceiling(($Percentile / 100) * $items.Count) - 1
    $index = [Math]::Max(0, [Math]::Min($index, $items.Count - 1))
    return [double]$items[$index]
}

function Measure-ShellProbeOverhead {
    param(
        [Parameter(Mandatory = $true)][object]$ShellApplication,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [ValidateRange(5, 100)][int]$Iterations
    )

    # Warm the complete readiness probe before timing so one-time COM
    # activation does not inflate every run's observer-cost estimate.
    [void](Get-NewReadyShellWindow `
        -ShellApplication $ShellApplication `
        -ExistingHandles @() `
        -TargetPath $TargetPath)
    $samples = @()
    for ($index = 0; $index -lt $Iterations; $index++) {
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [void](Get-NewReadyShellWindow `
            -ShellApplication $ShellApplication `
            -ExistingHandles @() `
            -TargetPath $TargetPath)
        $stopwatch.Stop()
        $samples += $stopwatch.Elapsed.TotalMilliseconds
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        medianMilliseconds = [Math]::Round((Get-Median -Values $samples), 3)
        p95Milliseconds = [Math]::Round((Get-Percentile -Values $samples -Percentile 95), 3)
        samplesMilliseconds = @($samples | ForEach-Object { [Math]::Round($_, 3) })
    }
}

function Close-NewShellWindows {
    param(
        [Parameter(Mandatory = $true)][object]$ShellApplication,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][int64[]]$ExistingHandles,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    $normalizedTarget = [IO.Path]::GetFullPath($TargetPath).TrimEnd('\')
    foreach ($item in @(Get-ShellWindowHandleSnapshot -ShellApplication $ShellApplication)) {
        if ($item.hwnd -in $ExistingHandles) { continue }
        try {
            $windowPath = [Uri]::UnescapeDataString(([Uri]$item.window.LocationURL).LocalPath)
            if ([IO.Path]::GetFullPath($windowPath).TrimEnd('\') -ieq $normalizedTarget) {
                $item.window.Quit()
            }
        } catch { }
    }
}

function Invoke-ExplorerReadinessRun {
    param(
        [Parameter(Mandatory = $true)][object]$ShellApplication,
        [ValidateRange(1000, 30000)][int]$TimeoutMilliseconds,
        [Parameter(Mandatory = $true)][double]$ProbeP95Milliseconds,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [int]$RunNumber,
        [switch]$Warmup
    )

    $before = @(Get-ShellWindowHandleSnapshot -ShellApplication $ShellApplication)
    $beforeHandles = @($before | ForEach-Object { [int64]$_.hwnd })
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $probeCount = 0
    $status = 'TimedOut'
    try {
        $ShellApplication.Explore($TargetPath)
        while ($stopwatch.Elapsed.TotalMilliseconds -lt $TimeoutMilliseconds) {
            $probeCount++
            $ready = @(Get-NewReadyShellWindow `
                -ShellApplication $ShellApplication `
                -ExistingHandles $beforeHandles `
                -TargetPath $TargetPath)
            if ($ready.Count -gt 0) {
                $status = 'Ready'
                break
            }
            Start-Sleep -Milliseconds 25
        }
    } catch {
        $status = 'LaunchFailed'
    } finally {
        $stopwatch.Stop()
        Close-NewShellWindows `
            -ShellApplication $ShellApplication `
            -ExistingHandles $beforeHandles `
            -TargetPath $TargetPath
    }

    $raw = [Math]::Round($stopwatch.Elapsed.TotalMilliseconds, 3)
    $overheadBound = [Math]::Round(($probeCount * $ProbeP95Milliseconds), 3)
    return [pscustomobject][ordered]@{
        run = $RunNumber
        warmup = [bool]$Warmup
        status = $status
        rawMilliseconds = $raw
        probeCount = $probeCount
        estimatedProbeOverheadP95BudgetMilliseconds = $overheadBound
        readinessMinusEstimatedObserverBudgetMilliseconds = [Math]::Round([Math]::Max(0, $raw - $overheadBound), 3)
    }
}

function Get-ShellReadinessSummary {
    param([Parameter(Mandatory = $true)][object[]]$Runs)

    $measured = @($Runs | Where-Object { -not $_.warmup })
    $successful = @($measured | Where-Object { $_.status -eq 'Ready' })
    $values = @($successful | ForEach-Object { [double]$_.rawMilliseconds })
    $median = if ($values.Count -gt 0) { Get-Median -Values $values } else { 0.0 }
    $deviations = @($values | ForEach-Object { [Math]::Abs($_ - $median) })
    return [pscustomobject][ordered]@{
        requestedRunCount = $measured.Count
        successfulRunCount = $successful.Count
        failedRunCount = $measured.Count - $successful.Count
        medianMilliseconds = [Math]::Round($median, 3)
        medianAbsoluteDeviationMilliseconds = if ($deviations.Count -gt 0) {
            [Math]::Round((Get-Median -Values $deviations), 3)
        } else { 0.0 }
        minimumMilliseconds = if ($values.Count -gt 0) { [Math]::Round(($values | Measure-Object -Minimum).Minimum, 3) } else { $null }
        maximumMilliseconds = if ($values.Count -gt 0) { [Math]::Round(($values | Measure-Object -Maximum).Maximum, 3) } else { $null }
        decision = 'BaselineOnlyNoPerformanceClaim'
    }
}

function Invoke-ShellProfile {
    param(
        [string]$Root,
        [ValidateRange(1, 25)][int]$RunCount,
        [ValidateRange(0, 5)][int]$WarmupRunCount,
        [ValidateRange(1000, 30000)][int]$TimeoutMilliseconds,
        [ValidateRange(5, 100)][int]$ProbeCalibrationIterations
    )

    if (-not [Environment]::UserInteractive) {
        throw 'ShellProfile requires an interactive Windows user session. No setting was changed.'
    }
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        throw 'ShellProfile requires the Windows Explorer shell to be running. No setting was changed.'
    }

    Ensure-DataDirectories -Root $Root
    $benchmarkTarget = Join-Path $Root 'shell-profile-target'
    if (-not (Test-Path -LiteralPath $benchmarkTarget)) {
        New-Item -ItemType Directory -Path $benchmarkTarget -Force | Out-Null
    }
    $shellApplication = New-ShellApplication
    $probe = Measure-ShellProbeOverhead `
        -ShellApplication $shellApplication `
        -TargetPath $benchmarkTarget `
        -Iterations $ProbeCalibrationIterations
    $runs = @()
    $total = $WarmupRunCount + $RunCount
    for ($index = 1; $index -le $total; $index++) {
        $isWarmup = $index -le $WarmupRunCount
        $runNumber = if ($isWarmup) { $index } else { $index - $WarmupRunCount }
        $runs += Invoke-ExplorerReadinessRun `
            -ShellApplication $shellApplication `
            -TimeoutMilliseconds $TimeoutMilliseconds `
            -ProbeP95Milliseconds $probe.p95Milliseconds `
            -TargetPath $benchmarkTarget `
            -RunNumber $runNumber `
            -Warmup:$isWarmup
        Start-Sleep -Milliseconds 250
    }

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-shell-profile.json"
    $profile = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        layer = 10
        kind = 'shell-profile'
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        environment = Get-WindowsEnvironment
        inventory = Get-ShellLayerInventory
        benchmark = [pscustomobject][ordered]@{
            workflow = 'Shell.Explore to the private benchmark folder, then wait for its new IShellWindows item to report Busy=false and ReadyState=Complete.'
            reset = 'Close only a new window whose LocationURL matches the private benchmark folder.'
            timeoutMilliseconds = $TimeoutMilliseconds
            pollIntervalMilliseconds = 25
            warmupRunCount = $WarmupRunCount
            probeOverhead = $probe
            runs = @($runs)
            summary = Get-ShellReadinessSummary -Runs @($runs)
            qualification = 'The complete readiness-probe cost is measured before the runs. Raw duration and an estimated p95-per-probe observer budget are retained; results are not overhead-corrected and no gain is inferred from this baseline.'
        }
        evidencePath = $evidencePath
    }
    $profile | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-StructuredEvent -Root $Root -Level Information -Event 'shell-profile-complete' -Data @{
        evidencePath = $evidencePath
        runCount = $RunCount
        successfulRunCount = $profile.benchmark.summary.successfulRunCount
        observationOnly = $true
    }

    Write-Host ''
    Write-Host 'Layer 10 shell profile (observation only)' -ForegroundColor Cyan
    Write-Host "Animations enabled: $($profile.inventory.uiSettings.animationsEnabled)"
    Write-Host "Transparency effects enabled: $($profile.inventory.uiSettings.transparencyEffectsEnabled)"
    Write-Host "Notification duration (seconds): $($profile.inventory.uiSettings.messageDurationSeconds)"
    Write-Host "Explorer readiness median (ms): $($profile.benchmark.summary.medianMilliseconds)"
    Write-Host "Median absolute deviation (ms): $($profile.benchmark.summary.medianAbsoluteDeviationMilliseconds)"
    Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
    Write-Host 'No Windows setting was changed and no performance-gain claim was made.' -ForegroundColor DarkYellow
    return $profile
}

function Resolve-WorkloadProcessNames {
    param([Parameter(Mandatory = $true)][string[]]$Names)

    $resolved = @()
    foreach ($name in $Names) {
        $candidate = ([string]$name).Trim()
        if ($candidate -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$') {
            throw "Invalid workload process name '$candidate'. Use an executable name, not a path, wildcard, or command line."
        }
        if (-not [IO.Path]::GetExtension($candidate)) {
            $candidate = "$candidate.exe"
        }
        $resolved += $candidate.ToLowerInvariant()
    }
    return @($resolved | Sort-Object -Unique)
}

function Initialize-WorkloadNativeMethods {
    if ('ZBookPerf.WorkloadNativeMethods' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ZBookPerf {
    [StructLayout(LayoutKind.Sequential)]
    public struct ProcessIoCounters {
        public UInt64 ReadOperationCount;
        public UInt64 WriteOperationCount;
        public UInt64 OtherOperationCount;
        public UInt64 ReadTransferCount;
        public UInt64 WriteTransferCount;
        public UInt64 OtherTransferCount;
    }

    public static class WorkloadNativeMethods {
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetProcessIoCounters(
            IntPtr processHandle,
            out ProcessIoCounters counters
        );
    }
}
'@
}

function Get-WorkloadProcessSnapshot {
    param([Parameter(Mandatory = $true)][string[]]$ProcessNames)

    Initialize-WorkloadNativeMethods
    $queryTimer = [Diagnostics.Stopwatch]::StartNew()
    $rows = @()
    $errors = @()
    foreach ($name in $ProcessNames) {
        $processBaseName = [IO.Path]::GetFileNameWithoutExtension($name)
        foreach ($process in @([Diagnostics.Process]::GetProcessesByName($processBaseName))) {
            try {
                $process.Refresh()
                $creationUtc = $process.StartTime.ToUniversalTime().ToString('o')
                $identity = "$([uint32]$process.Id)|$creationUtc"
                $io = New-Object ZBookPerf.ProcessIoCounters
                $ioAvailable = $false
                $ioErrorType = $null
                $ioWin32Error = $null
                try {
                    $ioAvailable = [ZBookPerf.WorkloadNativeMethods]::GetProcessIoCounters(
                        $process.Handle,
                        [ref]$io
                    )
                    if (-not $ioAvailable) {
                        $ioWin32Error = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    }
                } catch {
                    $ioErrorType = $_.Exception.GetType().FullName
                }
                $rows += [pscustomobject][ordered]@{
                    name = $name
                    processId = [uint32]$process.Id
                    creationUtc = $creationUtc
                    identity = $identity
                    kernelModeTime100ns = [uint64]$process.PrivilegedProcessorTime.Ticks
                    userModeTime100ns = [uint64]$process.UserProcessorTime.Ticks
                    ioCountersAvailable = [bool]$ioAvailable
                    ioCounterErrorType = $ioErrorType
                    ioCounterWin32Error = $ioWin32Error
                    readTransferBytes = if ($ioAvailable) { [uint64]$io.ReadTransferCount } else { $null }
                    writeTransferBytes = if ($ioAvailable) { [uint64]$io.WriteTransferCount } else { $null }
                    workingSetBytes = [uint64]$process.WorkingSet64
                    privateMemoryBytes = [uint64]$process.PrivateMemorySize64
                    handleCount = [uint32]$process.HandleCount
                    threadCount = [uint32]$process.Threads.Count
                }
            } catch {
                $errors += [pscustomobject][ordered]@{
                    name = $name
                    processId = [uint32]$process.Id
                    errorType = $_.Exception.GetType().FullName
                }
            } finally {
                $process.Dispose()
            }
        }
    }
    $queryTimer.Stop()

    return [pscustomobject][ordered]@{
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        monotonicTicks = [Diagnostics.Stopwatch]::GetTimestamp()
        queryDurationMilliseconds = [Math]::Round($queryTimer.Elapsed.TotalMilliseconds, 3)
        processes = @($rows)
        errors = @($errors)
    }
}

function Measure-WorkloadSnapshotOverhead {
    param(
        [Parameter(Mandatory = $true)][string[]]$ProcessNames,
        [ValidateRange(3, 25)][int]$Iterations
    )

    [void](Get-WorkloadProcessSnapshot -ProcessNames $ProcessNames)
    $samples = @()
    for ($index = 0; $index -lt $Iterations; $index++) {
        $snapshot = Get-WorkloadProcessSnapshot -ProcessNames $ProcessNames
        $samples += [double]$snapshot.queryDurationMilliseconds
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        medianMilliseconds = [Math]::Round((Get-Median -Values $samples), 3)
        p95Milliseconds = [Math]::Round((Get-Percentile -Values $samples -Percentile 95), 3)
        samplesMilliseconds = @($samples)
    }
}

function Get-NonnegativeCounterDelta {
    param(
        [Parameter(Mandatory = $true)][double]$Before,
        [Parameter(Mandatory = $true)][double]$After
    )

    if ($After -lt $Before) { return $null }
    return ($After - $Before)
}

function Get-NumericPropertySum {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    if ($Rows.Count -eq 0) { return 0.0 }
    return [double](($Rows | Measure-Object -Property $PropertyName -Sum).Sum)
}

function ConvertTo-WorkloadInterval {
    param(
        [Parameter(Mandatory = $true)][object]$Previous,
        [Parameter(Mandatory = $true)][object]$Current,
        [ValidateRange(1, 1024)][int]$LogicalProcessorCount
    )

    $elapsedSeconds = ([double]$Current.monotonicTicks - [double]$Previous.monotonicTicks) /
        [double][Diagnostics.Stopwatch]::Frequency
    if ($elapsedSeconds -le 0) {
        throw 'The workload snapshots do not have a positive monotonic interval.'
    }

    $previousByIdentity = @{}
    foreach ($row in @($Previous.processes)) {
        if ($row.identity) { $previousByIdentity[[string]$row.identity] = $row }
    }
    $currentByIdentity = @{}
    foreach ($row in @($Current.processes)) {
        if ($row.identity) { $currentByIdentity[[string]$row.identity] = $row }
    }

    $stableRows = @()
    foreach ($identity in $currentByIdentity.Keys) {
        if (-not $previousByIdentity.ContainsKey($identity)) { continue }
        $before = $previousByIdentity[$identity]
        $after = $currentByIdentity[$identity]
        $cpuBefore = [double]$before.kernelModeTime100ns + [double]$before.userModeTime100ns
        $cpuAfter = [double]$after.kernelModeTime100ns + [double]$after.userModeTime100ns
        $cpuDelta = Get-NonnegativeCounterDelta -Before $cpuBefore -After $cpuAfter
        if ($null -eq $cpuDelta) { continue }

        $ioAvailable = [bool]$before.ioCountersAvailable -and [bool]$after.ioCountersAvailable
        $readDelta = if ($ioAvailable) {
            Get-NonnegativeCounterDelta `
                -Before ([double]$before.readTransferBytes) `
                -After ([double]$after.readTransferBytes)
        } else { $null }
        $writeDelta = if ($ioAvailable) {
            Get-NonnegativeCounterDelta `
                -Before ([double]$before.writeTransferBytes) `
                -After ([double]$after.writeTransferBytes)
        } else { $null }
        if ($null -eq $readDelta -or $null -eq $writeDelta) { $ioAvailable = $false }

        $logicalCpuPercent = (($cpuDelta * 0.0000001) / $elapsedSeconds) * 100
        $stableRows += [pscustomobject][ordered]@{
            name = $after.name
            processId = $after.processId
            creationUtc = $after.creationUtc
            cpuLogicalProcessorPercent = [Math]::Round($logicalCpuPercent, 4)
            cpuMachinePercent = [Math]::Round(($logicalCpuPercent / $LogicalProcessorCount), 4)
            ioCountersAvailable = $ioAvailable
            readBytesPerSecond = if ($ioAvailable) { [Math]::Round(($readDelta / $elapsedSeconds), 0) } else { $null }
            writeBytesPerSecond = if ($ioAvailable) { [Math]::Round(($writeDelta / $elapsedSeconds), 0) } else { $null }
            workingSetBytes = $after.workingSetBytes
            privateMemoryBytes = $after.privateMemoryBytes
            handleCount = $after.handleCount
            threadCount = $after.threadCount
        }
    }

    $currentRows = @($Current.processes)
    $ioRows = @($stableRows | Where-Object { $_.ioCountersAvailable })
    $started = @($currentByIdentity.Keys | Where-Object { -not $previousByIdentity.ContainsKey($_) }).Count
    $exited = @($previousByIdentity.Keys | Where-Object { -not $currentByIdentity.ContainsKey($_) }).Count
    return [pscustomobject][ordered]@{
        capturedUtc = $Current.capturedUtc
        elapsedMilliseconds = [Math]::Round(($elapsedSeconds * 1000), 3)
        queryDurationMilliseconds = $Current.queryDurationMilliseconds
        status = if ($stableRows.Count -gt 0) { 'Measured' } else { 'NoStableProcessPair' }
        observedProcessCount = $currentRows.Count
        stableProcessCount = $stableRows.Count
        ioMeasuredProcessCount = $ioRows.Count
        startedProcessCount = $started
        exitedProcessCount = $exited
        cpuLogicalProcessorPercent = [Math]::Round((Get-NumericPropertySum -Rows $stableRows -PropertyName cpuLogicalProcessorPercent), 4)
        cpuMachinePercent = [Math]::Round((Get-NumericPropertySum -Rows $stableRows -PropertyName cpuMachinePercent), 4)
        readBytesPerSecond = if ($ioRows.Count -gt 0) {
            [Math]::Round((Get-NumericPropertySum -Rows $ioRows -PropertyName readBytesPerSecond), 0)
        } else { $null }
        writeBytesPerSecond = if ($ioRows.Count -gt 0) {
            [Math]::Round((Get-NumericPropertySum -Rows $ioRows -PropertyName writeBytesPerSecond), 0)
        } else { $null }
        workingSetBytes = [uint64](Get-NumericPropertySum -Rows $currentRows -PropertyName workingSetBytes)
        privateMemoryBytes = [uint64](Get-NumericPropertySum -Rows $currentRows -PropertyName privateMemoryBytes)
        handleCount = [uint64](Get-NumericPropertySum -Rows $currentRows -PropertyName handleCount)
        threadCount = [uint64](Get-NumericPropertySum -Rows $currentRows -PropertyName threadCount)
        processes = @($stableRows)
        queryErrors = @($Current.errors)
    }
}

function Get-WorkloadDistribution {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [double[]]$Values
    )

    if ($Values.Count -eq 0) {
        return [pscustomobject][ordered]@{
            count = 0
            median = $null
            p95 = $null
            minimum = $null
            maximum = $null
        }
    }
    return [pscustomobject][ordered]@{
        count = $Values.Count
        median = [Math]::Round((Get-Median -Values $Values), 4)
        p95 = [Math]::Round((Get-Percentile -Values $Values -Percentile 95), 4)
        minimum = [Math]::Round(($Values | Measure-Object -Minimum).Minimum, 4)
        maximum = [Math]::Round(($Values | Measure-Object -Maximum).Maximum, 4)
    }
}

function Get-WorkloadProfileSummary {
    param([Parameter(Mandatory = $true)][object[]]$Intervals)

    $measured = @($Intervals | Where-Object { $_.status -eq 'Measured' })
    $metricNames = @(
        'cpuLogicalProcessorPercent',
        'cpuMachinePercent',
        'readBytesPerSecond',
        'writeBytesPerSecond',
        'workingSetBytes',
        'privateMemoryBytes',
        'handleCount',
        'threadCount',
        'queryDurationMilliseconds'
    )
    $metrics = [ordered]@{}
    foreach ($metric in $metricNames) {
        $values = @($measured | ForEach-Object {
            if ($null -ne $_.$metric) { [double]$_.$metric }
        })
        $metrics[$metric] = Get-WorkloadDistribution -Values $values
    }

    return [pscustomobject][ordered]@{
        requestedIntervalCount = $Intervals.Count
        measuredIntervalCount = $measured.Count
        unmeasuredIntervalCount = $Intervals.Count - $measured.Count
        maximumObservedProcessCount = if ($Intervals.Count -gt 0) {
            [int]($Intervals | Measure-Object observedProcessCount -Maximum).Maximum
        } else { 0 }
        totalStartedProcessCount = [int](@($Intervals | Measure-Object startedProcessCount -Sum).Sum)
        totalExitedProcessCount = [int](@($Intervals | Measure-Object exitedProcessCount -Sum).Sum)
        metrics = [pscustomobject]$metrics
        decision = if ($measured.Count -gt 0) {
            'BaselineOnlyNoPerformanceClaim'
        } else {
            'NoStableTargetProcessObserved'
        }
    }
}

function Invoke-WorkloadProfile {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][string[]]$ProcessNames,
        [ValidateRange(5, 3600)][int]$Seconds,
        [ValidateRange(250, 5000)][int]$IntervalMilliseconds,
        [ValidateRange(3, 25)][int]$CalibrationIterations
    )

    $targets = @(Resolve-WorkloadProcessNames -Names $ProcessNames)
    Ensure-DataDirectories -Root $Root
    $environment = Get-WindowsEnvironment
    $logicalProcessors = [int]$environment.processor.logicalProcessors
    if ($logicalProcessors -lt 1) {
        throw 'A positive logical-processor count is required to normalize workload CPU use.'
    }

    $observer = Measure-WorkloadSnapshotOverhead `
        -ProcessNames $targets `
        -Iterations $CalibrationIterations
    $intervals = New-Object System.Collections.ArrayList
    $previous = Get-WorkloadProcessSnapshot -ProcessNames $targets
    $runTimer = [Diagnostics.Stopwatch]::StartNew()
    $sampleNumber = 1
    try {
        while ($runTimer.Elapsed.TotalSeconds -lt $Seconds) {
            $nextDueMilliseconds = [Math]::Min(
                ($sampleNumber * $IntervalMilliseconds),
                ($Seconds * 1000)
            )
            $remaining = $nextDueMilliseconds - $runTimer.Elapsed.TotalMilliseconds
            if ($remaining -gt 1) {
                Start-Sleep -Milliseconds ([int][Math]::Floor($remaining))
            }
            $current = Get-WorkloadProcessSnapshot -ProcessNames $targets
            [void]$intervals.Add((ConvertTo-WorkloadInterval `
                -Previous $previous `
                -Current $current `
                -LogicalProcessorCount $logicalProcessors))
            $previous = $current
            $sampleNumber++
        }
    } finally {
        $runTimer.Stop()
    }

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-workload-profile.json"
    $observerBudgetMilliseconds = [Math]::Round(
        ($observer.p95Milliseconds * ($intervals.Count + 1)),
        3
    )
    $profile = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        layer = 11
        kind = 'workload-profile'
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        targets = @($targets)
        requestedDurationSeconds = $Seconds
        actualDurationSeconds = [Math]::Round($runTimer.Elapsed.TotalSeconds, 3)
        requestedIntervalMilliseconds = $IntervalMilliseconds
        environment = $environment
        instrumentation = [pscustomobject][ordered]@{
            source = 'System.Diagnostics.Process snapshots plus GetProcessIoCounters'
            identity = 'ProcessId plus StartTime'
            timer = 'System.Diagnostics.Stopwatch monotonic timestamps'
            calibration = $observer
            estimatedTotalObserverP95BudgetMilliseconds = $observerBudgetMilliseconds
            estimatedObserverDutyCyclePercent = if ($runTimer.Elapsed.TotalMilliseconds -gt 0) {
                [Math]::Round(
                    (($observerBudgetMilliseconds / $runTimer.Elapsed.TotalMilliseconds) * 100),
                    3
                )
            } else { $null }
            qualification = 'Each filtered CIM snapshot has a measured observer cost. Raw interval and query durations are retained; metrics are not overhead-corrected.'
        }
        collectionScope = 'Exact executable names only. Command lines, executable paths, window titles, user content, and network endpoints are not collected. I/O metrics remain null when the process handle does not permit documented I/O-counter access.'
        intervals = @($intervals)
        summary = Get-WorkloadProfileSummary -Intervals @($intervals)
        evidencePath = $evidencePath
    }
    $profile | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    Write-StructuredEvent -Root $Root -Level Information -Event 'workload-profile-complete' -Data @{
        evidencePath = $evidencePath
        targets = @($targets)
        measuredIntervalCount = $profile.summary.measuredIntervalCount
        observationOnly = $true
    }

    Write-Host ''
    Write-Host 'Layer 11 workload runtime profile (observation only)' -ForegroundColor Cyan
    Write-Host "Targets: $($targets -join ', ')"
    Write-Host "Measured intervals: $($profile.summary.measuredIntervalCount) / $($profile.summary.requestedIntervalCount)"
    if ($profile.summary.measuredIntervalCount -gt 0) {
        Write-Host "Machine CPU median (%): $($profile.summary.metrics.cpuMachinePercent.median)"
        Write-Host "Read/write median (bytes/sec): $($profile.summary.metrics.readBytesPerSecond.median) / $($profile.summary.metrics.writeBytesPerSecond.median)"
        Write-Host "Working set median (bytes): $($profile.summary.metrics.workingSetBytes.median)"
    }
    Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
    Write-Host 'No process or Windows setting was changed and no performance-gain claim was made.' -ForegroundColor DarkYellow
    return $profile
}

function Get-RedactedDependencyHash {
    param([Parameter(Mandatory = $true)][string]$Value)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value.Trim().ToLowerInvariant())
        return -join @($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') })
    } finally {
        $sha.Dispose()
    }
}

function Test-PathWithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    try {
        $normalizedPath = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
        $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
        if ($normalizedPath.Equals($normalizedRoot, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
        return $normalizedPath.StartsWith(
            "$normalizedRoot\",
            [StringComparison]::OrdinalIgnoreCase
        )
    } catch {
        return $false
    }
}

function Get-DependencyPathObservation {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(0, 1000)][int]$InputIndex = 0
    )

    $candidate = $Path.Trim()
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        throw 'Dependency paths cannot be empty.'
    }
    try {
        $normalized = [IO.Path]::GetFullPath($candidate)
    } catch {
        throw "Invalid dependency path at index $InputIndex. Use a valid local, mapped-drive, or UNC path."
    }

    $identityHash = Get-RedactedDependencyHash -Value $normalized
    $isUnc = $normalized.StartsWith('\\', [StringComparison]::Ordinal)
    $root = [IO.Path]::GetPathRoot($normalized)
    $driveType = if ($isUnc) { 'Network' } else { 'Unknown' }
    $driveReady = $null
    $driveFormat = $null
    $availableFreeSpaceBytes = $null
    $totalSizeBytes = $null
    $exists = $null
    $existenceStatus = if ($isUnc) {
        'NotProbedToAvoidUnboundedNetworkPathAccess'
    } else {
        'NotChecked'
    }
    $attributesValue = $null
    $attributeErrorType = $null
    $driveErrorType = $null

    if (-not $isUnc) {
        try {
            $drive = New-Object IO.DriveInfo($root)
            $driveType = $drive.DriveType.ToString()
            if ($drive.DriveType -eq [IO.DriveType]::Network) {
                $existenceStatus = 'NotProbedToAvoidUnboundedNetworkPathAccess'
            } else {
                $driveReady = [bool]$drive.IsReady
                if ($driveReady) {
                    $driveFormat = $drive.DriveFormat
                    $availableFreeSpaceBytes = [uint64]$drive.AvailableFreeSpace
                    $totalSizeBytes = [uint64]$drive.TotalSize
                }
                $exists = [IO.File]::Exists($normalized) -or [IO.Directory]::Exists($normalized)
                $existenceStatus = if ($exists) { 'Exists' } else { 'NotFound' }
                if ($exists) {
                    try {
                        $attributesValue = [uint32][IO.File]::GetAttributes($normalized)
                    } catch {
                        $attributeErrorType = $_.Exception.GetType().FullName
                    }
                }
            }
        } catch {
            $driveErrorType = $_.Exception.GetType().FullName
            $existenceStatus = 'DriveQueryFailed'
        }
    }

    $knownSyncRootMatch = $false
    foreach ($variableName in @('OneDrive', 'OneDriveCommercial', 'OneDriveConsumer')) {
        $knownRoot = [Environment]::GetEnvironmentVariable($variableName)
        if (
            -not [string]::IsNullOrWhiteSpace($knownRoot) -and
            (Test-PathWithinRoot -Path $normalized -Root $knownRoot)
        ) {
            $knownSyncRootMatch = $true
            break
        }
    }

    return [pscustomobject][ordered]@{
        inputIndex = $InputIndex
        identitySha256 = $identityHash
        locality = if ($isUnc -or $driveType -eq 'Network') {
            'Network'
        } elseif ($knownSyncRootMatch) {
            'CloudSyncRoot'
        } else {
            'Local'
        }
        driveType = $driveType
        driveReady = $driveReady
        driveFormat = $driveFormat
        availableFreeSpaceBytes = $availableFreeSpaceBytes
        totalSizeBytes = $totalSizeBytes
        existenceStatus = $existenceStatus
        exists = $exists
        knownOneDriveRoot = $knownSyncRootMatch
        reparsePoint = if ($null -ne $attributesValue) {
            [bool]($attributesValue -band [uint32][IO.FileAttributes]::ReparsePoint)
        } else { $null }
        offline = if ($null -ne $attributesValue) {
            [bool]($attributesValue -band [uint32][IO.FileAttributes]::Offline)
        } else { $null }
        recallOnDataAccess = if ($null -ne $attributesValue) {
            [bool]($attributesValue -band [uint32]0x00400000)
        } else { $null }
        pinned = if ($null -ne $attributesValue) {
            [bool]($attributesValue -band [uint32]0x00080000)
        } else { $null }
        unpinned = if ($null -ne $attributesValue) {
            [bool]($attributesValue -band [uint32]0x00100000)
        } else { $null }
        attributeErrorType = $attributeErrorType
        driveErrorType = $driveErrorType
    }
}

function Resolve-DependencyEndpoint {
    param(
        [Parameter(Mandatory = $true)][string]$Endpoint,
        [ValidateRange(0, 1000)][int]$InputIndex = 0
    )

    $candidate = $Endpoint.Trim()
    $match = [regex]::Match(
        $candidate,
        '^(?<host>[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?):(?<port>[0-9]{1,5})$'
    )
    if (-not $match.Success) {
        throw "Invalid dependency endpoint at index $InputIndex. Use host:port with a DNS name or IPv4 address."
    }
    $port = [int]$match.Groups['port'].Value
    if ($port -lt 1 -or $port -gt 65535) {
        throw "Invalid dependency endpoint port at index $InputIndex. Use a port from 1 through 65535."
    }
    $hostName = $match.Groups['host'].Value.ToLowerInvariant()
    return [pscustomobject][ordered]@{
        inputIndex = $InputIndex
        host = $hostName
        port = $port
        identitySha256 = Get-RedactedDependencyHash -Value "$hostName`:$port"
    }
}

function Invoke-DependencyEndpointProbe {
    param(
        [Parameter(Mandatory = $true)][object]$Endpoint,
        [ValidateRange(100, 10000)][int]$TimeoutMilliseconds,
        [ValidateRange(1, 10)][int]$ProbeRun
    )

    $client = New-Object Net.Sockets.TcpClient
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $asyncResult = $null
    $status = 'Failed'
    $errorType = $null
    try {
        $asyncResult = $client.BeginConnect(
            [string]$Endpoint.host,
            [int]$Endpoint.port,
            $null,
            $null
        )
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            $status = 'Timeout'
        } else {
            $client.EndConnect($asyncResult)
            $status = if ($client.Connected) { 'Ready' } else { 'Failed' }
        }
    } catch {
        $status = 'Failed'
        $errorType = $_.Exception.GetType().FullName
    } finally {
        $timer.Stop()
        if ($asyncResult -and $asyncResult.AsyncWaitHandle) {
            $asyncResult.AsyncWaitHandle.Close()
        }
        $client.Close()
    }

    return [pscustomobject][ordered]@{
        inputIndex = [int]$Endpoint.inputIndex
        identitySha256 = [string]$Endpoint.identitySha256
        port = [int]$Endpoint.port
        probeRun = $ProbeRun
        status = $status
        durationMilliseconds = [Math]::Round($timer.Elapsed.TotalMilliseconds, 3)
        timeoutMilliseconds = $TimeoutMilliseconds
        errorType = $errorType
    }
}

function Measure-DependencyInventoryOverhead {
    param(
        [Parameter(Mandatory = $true)][string[]]$Paths,
        [ValidateRange(3, 25)][int]$Iterations
    )

    for ($pathIndex = 0; $pathIndex -lt $Paths.Count; $pathIndex++) {
        [void](Get-DependencyPathObservation -Path $Paths[$pathIndex] -InputIndex $pathIndex)
    }
    $samples = @()
    for ($iteration = 0; $iteration -lt $Iterations; $iteration++) {
        $timer = [Diagnostics.Stopwatch]::StartNew()
        for ($pathIndex = 0; $pathIndex -lt $Paths.Count; $pathIndex++) {
            [void](Get-DependencyPathObservation -Path $Paths[$pathIndex] -InputIndex $pathIndex)
        }
        $timer.Stop()
        $samples += [Math]::Round($timer.Elapsed.TotalMilliseconds, 3)
    }
    return [pscustomobject][ordered]@{
        iterations = $Iterations
        medianMilliseconds = [Math]::Round((Get-Median -Values $samples), 3)
        p95Milliseconds = [Math]::Round((Get-Percentile -Values $samples -Percentile 95), 3)
        samplesMilliseconds = @($samples)
    }
}

function Get-DependencyProfileSummary {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Paths,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$EndpointProbes
    )

    $endpointSummaries = @()
    foreach ($group in @($EndpointProbes | Group-Object -Property identitySha256)) {
        $rows = @($group.Group)
        $durations = @($rows | ForEach-Object { [double]$_.durationMilliseconds })
        $endpointSummaries += [pscustomobject][ordered]@{
            identitySha256 = $group.Name
            port = [int]$rows[0].port
            probeCount = $rows.Count
            readyCount = @($rows | Where-Object status -eq 'Ready').Count
            timeoutCount = @($rows | Where-Object status -eq 'Timeout').Count
            failedCount = @($rows | Where-Object status -eq 'Failed').Count
            durationMilliseconds = Get-WorkloadDistribution -Values $durations
        }
    }
    $allReady = $EndpointProbes.Count -gt 0 -and
        @($EndpointProbes | Where-Object status -ne 'Ready').Count -eq 0
    return [pscustomobject][ordered]@{
        pathCount = $Paths.Count
        localPathCount = @($Paths | Where-Object locality -eq 'Local').Count
        cloudSyncPathCount = @($Paths | Where-Object locality -eq 'CloudSyncRoot').Count
        networkPathCount = @($Paths | Where-Object locality -eq 'Network').Count
        recallOnDataAccessCount = @($Paths | Where-Object recallOnDataAccess -eq $true).Count
        offlineCount = @($Paths | Where-Object offline -eq $true).Count
        endpointCount = @($endpointSummaries).Count
        readiness = if ($EndpointProbes.Count -eq 0) {
            'NoEndpointsDeclared'
        } elseif ($allReady) {
            'AllDeclaredEndpointsReady'
        } else {
            'OneOrMoreEndpointProbesNotReady'
        }
        endpoints = @($endpointSummaries)
        decision = 'BaselineOnlyNoPerformanceClaim'
    }
}

function Get-DependencyConditionSignature {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Paths,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$EndpointProbes
    )

    $pathConditions = @($Paths | Sort-Object identitySha256 | ForEach-Object {
        [ordered]@{
            identitySha256 = $_.identitySha256
            locality = $_.locality
            driveType = $_.driveType
            driveReady = $_.driveReady
            driveFormat = $_.driveFormat
            existenceStatus = $_.existenceStatus
            knownOneDriveRoot = $_.knownOneDriveRoot
            reparsePoint = $_.reparsePoint
            offline = $_.offline
            recallOnDataAccess = $_.recallOnDataAccess
        }
    })
    $endpointConditions = @($EndpointProbes | Sort-Object identitySha256, probeRun | ForEach-Object {
        [ordered]@{
            identitySha256 = $_.identitySha256
            port = $_.port
            probeRun = $_.probeRun
            status = $_.status
        }
    })
    $canonical = [ordered]@{
        schemaVersion = 1
        paths = $pathConditions
        endpoints = $endpointConditions
    } | ConvertTo-Json -Depth 10 -Compress
    return (Get-RedactedDependencyHash -Value $canonical)
}

function Invoke-DependencyProfile {
    param(
        [string]$Root,
        [AllowEmptyCollection()][string[]]$Paths = @(),
        [AllowEmptyCollection()][string[]]$Endpoints = @(),
        [ValidateRange(1, 10)][int]$ProbeRunCount,
        [ValidateRange(100, 10000)][int]$TimeoutMilliseconds,
        [ValidateRange(3, 25)][int]$CalibrationIterations
    )

    Ensure-DataDirectories -Root $Root
    $effectivePaths = @($Paths)
    if ($effectivePaths.Count -eq 0) {
        $effectivePaths = @($Root)
    }
    $resolvedEndpoints = @()
    for ($endpointIndex = 0; $endpointIndex -lt $Endpoints.Count; $endpointIndex++) {
        $resolvedEndpoints += Resolve-DependencyEndpoint `
            -Endpoint $Endpoints[$endpointIndex] `
            -InputIndex $endpointIndex
    }

    $observer = Measure-DependencyInventoryOverhead `
        -Paths $effectivePaths `
        -Iterations $CalibrationIterations
    $pathObservations = @()
    for ($pathIndex = 0; $pathIndex -lt $effectivePaths.Count; $pathIndex++) {
        $pathObservations += Get-DependencyPathObservation `
            -Path $effectivePaths[$pathIndex] `
            -InputIndex $pathIndex
    }
    $endpointProbes = @()
    foreach ($endpoint in $resolvedEndpoints) {
        for ($probeRun = 1; $probeRun -le $ProbeRunCount; $probeRun++) {
            $endpointProbes += Invoke-DependencyEndpointProbe `
                -Endpoint $endpoint `
                -TimeoutMilliseconds $TimeoutMilliseconds `
                -ProbeRun $probeRun
        }
    }

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')
    $runSuffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $evidencePath = Join-Path (Join-Path $Root 'measurements') "$stamp-$runSuffix-dependency-profile.json"
    $profile = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        experimentId = $script:ExperimentId
        layer = 12
        kind = 'dependency-profile'
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        environment = Get-WindowsEnvironment
        requested = [pscustomobject][ordered]@{
            pathCount = $effectivePaths.Count
            endpointCount = $resolvedEndpoints.Count
            probeRunCount = $ProbeRunCount
            endpointTimeoutMilliseconds = $TimeoutMilliseconds
        }
        instrumentation = [pscustomobject][ordered]@{
            pathInventorySource = 'System.IO.Path, DriveInfo, and File.GetAttributes'
            networkProbeSource = 'TcpClient.BeginConnect, bounded WaitOne, EndConnect, then close'
            timer = 'System.Diagnostics.Stopwatch'
            pathInventoryCalibration = $observer
            maximumDeclaredEndpointBudgetMilliseconds = (
                $resolvedEndpoints.Count * $ProbeRunCount * $TimeoutMilliseconds
            )
            qualification = 'Path inventory cost is calibrated. Each TCP connection is the readiness interval itself and has a hard timeout; no application payload is sent.'
        }
        collectionScope = 'Raw paths, host names, IP addresses, directory listings, file names, file contents, and application payloads are not recorded. Identity values are SHA-256 hashes. UNC and mapped-network paths are classified without existence checks to avoid unbounded remote I/O.'
        paths = @($pathObservations)
        endpointProbes = @($endpointProbes)
        summary = Get-DependencyProfileSummary `
            -Paths @($pathObservations) `
            -EndpointProbes @($endpointProbes)
        conditionSignatureSha256 = Get-DependencyConditionSignature `
            -Paths @($pathObservations) `
            -EndpointProbes @($endpointProbes)
        evidencePath = $evidencePath
    }
    $profile | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidencePath -Encoding UTF8
    try {
        Write-StructuredEvent -Root $Root -Level Information -Event 'dependency-profile-complete' -Data @{
            evidencePath = $evidencePath
            pathCount = $profile.summary.pathCount
            endpointCount = $profile.summary.endpointCount
            readiness = $profile.summary.readiness
            conditionSignatureSha256 = $profile.conditionSignatureSha256
            observationOnly = $true
        }
    } catch {
        Write-Warning "The dependency profile was saved, but the optional event journal could not be updated ($($_.Exception.GetType().Name))."
    }

    Write-Host ''
    Write-Host 'Layer 12 dependency readiness profile (observation only)' -ForegroundColor Cyan
    Write-Host "Storage paths: $($profile.summary.pathCount) (local $($profile.summary.localPathCount), cloud-sync $($profile.summary.cloudSyncPathCount), network $($profile.summary.networkPathCount))"
    Write-Host "Declared endpoints: $($profile.summary.endpointCount); readiness: $($profile.summary.readiness)"
    Write-Host "Condition signature: $($profile.conditionSignatureSha256)"
    Write-Host "Evidence: $evidencePath" -ForegroundColor DarkGray
    Write-Host 'No file content or Windows setting was changed and no performance-gain claim was made.' -ForegroundColor DarkYellow
    return $profile
}

function Get-BaselineForEnhancement {
    param([string]$Root)

    $sessionPath = Join-Path $Root 'session.json'
    if (-not (Test-Path -LiteralPath $sessionPath)) {
        throw 'No baseline session exists. Run Analyze before applying an enhancement.'
    }
    $session = Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
    if (-not $session.baselinePath -or -not (Test-Path -LiteralPath $session.baselinePath)) {
        throw 'The baseline evidence referenced by session.json is missing. Run Analyze again.'
    }
    $baseline = Get-Content -LiteralPath $session.baselinePath -Raw | ConvertFrom-Json
    if ($baseline.experimentId -ne $script:ExperimentId -or $baseline.kind -ne 'baseline') {
        throw 'The baseline evidence identity is not valid for EXP-047.'
    }
    return $baseline
}

function New-EnhancementEntry {
    param(
        [string]$Name,
        [object]$Original,
        [object]$Applied,
        [bool]$RebootRequired,
        [object]$Baseline,
        [object]$EnvironmentAtApply
    )
    return [pscustomobject][ordered]@{
        id = [guid]::NewGuid().ToString()
        candidate = $Name
        appliedUtc = [DateTime]::UtcNow.ToString('o')
        status = 'pending'
        original = $Original
        requested = $Applied
        baselineEvidencePath = $Baseline.evidencePath
        baselineEnvironment = $Baseline.environment
        environmentAtApply = $EnvironmentAtApply
        rebootRequired = $RebootRequired
        verification = $null
        revertedUtc = $null
    }
}

function Test-RestorePointPrerequisite {
    param([string]$Root)

    $restorePoint = [pscustomobject][ordered]@{
        attemptedUtc = [DateTime]::UtcNow.ToString('o')
        succeeded = $false
        detail = $null
    }
    try {
        Checkpoint-Computer -Description "ZBookPerf $script:ExperimentId" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        $restorePoint.succeeded = $true
        $restorePoint.detail = 'System Restore reported success.'
    } catch {
        $restorePoint.detail = $_.Exception.Message
        Write-Warning "System Restore could not create a point: $($restorePoint.detail)"
        Write-Warning 'Continuing only because -LabTier2Confirmed states that a tested external recovery path exists. Windows also limits restore-point creation frequency.'
    }
    Write-StructuredEvent -Root $Root -Level $(if ($restorePoint.succeeded) { 'Information' } else { 'Warning' }) -Event 'restore-point' -Data @{ succeeded = $restorePoint.succeeded; detail = $restorePoint.detail }
    return $restorePoint
}

function Get-CandidateOriginalState {
    param(
        [string]$Name,
        [switch]$DiagnosticConfirmed
    )
    switch ($Name) {
        'PowerAc' { return Get-PowerCandidateState }
        'MmcssResponsiveness' { return Get-RegistryValueState -Path $script:MmcssPath -Name 'SystemResponsiveness' }
        'NtfsLastAccess' { return Get-NtfsLastAccessState }
        'VisualEffects' { return Get-VisualEffectsState }
        'FastStartupDiagnostic' {
            if (-not $DiagnosticConfirmed) { throw 'FastStartupDiagnostic requires -Diagnostic in non-interactive runs because disabling Fast Startup is a diagnostic isolation step, not a universal optimization.' }
            return Get-RegistryValueState -Path $script:FastStartupPath -Name 'HiberbootEnabled'
        }
    }
}

function Get-CandidateRequestedState {
    param([string]$Name)
    switch ($Name) {
        'PowerAc' {
            return [pscustomobject][ordered]@{
                schemeGuid = $script:HighPerformanceScheme
                acValues = [pscustomobject]$script:PowerTargets
                note = 'AC-only experiment. Autonomous hardware P-state control can make legacy indices advisory or ignored.'
            }
        }
        'MmcssResponsiveness' { return [pscustomobject]@{ value = 10; type = 'DWord' } }
        'NtfsLastAccess' { return [pscustomobject]@{ value = 1 } }
        'VisualEffects' {
            return [pscustomobject]@{
                UIEffects = $false; ClientAreaAnimation = $false; MenuAnimation = $false
                TooltipAnimation = $false; SelectionFade = $false; ComboBoxAnimation = $false
                ListBoxSmoothScrolling = $false
            }
        }
        'FastStartupDiagnostic' { return [pscustomobject]@{ value = 0; type = 'DWord' } }
    }
}

function Apply-Candidate {
    param([string]$Name, [object]$Requested)
    switch ($Name) {
        'PowerAc' { Apply-PowerCandidate }
        'MmcssResponsiveness' {
            New-ItemProperty -LiteralPath $script:MmcssPath -Name 'SystemResponsiveness' -Value 10 -PropertyType DWord -Force | Out-Null
        }
        'NtfsLastAccess' { Set-NtfsLastAccessState -Value 1 }
        'VisualEffects' { Set-VisualEffectsState -Values $Requested }
        'FastStartupDiagnostic' {
            New-ItemProperty -LiteralPath $script:FastStartupPath -Name 'HiberbootEnabled' -Value 0 -PropertyType DWord -Force | Out-Null
        }
    }
}

function Test-CandidateApplied {
    param([string]$Name)
    switch ($Name) {
        'PowerAc' { return Test-PowerCandidateApplied }
        'MmcssResponsiveness' {
            $state = Get-RegistryValueState -Path $script:MmcssPath -Name 'SystemResponsiveness'
            return ($state.Exists -and [int]$state.Value -eq 10 -and $state.Kind -eq 'DWord')
        }
        'NtfsLastAccess' { return ((Get-NtfsLastAccessState).value -eq 1) }
        'VisualEffects' {
            $state = Get-VisualEffectsState
            foreach ($property in $state.values.PSObject.Properties) {
                if ([bool]$property.Value) { return $false }
            }
            return $true
        }
        'FastStartupDiagnostic' {
            $state = Get-RegistryValueState -Path $script:FastStartupPath -Name 'HiberbootEnabled'
            return ($state.Exists -and [int]$state.Value -eq 0 -and $state.Kind -eq 'DWord')
        }
    }
}

function Restore-Candidate {
    param([object]$Entry)
    switch ($Entry.candidate) {
        'PowerAc' { Restore-PowerCandidate -Original $Entry.original }
        'MmcssResponsiveness' { Set-RegistryValueFromState -State $Entry.original }
        'NtfsLastAccess' { Set-NtfsLastAccessState -Value ([int]$Entry.original.value) }
        'VisualEffects' { Set-VisualEffectsState -Values $Entry.original.values }
        'FastStartupDiagnostic' { Set-RegistryValueFromState -State $Entry.original }
    }
}

function Test-CandidateRestored {
    param([object]$Entry)
    switch ($Entry.candidate) {
        'PowerAc' {
            $active = Get-PowerSchemeGuid -Output (Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/getactivescheme')).Output
            if ($active -ne $Entry.original.activeSchemeGuid) { return $false }
            foreach ($alias in $script:PowerTargets.Keys) {
                if ((Get-PowerAcValue -SchemeGuid $Entry.original.targetSchemeGuid -SettingAlias $alias) -ne [int]$Entry.original.acValues.$alias) { return $false }
                if (-not (Test-RegistryValueMatchesState -Expected $Entry.original.attributeStates.$alias)) { return $false }
            }
            return $true
        }
        'MmcssResponsiveness' {
            return Test-RegistryValueMatchesState -Expected $Entry.original
        }
        'NtfsLastAccess' { return ((Get-NtfsLastAccessState).value -eq [int]$Entry.original.value) }
        'VisualEffects' {
            $current = Get-VisualEffectsState
            foreach ($property in $Entry.original.values.PSObject.Properties) {
                if ([bool]$current.values.($property.Name) -ne [bool]$property.Value) { return $false }
            }
            return $true
        }
        'FastStartupDiagnostic' {
            return Test-RegistryValueMatchesState -Expected $Entry.original
        }
    }
}

function Invoke-Enhancement {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [string]$Name,
        [string]$Root,
        [switch]$Tier2Confirmed,
        [switch]$DiagnosticConfirmed
    )

    if (-not $Name) { throw '-Candidate is required for direct Enhance. Use -Action ApplyAll for the named, reversible synergy batch.' }
    if ($Name -eq 'PowerAc') {
        $powerSupport = Get-PowerCandidateSupport
        if (-not $powerSupport.supported) {
            throw "PowerAc is unsupported on this PC. $($powerSupport.reason) No setting was changed."
        }
    }
    $isMachine = $Name -in $script:MachineCandidates
    if ($isMachine -and -not $WhatIfPreference -and -not (Test-IsAdministrator)) {
        throw "Candidate '$Name' requires an administrator console."
    }
    if ($isMachine -and -not $WhatIfPreference -and -not $Tier2Confirmed) {
        throw "Candidate '$Name' is Tier 2. Use a disposable image or dedicated lab system with a tested recovery path, then pass -LabTier2Confirmed."
    }

    $original = Get-CandidateOriginalState -Name $Name -DiagnosticConfirmed:$DiagnosticConfirmed
    $requested = Get-CandidateRequestedState -Name $Name
    $rebootRequired = $Name -in @('NtfsLastAccess', 'FastStartupDiagnostic')

    Write-Host "Candidate: $Name" -ForegroundColor Cyan
    Write-Host 'Original state:' -ForegroundColor Yellow
    $original | ConvertTo-Json -Depth 12 | Write-Host
    Write-Host 'Requested state:' -ForegroundColor Yellow
    $requested | ConvertTo-Json -Depth 12 | Write-Host

    if (-not $PSCmdlet.ShouldProcess("$env:COMPUTERNAME / $Name", 'Apply one reversible EXP-047 candidate')) {
        Write-Host 'Dry run complete. No setting was changed.' -ForegroundColor DarkYellow
        return
    }

    Ensure-DataDirectories -Root $Root
    $baseline = Get-BaselineForEnhancement -Root $Root
    $environmentAtApply = Get-WindowsEnvironment
    $log = Get-ChangeLog -Root $Root
    $activeSameCandidate = @($log.entries | Where-Object {
        $_.candidate -eq $Name -and $_.status -eq 'applied'
    })
    if ($activeSameCandidate.Count -gt 0) {
        if (Test-CandidateApplied -Name $Name) {
            Write-Host 'The requested candidate is already applied and verified. No duplicate entry was created.' -ForegroundColor Green
            return
        }
        throw 'An active journal entry exists, but the candidate no longer verifies. Inspect or revert the recorded state before attempting another application.'
    }
    if ($isMachine) { [void](Test-RestorePointPrerequisite -Root $Root) }

    $entry = New-EnhancementEntry -Name $Name -Original $original -Applied $requested -RebootRequired $rebootRequired -Baseline $baseline -EnvironmentAtApply $environmentAtApply
    $log.entries = @($log.entries) + @($entry)
    Save-ChangeLog -Root $Root -Log $log
    try {
        Apply-Candidate -Name $Name -Requested $requested
        if (-not (Test-CandidateApplied -Name $Name)) {
            throw 'Post-application verification did not match the requested state.'
        }
        $entry.status = 'applied'
        $entry.verification = [pscustomobject]@{ verifiedUtc = [DateTime]::UtcNow.ToString('o'); passed = $true }
        Save-ChangeLog -Root $Root -Log $log
        Write-StructuredEvent -Root $Root -Level Information -Event 'candidate-applied' -Data @{ candidate = $Name; entryId = $entry.id; rebootRequired = $rebootRequired }
        Write-Host "Applied and verified: $Name" -ForegroundColor Green
        if ($rebootRequired) { Write-Warning 'A reboot-persistence check is still required before this experiment can be accepted.' }
    } catch {
        $entry.status = 'apply-failed'
        $entry.verification = [pscustomobject]@{ verifiedUtc = [DateTime]::UtcNow.ToString('o'); passed = $false; error = $_.Exception.Message }
        try {
            Restore-Candidate -Entry $entry
            $entry.status = 'apply-failed-rolled-back'
        } catch {
            $entry.status = 'apply-failed-rollback-failed'
            $entry | Add-Member -NotePropertyName rollbackError -NotePropertyValue $_.Exception.Message -Force
        }
        Save-ChangeLog -Root $Root -Log $log
        Write-StructuredEvent -Root $Root -Level Error -Event 'candidate-apply-failed' -Data @{ candidate = $Name; entryId = $entry.id; status = $entry.status }
        throw
    }
}

function Invoke-RevertChanges {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([string]$Root)

    $log = Get-ChangeLog -Root $Root
    $active = @($log.entries | Where-Object { $_.status -eq 'applied' } | Select-Object -Last 1)
    if ($active.Count -eq 0) {
        Write-Host 'No applied ZBookPerf change is recorded.' -ForegroundColor DarkYellow
        return
    }
    $entry = $active[0]
    if ($entry.candidate -in $script:MachineCandidates -and -not (Test-IsAdministrator)) {
        throw "Reverting '$($entry.candidate)' requires an administrator console."
    }
    if (-not $PSCmdlet.ShouldProcess("$env:COMPUTERNAME / $($entry.candidate)", "Restore captured state from entry $($entry.id)")) {
        Write-Host 'Revert dry run complete. No setting was changed.' -ForegroundColor DarkYellow
        return
    }
    try {
        Restore-Candidate -Entry $entry
        if (-not (Test-CandidateRestored -Entry $entry)) {
            throw 'Rollback verification did not match the captured original state.'
        }
        $entry.status = 'reverted'
        $entry.revertedUtc = [DateTime]::UtcNow.ToString('o')
        $entry | Add-Member -NotePropertyName rollbackVerification -NotePropertyValue ([pscustomobject]@{ verifiedUtc = [DateTime]::UtcNow.ToString('o'); passed = $true }) -Force
        Save-ChangeLog -Root $Root -Log $log
        Write-StructuredEvent -Root $Root -Level Information -Event 'candidate-reverted' -Data @{ candidate = $entry.candidate; entryId = $entry.id }
        Write-Host "Restored and verified: $($entry.candidate)" -ForegroundColor Green
    } catch {
        $entry.status = 'rollback-failed'
        $entry | Add-Member -NotePropertyName rollbackVerification -NotePropertyValue ([pscustomobject]@{ verifiedUtc = [DateTime]::UtcNow.ToString('o'); passed = $false; error = $_.Exception.Message }) -Force
        Save-ChangeLog -Root $Root -Log $log
        Write-StructuredEvent -Root $Root -Level Error -Event 'candidate-revert-failed' -Data @{ candidate = $entry.candidate; entryId = $entry.id; error = $_.Exception.Message }
        throw
    }
}

function Get-PerformanceLayerCatalog {
    return @(
        [pscustomobject][ordered]@{
            number = 1
            name = 'Physical and thermal health'
            description = 'Checks heat, cooling, power source, and throttling before software tuning.'
            assessment = 'ThermalProfile'
            assessmentLabel = 'Passive processor performance-limit and thermal-envelope profile'
            candidates = @()
        },
        [pscustomobject][ordered]@{
            number = 2
            name = 'Hardware resources and bottlenecks'
            description = 'Finds pressure on the CPU, memory, storage, and hardware queues.'
            assessment = 'HardwareProfile'
            assessmentLabel = 'Installed storage-path inventory with passive per-disk latency and queue baseline'
            candidates = @()
        },
        [pscustomobject][ordered]@{
            number = 3
            name = 'BIOS, UEFI, embedded-controller, and firmware interactions'
            description = 'Covers firmware timing, hardware control, and supported HP firmware behavior.'
            assessment = 'FirmwareProfile'
            assessmentLabel = 'UEFI/BIOS boundary, SMBIOS/EC fields, Secure Boot query, and HP BIOS WMI metadata'
            candidates = @()
        },
        [pscustomobject][ordered]@{
            number = 4
            name = 'Platform drivers and OEM components'
            description = 'Reviews graphics, storage, network, dock, and HP driver coordination.'
            assessment = 'DriverProfile'
            assessmentLabel = 'Redacted signed-package, Plug and Play health, and driver-service ownership profile'
            candidates = @()
        },
        [pscustomobject][ordered]@{
            number = 5
            name = 'Kernel, scheduler, memory, storage, interrupts, and DPC/ISR behavior'
            description = 'Tunes documented scheduling and storage behavior that affects response time.'
            assessment = 'KernelProfile'
            assessmentLabel = 'Repeated DPC/ISR, scheduling, paging, and storage-pressure baseline'
            candidates = @('MmcssResponsiveness', 'NtfsLastAccess')
        },
        [pscustomobject][ordered]@{
            number = 6
            name = 'Power management and performance policy'
            description = 'Aligns supported processor and power policy with plugged-in performance.'
            assessment = 'Baseline'
            assessmentLabel = 'Power source, mode, battery, and processor baseline'
            candidates = @('PowerAc')
        },
        [pscustomobject][ordered]@{
            number = 7
            name = 'Security and isolation overhead without reducing protection'
            description = 'Measures security cost while keeping Windows protection fully enabled.'
            assessment = 'NotIntegrated'
            assessmentLabel = 'No product-integrated assessment yet'
            candidates = @()
        },
        [pscustomobject][ordered]@{
            number = 8
            name = 'Boot, services, tasks, background permissions, and startup applications'
            description = 'Improves the path from power-on and sign-in to a genuinely usable desktop.'
            assessment = 'NotIntegrated'
            assessmentLabel = 'No product-integrated off-to-usable assessment yet'
            candidates = @('FastStartupDiagnostic')
        },
        [pscustomobject][ordered]@{
            number = 9
            name = 'Group Policy, MDM, registry, and system configuration'
            description = 'Finds configuration conflicts and changes only documented, unmanaged settings.'
            assessment = 'NotIntegrated'
            assessmentLabel = 'No product-integrated assessment yet'
            candidates = @()
        },
        [pscustomobject][ordered]@{
            number = 10
            name = 'Shell, GUI, capture, notifications, and perceived responsiveness'
            description = 'Targets Explorer, menus, visual effects, capture, and visible response time.'
            assessment = 'ShellProfile'
            assessmentLabel = 'Shell configuration inventory and Explorer readiness baseline'
            candidates = @('VisualEffects')
        },
        [pscustomobject][ordered]@{
            number = 11
            name = 'Application/runtime efficiency and workload profiles'
            description = 'Measures the real apps you use and their CPU, I/O, memory, and launch behavior.'
            assessment = 'WorkloadProfile'
            assessmentLabel = 'Existing-process CPU, I/O, memory, thread, and handle profile'
            candidates = @()
        },
        [pscustomobject][ordered]@{
            number = 12
            name = 'Workload data, storage locality, network dependencies, and reproducibility'
            description = 'Checks whether files, storage, and network dependencies make work feel slow.'
            assessment = 'DependencyProfile'
            assessmentLabel = 'Redacted storage-locality and bounded endpoint-readiness profile'
            candidates = @()
        }
    )
}

function Get-PerformanceLayer {
    param([ValidateRange(1, 12)][int]$Number)

    return @(Get-PerformanceLayerCatalog | Where-Object { $_.number -eq $Number })[0]
}

function Get-CandidateDisplayName {
    param([string]$Name)

    switch ($Name) {
        'PowerAc' { return 'AC High performance processor policy' }
        'MmcssResponsiveness' { return 'MMCSS SystemResponsiveness = 10' }
        'NtfsLastAccess' { return 'NTFS DisableLastAccess = 1' }
        'VisualEffects' { return 'Documented visual-effect APIs' }
        'FastStartupDiagnostic' { return 'Fast Startup diagnostic isolation' }
        default { return $Name }
    }
}

function Get-LayerWorkflowPath {
    param([string]$Root)
    return (Join-Path $Root 'layer-workflow.json')
}

function New-LayerWorkflowState {
    return [pscustomobject][ordered]@{
        schemaVersion = $script:LayerWorkflowSchemaVersion
        productVersion = $script:ProductVersion
        cycleNumber = 1
        currentLayer = 1
        phase = 'assessment-required'
        activeCandidate = $null
        createdUtc = [DateTime]::UtcNow.ToString('o')
        updatedUtc = [DateTime]::UtcNow.ToString('o')
        history = @()
    }
}

function Get-LayerWorkflowState {
    param([string]$Root)

    $path = Get-LayerWorkflowPath -Root $Root
    if (-not (Test-Path -LiteralPath $path)) {
        return (New-LayerWorkflowState)
    }
    $state = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if (
        [int]$state.schemaVersion -ne $script:LayerWorkflowSchemaVersion -or
        [int]$state.currentLayer -lt 1 -or
        [int]$state.currentLayer -gt 12
    ) {
        throw "Unsupported or invalid layer workflow state: $path"
    }
    return $state
}

function Save-LayerWorkflowState {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State
    )

    Ensure-DataDirectories -Root $Root
    $State.productVersion = $script:ProductVersion
    $State.updatedUtc = [DateTime]::UtcNow.ToString('o')
    $State | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Get-LayerWorkflowPath -Root $Root) -Encoding UTF8
}

function Add-LayerWorkflowHistory {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Action,
        [int]$Layer,
        [AllowNull()][string]$Candidate,
        [AllowNull()][string]$EvidencePath,
        [AllowNull()][string]$Reason
    )

    $entry = [pscustomobject][ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        layer = $Layer
        action = $Action
        candidate = $Candidate
        evidencePath = $EvidencePath
        reason = $Reason
    }
    $State.history = @($State.history) + @($entry)
}

function Get-ProcessedLayerCandidates {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [ValidateRange(1, 12)][int]$Layer
    )

    return @($State.history | Where-Object {
        [int]$_.layer -eq $Layer -and
        $_.candidate -and
        $_.action -in @('candidate-kept', 'candidate-reverted', 'candidate-skipped', 'candidate-unsupported')
    } | ForEach-Object { [string]$_.candidate } | Sort-Object -Unique)
}

function Get-NextLayerCandidate {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [ValidateRange(1, 12)][int]$Layer
    )

    $catalogEntry = Get-PerformanceLayer -Number $Layer
    $processed = @(Get-ProcessedLayerCandidates -State $State -Layer $Layer)
    foreach ($candidate in @($catalogEntry.candidates)) {
        if ($candidate -notin $processed) {
            return [string]$candidate
        }
    }
    return $null
}

function Get-WorkflowCandidateSupport {
    param([string]$Name)

    if ($Name -eq 'PowerAc') {
        return (Get-PowerCandidateSupport)
    }
    return [pscustomobject][ordered]@{
        supported = $true
        reason = 'Candidate-specific support detection runs again before original-state capture and application.'
    }
}

function Move-LayerWorkflowForward {
    param([Parameter(Mandatory = $true)][object]$State)

    if ([int]$State.currentLayer -eq 12) {
        $State.currentLayer = 1
        $State.cycleNumber = [int]$State.cycleNumber + 1
    } else {
        $State.currentLayer = [int]$State.currentLayer + 1
    }
    $State.phase = 'assessment-required'
    $State.activeCandidate = $null
}

function Show-PerformanceLayerMap {
    param(
        [string]$Root,
        [object]$State = $null
    )

    if (-not $State) { $State = Get-LayerWorkflowState -Root $Root }
    Write-Host ''
    Write-Host "Sequential performance-layer workflow - cycle $($State.cycleNumber)" -ForegroundColor Cyan
    foreach ($layer in Get-PerformanceLayerCatalog) {
        $nextCandidate = Get-NextLayerCandidate -State $State -Layer $layer.number
        $marker = if ([int]$State.currentLayer -eq $layer.number) { '>' } else { ' ' }
        $assessmentColor = if ($layer.assessment -eq 'NotIntegrated') { 'DarkYellow' } else { 'Gray' }
        Write-Host ("{0} Layer {1,2}: {2}" -f $marker, $layer.number, $layer.name) -ForegroundColor $(if ($marker -eq '>') { 'Cyan' } else { 'White' })
        Write-Host ("    Internal baseline: {0}" -f $layer.assessmentLabel) -ForegroundColor $assessmentColor
        Write-Host ("    Next experiment: {0}" -f $(if ($nextCandidate) { Get-CandidateDisplayName -Name $nextCandidate } else { 'none' })) -ForegroundColor DarkGray
    }
    Write-Host 'A missing integration is a product gap, not evidence that the layer is healthy.' -ForegroundColor DarkYellow
}

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
    $evidencePath = $null
    $reason = $null
    switch ($layer.assessment) {
        'ThermalProfile' {
            $profile = Invoke-ThermalProfile `
                -Root $Root `
                -Seconds $Seconds `
                -IntervalSeconds $Interval `
                -CalibrationIterations $ThermalCalibration
            $evidencePath = $profile.evidencePath
        }
        'HardwareProfile' {
            $profile = Invoke-HardwareProfile `
                -Root $Root `
                -Seconds $Seconds `
                -IntervalSeconds $Interval `
                -CalibrationIterations $HardwareCalibration
            $evidencePath = $profile.evidencePath
        }
        'FirmwareProfile' {
            $profile = Invoke-FirmwareProfile `
                -Root $Root `
                -CalibrationIterations $FirmwareCalibration
            $evidencePath = $profile.evidencePath
        }
        'DriverProfile' {
            $profile = Invoke-DriverProfile `
                -Root $Root `
                -CalibrationIterations $DriverCalibration `
                -DeviceLimit $DriverLimit
            $evidencePath = $profile.evidencePath
        }
        'KernelProfile' {
            $profile = Invoke-KernelProfile `
                -Root $Root `
                -BlockCount $KernelBlocks `
                -SamplesPerBlock $KernelSamples `
                -SampleIntervalSeconds $KernelInterval `
                -CalibrationIterations $KernelCalibration
            $evidencePath = $profile.evidencePath
        }
        'Baseline' {
            $measurement = Invoke-Measurement -Kind baseline -Seconds $Seconds -Interval $Interval -Root $Root -SkipTrace:$SkipTrace
            $evidencePath = $measurement.evidencePath
        }
        'ShellProfile' {
            $profile = Invoke-ShellProfile `
                -Root $Root `
                -RunCount $ShellRuns `
                -WarmupRunCount $ShellWarmups `
                -TimeoutMilliseconds $ShellTimeout `
                -ProbeCalibrationIterations $ShellCalibration
            $evidencePath = $profile.evidencePath
        }
        'WorkloadProfile' {
            $profile = Invoke-WorkloadProfile `
                -Root $Root `
                -ProcessNames $WorkloadNames `
                -Seconds $Seconds `
                -IntervalMilliseconds $WorkloadInterval `
                -CalibrationIterations $WorkloadCalibration
            $evidencePath = $profile.evidencePath
        }
        'DependencyProfile' {
            $profile = Invoke-DependencyProfile `
                -Root $Root `
                -Paths $DependencyPaths `
                -Endpoints $DependencyEndpoints `
                -ProbeRunCount $DependencyRuns `
                -TimeoutMilliseconds $DependencyTimeout `
                -CalibrationIterations $DependencyCalibration
            $evidencePath = $profile.evidencePath
        }
        default {
            $reason = $layer.assessmentLabel
            Write-Host "Layer $($layer.number) assessment unavailable: $reason" -ForegroundColor DarkYellow
        }
    }

    Add-LayerWorkflowHistory `
        -State $State `
        -Action $(if ($evidencePath) { 'assessment-complete' } else { 'assessment-unavailable' }) `
        -Layer $layer.number `
        -Candidate $null `
        -EvidencePath $evidencePath `
        -Reason $reason
    $State.phase = 'assessed'
    Save-LayerWorkflowState -Root $Root -State $State
}

function Invoke-LayerEnhancementStep {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State,
        [int]$Seconds,
        [int]$Interval,
        [switch]$SkipTrace,
        [switch]$DryRun
    )

    if ($State.activeCandidate) {
        Write-Host "Candidate '$($State.activeCandidate)' is already active in this workflow. Re-measure or revert it before another change." -ForegroundColor DarkYellow
        return
    }

    $layerNumber = [int]$State.currentLayer
    $candidate = Get-NextLayerCandidate -State $State -Layer $layerNumber
    if (-not $candidate) {
        Write-Host "Layer $layerNumber has no remaining integrated change experiment." -ForegroundColor DarkYellow
        return
    }

    $support = Get-WorkflowCandidateSupport -Name $candidate
    if (-not $support.supported) {
        Write-Host "Skipping unsupported experiment: $(Get-CandidateDisplayName -Name $candidate)" -ForegroundColor DarkYellow
        Write-Host $support.reason -ForegroundColor DarkYellow
        Add-LayerWorkflowHistory -State $State -Action 'candidate-unsupported' -Layer $layerNumber -Candidate $candidate -EvidencePath $null -Reason $support.reason
        Save-LayerWorkflowState -Root $Root -State $State
        return
    }

    Write-Host "Capturing a fresh cumulative-state baseline before: $(Get-CandidateDisplayName -Name $candidate)" -ForegroundColor Cyan
    [void](Invoke-Measurement -Kind baseline -Seconds $Seconds -Interval $Interval -Root $Root -SkipTrace:$SkipTrace)

    $tier2Confirmed = $false
    if ($candidate -in $script:MachineCandidates) {
        $tier2Confirmed = Confirm-Tier2Interactive -Name $candidate
        if (-not $tier2Confirmed) {
            Write-Host 'Cancelled. No setting was changed.' -ForegroundColor DarkYellow
            return
        }
    }
    $diagnosticConfirmed = ($candidate -eq 'FastStartupDiagnostic')
    $beforeLog = Get-ChangeLog -Root $Root
    $beforeCount = @($beforeLog.entries).Count
    Invoke-Enhancement `
        -Name $candidate `
        -Root $Root `
        -Tier2Confirmed:$tier2Confirmed `
        -DiagnosticConfirmed:$diagnosticConfirmed `
        -WhatIf:$DryRun
    $afterLog = Get-ChangeLog -Root $Root
    $afterEntries = @($afterLog.entries)
    if ($afterEntries.Count -le $beforeCount) {
        Add-LayerWorkflowHistory -State $State -Action 'candidate-dry-run-or-cancelled' -Layer $layerNumber -Candidate $candidate -EvidencePath $null -Reason 'No applied journal entry was added.'
        Save-LayerWorkflowState -Root $Root -State $State
        return
    }

    $entry = $afterEntries[-1]
    if ($entry.candidate -ne $candidate -or $entry.status -ne 'applied') {
        throw "The layer workflow could not verify the applied journal entry for '$candidate'."
    }
    $State.activeCandidate = $candidate
    $State.phase = if ($entry.rebootRequired) { 'reboot-required' } else { 'remeasure-required' }
    Add-LayerWorkflowHistory -State $State -Action 'candidate-applied' -Layer $layerNumber -Candidate $candidate -EvidencePath $entry.baselinePath -Reason $State.phase
    Save-LayerWorkflowState -Root $Root -State $State

    if ($entry.rebootRequired) {
        Write-Host 'A reboot is required. Reopen ZBookPerf afterward and continue this persisted workflow before re-measuring.' -ForegroundColor DarkYellow
    } else {
        Write-Host 'The workflow is paused at the measurement gate. Continue to re-measure before keeping or advancing.' -ForegroundColor DarkYellow
    }
}

function Invoke-LayerRemeasureStep {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State,
        [int]$Seconds,
        [int]$Interval,
        [switch]$SkipTrace
    )

    if (-not $State.activeCandidate) {
        Write-Host 'No layer-workflow candidate is active. Apply an experiment first.' -ForegroundColor DarkYellow
        return
    }
    $measurement = Invoke-Measurement -Kind after -Seconds $Seconds -Interval $Interval -Root $Root -SkipTrace:$SkipTrace
    Show-MeasurementComparison -Root $Root
    $State.phase = 'review-required'
    Add-LayerWorkflowHistory -State $State -Action 'candidate-measured' -Layer ([int]$State.currentLayer) -Candidate ([string]$State.activeCandidate) -EvidencePath $measurement.evidencePath -Reason 'Review before keep or revert.'
    Save-LayerWorkflowState -Root $Root -State $State
}

function Complete-LayerWorkflowCandidate {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State
    )

    if ($State.activeCandidate -and $State.phase -ne 'review-required') {
        Write-Host 'The active change cannot be kept or advanced until its repeated measurement is complete.' -ForegroundColor DarkYellow
        return
    }
    if ($State.activeCandidate) {
        Add-LayerWorkflowHistory -State $State -Action 'candidate-kept' -Layer ([int]$State.currentLayer) -Candidate ([string]$State.activeCandidate) -EvidencePath $null -Reason 'Operator retained the measured change for cumulative interaction testing.'
        $State.activeCandidate = $null
    }

    $remaining = Get-NextLayerCandidate -State $State -Layer ([int]$State.currentLayer)
    if ($remaining) {
        $State.phase = 'assessed'
        Write-Host "Staying on Layer $($State.currentLayer) for the next experiment: $(Get-CandidateDisplayName -Name $remaining)" -ForegroundColor Cyan
    } else {
        Move-LayerWorkflowForward -State $State
        Write-Host "Advanced to Layer $($State.currentLayer)." -ForegroundColor Green
    }
    Save-LayerWorkflowState -Root $Root -State $State
}

function Skip-LayerWorkflowCandidate {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State
    )

    if ($State.activeCandidate) {
        Write-Host 'An applied change cannot be skipped. Re-measure it or revert it.' -ForegroundColor DarkYellow
        return
    }
    $candidate = Get-NextLayerCandidate -State $State -Layer ([int]$State.currentLayer)
    if ($candidate) {
        Add-LayerWorkflowHistory -State $State -Action 'candidate-skipped' -Layer ([int]$State.currentLayer) -Candidate $candidate -EvidencePath $null -Reason 'Operator skipped this declared experiment.'
        Write-Host "Skipped: $(Get-CandidateDisplayName -Name $candidate)" -ForegroundColor DarkYellow
    }
    $remaining = Get-NextLayerCandidate -State $State -Layer ([int]$State.currentLayer)
    if (-not $remaining) {
        Move-LayerWorkflowForward -State $State
        Write-Host "Advanced to Layer $($State.currentLayer)." -ForegroundColor Green
    } else {
        $State.phase = 'assessed'
        Write-Host "Next Layer $($State.currentLayer) experiment: $(Get-CandidateDisplayName -Name $remaining)" -ForegroundColor Cyan
    }
    Save-LayerWorkflowState -Root $Root -State $State
}

function Revert-LayerWorkflowCandidate {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$DryRun
    )

    if (-not $State.activeCandidate) {
        Write-Host 'No layer-workflow candidate is active.' -ForegroundColor DarkYellow
        return
    }
    $candidate = [string]$State.activeCandidate
    Invoke-RevertChanges -Root $Root -WhatIf:$DryRun
    if ($DryRun) { return }

    $log = Get-ChangeLog -Root $Root
    $entry = @($log.entries | Where-Object { $_.candidate -eq $candidate } | Select-Object -Last 1)[0]
    if (-not $entry -or $entry.status -ne 'reverted') {
        throw "The layer workflow could not verify rollback for '$candidate'."
    }
    Add-LayerWorkflowHistory -State $State -Action 'candidate-reverted' -Layer ([int]$State.currentLayer) -Candidate $candidate -EvidencePath $null -Reason 'Rollback verified by the change journal.'
    $State.activeCandidate = $null
    $State.phase = 'assessed'
    Save-LayerWorkflowState -Root $Root -State $State
}

function Set-LayerWorkflowCurrentLayer {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State,
        [ValidateRange(1, 12)][int]$Layer
    )

    if ($State.activeCandidate) {
        Write-Host 'Cannot change layers while a workflow change awaits measurement or rollback.' -ForegroundColor DarkYellow
        return
    }
    Add-LayerWorkflowHistory -State $State -Action 'layer-selected' -Layer $Layer -Candidate $null -EvidencePath $null -Reason 'Operator selected a layer.'
    $State.currentLayer = $Layer
    $State.phase = 'assessment-required'
    Save-LayerWorkflowState -Root $Root -State $State
}

function Show-LayerControlMenu {
    param(
        [Parameter(Mandatory = $true)][object]$Layer,
        [Parameter(Mandatory = $true)][object]$State
    )

    $nextCandidate = Get-NextLayerCandidate -State $State -Layer $Layer.number
    Write-Host ''
    Write-Host "Layer $($Layer.number) of 12 - $($Layer.name)" -ForegroundColor Cyan
    Write-Host $Layer.description -ForegroundColor DarkGray
    Write-Host "Cycle: $($State.cycleNumber)  Phase: $($State.phase)"
    Write-Host "Internal baseline: $($Layer.assessmentLabel)"
    Write-Host "Next experiment: $(if ($nextCandidate) { Get-CandidateDisplayName -Name $nextCandidate } else { 'none' })"
    if ($State.activeCandidate) {
        Write-Host "Active change: $(Get-CandidateDisplayName -Name ([string]$State.activeCandidate))" -ForegroundColor DarkYellow
    }
    Write-Host '1. Continue this layer'
    Write-Host '2. Refresh the required internal baseline'
    Write-Host '3. Apply this layer''s next eligible tweak'
    Write-Host '4. Re-measure the active experiment'
    Write-Host '5. Keep the measured change and continue'
    Write-Host '6. Revert the active experiment'
    Write-Host '7. Skip the next experiment or advance'
    Write-Host '8. Show all 12 layers'
    Write-Host 'B. Back to main menu'
    return (Read-Host 'Choose a layer action')
}

function Invoke-NextLayerWorkflowStep {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State,
        [hashtable]$Runtime
    )

    switch ([string]$State.phase) {
        'assessment-required' {
            Invoke-LayerAssessmentStep @Runtime -Root $Root -State $State
        }
        'assessed' {
            if (Get-NextLayerCandidate -State $State -Layer ([int]$State.currentLayer)) {
                Invoke-LayerEnhancementStep `
                    -Root $Root `
                    -State $State `
                    -Seconds $Runtime.Seconds `
                    -Interval $Runtime.Interval `
                    -SkipTrace:$Runtime.SkipTrace `
                    -DryRun:$Runtime.DryRun
            } else {
                Complete-LayerWorkflowCandidate -Root $Root -State $State
            }
        }
        'remeasure-required' {
            Invoke-LayerRemeasureStep -Root $Root -State $State -Seconds $Runtime.Seconds -Interval $Runtime.Interval -SkipTrace:$Runtime.SkipTrace
        }
        'reboot-required' {
            Write-Host 'Confirm that the required reboot and health check are complete, then choose re-measure.' -ForegroundColor DarkYellow
        }
        'review-required' {
            Write-Host 'Review the comparison, then explicitly keep or revert the measured change.' -ForegroundColor DarkYellow
        }
        default {
            throw "Unknown layer workflow phase '$($State.phase)'."
        }
    }
}

function Invoke-LayerWorkflowUntilGate {
    param(
        [string]$Root,
        [Parameter(Mandatory = $true)][object]$State,
        [hashtable]$Runtime
    )

    $startingCycle = [int]$State.cycleNumber
    for ($step = 0; $step -lt 48; $step++) {
        if ([int]$State.cycleNumber -gt $startingCycle) {
            Write-Host "Completed cycle $startingCycle. The next run begins again at Layer 1." -ForegroundColor Green
            return
        }
        switch ([string]$State.phase) {
            'assessment-required' {
                Invoke-LayerAssessmentStep @Runtime -Root $Root -State $State
                continue
            }
            'assessed' {
                if (Get-NextLayerCandidate -State $State -Layer ([int]$State.currentLayer)) {
                    $beforeHistoryCount = @($State.history).Count
                    Invoke-LayerEnhancementStep `
                        -Root $Root `
                        -State $State `
                        -Seconds $Runtime.Seconds `
                        -Interval $Runtime.Interval `
                        -SkipTrace:$Runtime.SkipTrace `
                        -DryRun:$Runtime.DryRun
                    if ($State.activeCandidate) { return }
                    if (@($State.history).Count -eq $beforeHistoryCount) { return }
                    if (@($State.history)[-1].action -eq 'candidate-dry-run-or-cancelled') { return }
                    continue
                }
                Complete-LayerWorkflowCandidate -Root $Root -State $State
                continue
            }
            'remeasure-required' {
                Invoke-LayerRemeasureStep -Root $Root -State $State -Seconds $Runtime.Seconds -Interval $Runtime.Interval -SkipTrace:$Runtime.SkipTrace
                return
            }
            'reboot-required' {
                Write-Host 'The workflow is paused for a reboot and health check. Reopen ZBookPerf afterward, then choose re-measure.' -ForegroundColor DarkYellow
                return
            }
            'review-required' {
                Write-Host 'The workflow is paused for a keep-or-revert decision based on the comparison.' -ForegroundColor DarkYellow
                return
            }
            default {
                throw "Unknown layer workflow phase '$($State.phase)'."
            }
        }
    }
    throw 'The sequential workflow exceeded its bounded step count without reaching a gate.'
}

function New-LayerRuntime {
    param(
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

    return @{
        Seconds = $Seconds
        Interval = $Interval
        SkipTrace = [bool]$SkipTrace
        ThermalCalibration = $ThermalCalibration
        HardwareCalibration = $HardwareCalibration
        FirmwareCalibration = $FirmwareCalibration
        DriverCalibration = $DriverCalibration
        DriverLimit = $DriverLimit
        KernelBlocks = $KernelBlocks
        KernelSamples = $KernelSamples
        KernelInterval = $KernelInterval
        KernelCalibration = $KernelCalibration
        ShellRuns = $ShellRuns
        ShellWarmups = $ShellWarmups
        ShellTimeout = $ShellTimeout
        ShellCalibration = $ShellCalibration
        WorkloadNames = $WorkloadNames
        WorkloadInterval = $WorkloadInterval
        WorkloadCalibration = $WorkloadCalibration
        DependencyPaths = @($DependencyPaths)
        DependencyEndpoints = @($DependencyEndpoints)
        DependencyRuns = $DependencyRuns
        DependencyTimeout = $DependencyTimeout
        DependencyCalibration = $DependencyCalibration
        DryRun = [bool]$DryRun
    }
}

function Invoke-SelectedPerformanceLayer {
    param(
        [string]$Root,
        [ValidateRange(1, 12)][int]$LayerNumber,
        [hashtable]$Runtime
    )

    $state = Get-LayerWorkflowState -Root $Root
    if ($state.activeCandidate) {
        if ([int]$state.currentLayer -ne $LayerNumber) {
            Write-Host "Layer $($state.currentLayer) has an unfinished change. Finish its measurement or rollback before changing layers." -ForegroundColor DarkYellow
            return
        }
        Invoke-NextLayerWorkflowStep -Root $Root -State $state -Runtime $Runtime
        return
    }

    $layer = Get-PerformanceLayer -Number $LayerNumber
    $candidate = Get-NextLayerCandidate -State $state -Layer $LayerNumber
    Write-Host ''
    Write-Host "Layer $LayerNumber - $($layer.name)" -ForegroundColor Cyan
    Write-Host $layer.description
    if (-not $candidate) {
        Write-Host 'UX-ROM does not yet contain an eligible tweak for this layer.' -ForegroundColor DarkYellow
        Write-Host 'Use Full system diagnostics for one read-only health pass; this layer remains visible as an engineering gap.' -ForegroundColor DarkGray
        return
    }

    Set-LayerWorkflowCurrentLayer -Root $Root -State $state -Layer $LayerNumber
    Write-Host "Preparing: $(Get-CandidateDisplayName -Name $candidate)" -ForegroundColor Cyan
    Write-Host 'The required baseline and support checks run automatically before the change.'
    Invoke-LayerAssessmentStep @Runtime -Root $Root -State $state
    Invoke-LayerEnhancementStep `
        -Root $Root `
        -State $state `
        -Seconds $Runtime.Seconds `
        -Interval $Runtime.Interval `
        -SkipTrace:$Runtime.SkipTrace `
        -DryRun:$Runtime.DryRun
}

function Invoke-FullSystemDiagnostics {
    param(
        [string]$Root,
        [hashtable]$Runtime
    )

    Ensure-DataDirectories -Root $Root
    Write-Host ''
    Write-Host 'Full system diagnostics' -ForegroundColor Cyan
    Write-Host 'One read-only pass: thermal envelope, system, Explorer, workload, storage-locality, and declared endpoint readiness.'
    $thermal = Invoke-ThermalProfile `
        -Root $Root `
        -Seconds $Runtime.Seconds `
        -IntervalSeconds $Runtime.Interval `
        -CalibrationIterations $Runtime.ThermalCalibration
    $hardware = Invoke-HardwareProfile `
        -Root $Root `
        -Seconds $Runtime.Seconds `
        -IntervalSeconds $Runtime.Interval `
        -CalibrationIterations $Runtime.HardwareCalibration
    $firmware = Invoke-FirmwareProfile `
        -Root $Root `
        -CalibrationIterations $Runtime.FirmwareCalibration
    $drivers = Invoke-DriverProfile `
        -Root $Root `
        -CalibrationIterations $Runtime.DriverCalibration `
        -DeviceLimit $Runtime.DriverLimit
    $kernel = Invoke-KernelProfile `
        -Root $Root `
        -BlockCount $Runtime.KernelBlocks `
        -SamplesPerBlock $Runtime.KernelSamples `
        -SampleIntervalSeconds $Runtime.KernelInterval `
        -CalibrationIterations $Runtime.KernelCalibration
    $baseline = Invoke-Measurement `
        -Kind baseline `
        -Seconds $Runtime.Seconds `
        -Interval $Runtime.Interval `
        -Root $Root `
        -SkipTrace:$Runtime.SkipTrace
    $shell = Invoke-ShellProfile `
        -Root $Root `
        -RunCount $Runtime.ShellRuns `
        -WarmupRunCount $Runtime.ShellWarmups `
        -TimeoutMilliseconds $Runtime.ShellTimeout `
        -ProbeCalibrationIterations $Runtime.ShellCalibration
    $workload = Invoke-WorkloadProfile `
        -Root $Root `
        -ProcessNames $Runtime.WorkloadNames `
        -Seconds $Runtime.Seconds `
        -IntervalMilliseconds $Runtime.WorkloadInterval `
        -CalibrationIterations $Runtime.WorkloadCalibration
    $dependencies = Invoke-DependencyProfile `
        -Root $Root `
        -Paths $Runtime.DependencyPaths `
        -Endpoints $Runtime.DependencyEndpoints `
        -ProbeRunCount $Runtime.DependencyRuns `
        -TimeoutMilliseconds $Runtime.DependencyTimeout `
        -CalibrationIterations $Runtime.DependencyCalibration

    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $manifestPath = Join-Path (Join-Path $Root 'measurements') "$stamp-full-diagnostics.json"
    $manifest = [pscustomobject][ordered]@{
        schemaVersion = $script:SchemaVersion
        product = $script:ProductName
        productVersion = $script:ProductVersion
        experimentId = $script:ExperimentId
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        observationOnly = $true
        evidence = [pscustomobject][ordered]@{
            thermalEnvelope = $thermal.evidencePath
            storagePath = $hardware.evidencePath
            firmwareBoundary = $firmware.evidencePath
            driverOwnership = $drivers.evidencePath
            kernelPressure = $kernel.evidencePath
            systemBaseline = $baseline.evidencePath
            shellReadiness = $shell.evidencePath
            workloadProfile = $workload.evidencePath
            dependencyProfile = $dependencies.evidencePath
        }
        coveredLayers = @(1, 2, 3, 4, 5, 6, 10, 11, 12)
        integrationGaps = @(7, 8, 9)
        statement = 'No Windows setting was changed. A missing layer integration is not a clean bill of health.'
    }
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Write-StructuredEvent -Root $Root -Level Information -Event 'full-diagnostics-complete' -Data @{ evidencePath = $manifestPath; observationOnly = $true }
    Write-Host "Full diagnostic manifest: $manifestPath" -ForegroundColor Green
    Write-Host 'No Windows setting was changed.' -ForegroundColor DarkYellow
    return $manifest
}

function Get-SynergyBatchPlan {
    $items = New-Object System.Collections.ArrayList
    foreach ($candidate in @('MmcssResponsiveness', 'PowerAc', 'VisualEffects')) {
        $support = Get-WorkflowCandidateSupport -Name $candidate
        $layer = @(Get-PerformanceLayerCatalog | Where-Object { $candidate -in @($_.candidates) })[0]
        [void]$items.Add([pscustomobject][ordered]@{
            candidate = $candidate
            displayName = Get-CandidateDisplayName -Name $candidate
            layer = [int]$layer.number
            supported = [bool]$support.supported
            reason = $support.reason
        })
    }
    return @($items)
}

function Get-SynergyBatchPath {
    param([string]$Root)
    return (Join-Path $Root 'latest-synergy-batch.json')
}

function Invoke-AllEligibleTweaks {
    param(
        [string]$Root,
        [hashtable]$Runtime,
        [switch]$Tier2Confirmed,
        [switch]$DryRun,
        [switch]$Interactive
    )

    $workflowState = Get-LayerWorkflowState -Root $Root
    if ($workflowState.activeCandidate) {
        throw "Layer $($workflowState.currentLayer) has an unfinished change. Measure or revert it before starting a synergy batch."
    }
    $plan = @(Get-SynergyBatchPlan)
    $eligible = @($plan | Where-Object supported)
    Write-Host ''
    Write-Host 'Apply all eligible tweaks - synergy batch' -ForegroundColor Cyan
    foreach ($item in $plan) {
        $status = if ($item.supported) { 'included' } else { 'skipped: unsupported' }
        Write-Host ("Layer {0}: {1} [{2}]" -f $item.layer, $item.displayName, $status)
        if (-not $item.supported) { Write-Host "  $($item.reason)" -ForegroundColor DarkYellow }
    }
    Write-Host 'Excluded: NTFS last-access and Fast Startup experiments require reboot-specific validation.' -ForegroundColor DarkGray
    Write-Host 'The included controls are applied as one named synergy experiment with one before/after measurement and a batch rollback record.'
    if ($eligible.Count -eq 0) {
        Write-Host 'No eligible tweak is supported on this PC.' -ForegroundColor DarkYellow
        return
    }

    if ($DryRun) {
        foreach ($item in $eligible) {
            Invoke-Enhancement -Name $item.candidate -Root $Root -WhatIf -Confirm:$false
        }
        Write-Host 'Batch dry run complete. No setting was changed.' -ForegroundColor DarkYellow
        return
    }

    $containsTier2 = @($eligible | Where-Object { $_.candidate -in $script:MachineCandidates }).Count -gt 0
    if ($containsTier2 -and -not $Tier2Confirmed) {
        if (-not $Interactive) {
            throw 'The synergy batch contains Tier 2 machine changes. Pass -LabTier2Confirmed only on a dedicated, recoverable lab system.'
        }
        Write-Warning 'This batch contains machine-wide Windows settings.'
        $answer = Read-Host 'Is this a dedicated, recoverable lab system and should UX-ROM apply the whole eligible batch? [y/N]'
        if ($answer -notin @('y', 'Y', 'yes', 'YES', 'Yes')) {
            Write-Host 'Cancelled. No setting was changed.' -ForegroundColor DarkYellow
            return
        }
        $Tier2Confirmed = $true
    } elseif ($Interactive) {
        $answer = Read-Host 'Apply the complete eligible batch? [y/N]'
        if ($answer -notin @('y', 'Y', 'yes', 'YES', 'Yes')) {
            Write-Host 'Cancelled. No setting was changed.' -ForegroundColor DarkYellow
            return
        }
    }

    $baseline = Invoke-Measurement -Kind baseline -Seconds $Runtime.Seconds -Interval $Runtime.Interval -Root $Root -SkipTrace:$Runtime.SkipTrace
    $entryIds = New-Object System.Collections.ArrayList
    try {
        foreach ($item in $eligible) {
            $beforeLog = Get-ChangeLog -Root $Root
            $beforeCount = @($beforeLog.entries).Count
            Invoke-Enhancement -Name $item.candidate -Root $Root -Tier2Confirmed:$Tier2Confirmed -Confirm:$false
            $afterLog = Get-ChangeLog -Root $Root
            if (@($afterLog.entries).Count -gt $beforeCount) {
                $entry = @($afterLog.entries)[-1]
                if ($entry.status -ne 'applied') { throw "Batch verification failed for '$($item.candidate)'." }
                [void]$entryIds.Add([string]$entry.id)
            }
        }
        $after = Invoke-Measurement -Kind after -Seconds $Runtime.Seconds -Interval $Runtime.Interval -Root $Root -SkipTrace:$Runtime.SkipTrace
        Show-MeasurementComparison -Root $Root
    } catch {
        for ($index = 0; $index -lt $entryIds.Count; $index++) {
            Invoke-RevertChanges -Root $Root -Confirm:$false
        }
        throw
    }

    $batch = [pscustomobject][ordered]@{
        schemaVersion = 1
        product = $script:ProductName
        batchId = [guid]::NewGuid().ToString()
        status = 'active'
        appliedUtc = [DateTime]::UtcNow.ToString('o')
        entryIds = @($entryIds)
        candidates = @($eligible.candidate)
        baselineEvidencePath = $baseline.evidencePath
        afterEvidencePath = $after.evidencePath
        rebootRequired = $false
        decision = 'AppliedAsRequestedNoStandalonePerformanceClaim'
    }
    $batch | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Get-SynergyBatchPath -Root $Root) -Encoding UTF8
    foreach ($item in $eligible) {
        Add-LayerWorkflowHistory -State $workflowState -Action 'candidate-kept' -Layer $item.layer -Candidate $item.candidate -EvidencePath $after.evidencePath -Reason "Retained as part of synergy batch $($batch.batchId); no standalone gain claim."
    }
    Save-LayerWorkflowState -Root $Root -State $workflowState
    Write-StructuredEvent -Root $Root -Level Information -Event 'synergy-batch-applied' -Data @{ batchId = $batch.batchId; entryIds = @($entryIds); afterEvidencePath = $after.evidencePath }
    Write-Host "Applied and verified $($entryIds.Count) change(s). Batch rollback is available from the main menu." -ForegroundColor Green
    Write-Host 'This is a cumulative configuration experiment, not a claim that each item improved performance.' -ForegroundColor DarkYellow
    return $batch
}

function Invoke-LayerWorkflow {
    param(
        [string]$Root,
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

    $runtime = New-LayerRuntime `
        -Seconds $Seconds `
        -Interval $Interval `
        -SkipTrace:$SkipTrace `
        -ThermalCalibration $ThermalCalibration `
        -HardwareCalibration $HardwareCalibration `
        -FirmwareCalibration $FirmwareCalibration `
        -DriverCalibration $DriverCalibration `
        -DriverLimit $DriverLimit `
        -KernelBlocks $KernelBlocks `
        -KernelSamples $KernelSamples `
        -KernelInterval $KernelInterval `
        -KernelCalibration $KernelCalibration `
        -ShellRuns $ShellRuns `
        -ShellWarmups $ShellWarmups `
        -ShellTimeout $ShellTimeout `
        -ShellCalibration $ShellCalibration `
        -WorkloadNames $WorkloadNames `
        -WorkloadInterval $WorkloadInterval `
        -WorkloadCalibration $WorkloadCalibration `
        -DependencyPaths $DependencyPaths `
        -DependencyEndpoints $DependencyEndpoints `
        -DependencyRuns $DependencyRuns `
        -DependencyTimeout $DependencyTimeout `
        -DependencyCalibration $DependencyCalibration `
        -DryRun:$DryRun
    $state = Get-LayerWorkflowState -Root $Root
    Save-LayerWorkflowState -Root $Root -State $state
    do {
        $layer = Get-PerformanceLayer -Number ([int]$state.currentLayer)
        switch (Show-LayerControlMenu -Layer $layer -State $state) {
            '1' { Invoke-NextLayerWorkflowStep -Root $Root -State $state -Runtime $runtime }
            '2' { Invoke-LayerAssessmentStep @runtime -Root $Root -State $state }
            '3' {
                Invoke-LayerEnhancementStep `
                    -Root $Root `
                    -State $state `
                    -Seconds $Seconds `
                    -Interval $Interval `
                    -SkipTrace:$SkipTrace `
                    -DryRun:$DryRun
            }
            '4' { Invoke-LayerRemeasureStep -Root $Root -State $state -Seconds $Seconds -Interval $Interval -SkipTrace:$SkipTrace }
            '5' { Complete-LayerWorkflowCandidate -Root $Root -State $state }
            '6' { Revert-LayerWorkflowCandidate -Root $Root -State $state -DryRun:$DryRun }
            '7' { Skip-LayerWorkflowCandidate -Root $Root -State $state }
            '8' { Show-PerformanceLayerMap -Root $Root -State $state }
            'b' { return }
            'B' { return }
            default { Write-Warning 'Unknown layer action.' }
        }
        $state = Get-LayerWorkflowState -Root $Root
    } while ($true)
}

function Invoke-ContextAwareRemeasure {
    param(
        [string]$Root,
        [int]$Seconds,
        [int]$Interval,
        [switch]$SkipTrace
    )

    $state = Get-LayerWorkflowState -Root $Root
    if ($state.activeCandidate) {
        Invoke-LayerRemeasureStep -Root $Root -State $state -Seconds $Seconds -Interval $Interval -SkipTrace:$SkipTrace
        return
    }
    [void](Invoke-Measurement -Kind after -Seconds $Seconds -Interval $Interval -Root $Root -SkipTrace:$SkipTrace)
    Show-MeasurementComparison -Root $Root
}

function Invoke-ContextAwareRevert {
    param(
        [string]$Root,
        [switch]$DryRun
    )

    $state = Get-LayerWorkflowState -Root $Root
    if ($state.activeCandidate) {
        Revert-LayerWorkflowCandidate -Root $Root -State $state -DryRun:$DryRun
        return
    }
    $batchPath = Get-SynergyBatchPath -Root $Root
    if (Test-Path -LiteralPath $batchPath) {
        $batch = Get-Content -LiteralPath $batchPath -Raw | ConvertFrom-Json
        if ($batch.status -eq 'active' -and @($batch.entryIds).Count -gt 0) {
            $log = Get-ChangeLog -Root $Root
            $activeEntries = @($log.entries | Where-Object { $_.status -eq 'applied' })
            $batchIds = @($batch.entryIds | ForEach-Object { [string]$_ })
            $tailIds = @($activeEntries | Select-Object -Last $batchIds.Count | ForEach-Object { [string]$_.id })
            if (($tailIds -join '|') -ne ($batchIds -join '|')) {
                throw 'The latest active changes no longer match the recorded synergy batch. Revert individual changes from newest to oldest.'
            }
            if ($DryRun) {
                Write-Host "Batch revert dry run: UX-ROM would restore $($batchIds.Count) captured changes in reverse order." -ForegroundColor DarkYellow
                return
            }
            for ($index = 0; $index -lt $batchIds.Count; $index++) {
                Invoke-RevertChanges -Root $Root -Confirm:$false
            }
            $batch.status = 'reverted'
            $batch | Add-Member -NotePropertyName revertedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
            $batch | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $batchPath -Encoding UTF8
            Write-StructuredEvent -Root $Root -Level Information -Event 'synergy-batch-reverted' -Data @{ batchId = $batch.batchId; entryIds = $batchIds }
            Write-Host "Reverted and verified the full synergy batch ($($batchIds.Count) changes)." -ForegroundColor Green
            return
        }
    }
    Invoke-RevertChanges -Root $Root -WhatIf:$DryRun
}

function Show-ZBookPerfStatus {
    param([string]$Root)
    Write-Host "$script:ProductName $script:ProductVersion" -ForegroundColor Cyan
    Write-Host "Experiment: $script:ExperimentId" -ForegroundColor Cyan
    Write-Host "Product version: $script:ProductVersion"
    Write-Host "Loaded from: $script:LoadedFrom"
    Write-Host "Data root: $Root"
    Write-Host "Administrator: $(Test-IsAdministrator)"
    $wprState = Get-WprRecordingState
    Write-Host "WPR state: $($wprState.state)"
    if ($wprState.state -eq 'recording') {
        Write-Host (Get-WprBusyGuidance) -ForegroundColor DarkYellow
    }
    $powerSupport = Get-PowerCandidateSupport
    Write-Host "PowerAc support: $($powerSupport.supported)"
    if (-not $powerSupport.supported) {
        Write-Host $powerSupport.reason -ForegroundColor DarkYellow
    }
    $layerState = Get-LayerWorkflowState -Root $Root
    $layer = Get-PerformanceLayer -Number ([int]$layerState.currentLayer)
    Write-Host "Layer workflow: cycle $($layerState.cycleNumber), Layer $($layer.number), phase $($layerState.phase)"
    Write-Host "Layer area: $($layer.name)"
    if ($layerState.activeCandidate) {
        Write-Host "Layer active change: $(Get-CandidateDisplayName -Name ([string]$layerState.activeCandidate))" -ForegroundColor DarkYellow
    }
    $log = Get-ChangeLog -Root $Root
    if (@($log.entries).Count -eq 0) {
        Write-Host 'Recorded changes: none'
    } else {
        $log.entries | Select-Object appliedUtc, candidate, status, rebootRequired | Format-Table -AutoSize | Out-Host
    }
}

function Show-UxRomHeader {
    $logo = @'
   _        _    ____ _  __ ____    _    _   _
  | |      / \  / ___| |/ // ___|  / \  | \ | |
  | |     / _ \| |   | ' / \___ \ / _ \ |  \| |
  | |___ / ___ \ |___| . \  ___) / ___ \| |\  |
  |_____/_/   \_\____|_|\_\|____/_/   \_\_| \_|
'@
    Write-Host $logo -ForegroundColor Gray
    Write-Host '                    U X - R O M' -ForegroundColor Red
    Write-Host 'Windows performance-layer controller  ' -ForegroundColor DarkGray -NoNewline
    Write-Host $script:ProductVersion -ForegroundColor Red
}

function Show-UxRomSplash {
    if ($script:SplashShown) { return }
    $script:SplashShown = $true
    Write-Host ''
    Show-UxRomHeader
    Write-Host 'Loading the twelve performance layers...' -ForegroundColor DarkGray
    Write-Host ''
}

function Show-ZBookPerfMenu {
    Write-Host ''
    Write-Host 'D. Full system diagnostics - one read-only pass across every integrated check' -ForegroundColor White
    Write-Host ''
    foreach ($layer in Get-PerformanceLayerCatalog) {
        Write-Host ("{0,2}. {1}" -f $layer.number, $layer.name) -ForegroundColor White
        Write-Host ("    {0}" -f $layer.description) -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host 'A. Apply all eligible tweaks - one measured, reversible synergy batch' -ForegroundColor Yellow
    Write-Host 'K. Keep the measured layer change and continue'
    Write-Host 'R. Revert the active layer change or latest synergy batch'
    Write-Host 'S. Show workflow, build, WPR, and support status'
    Write-Host 'M. Maintenance and direct measurement tools'
    Write-Host 'Q. Quit'
    return (Read-Host 'Choose diagnostics, a layer, or an action')
}

function Show-ZBookPerfAdvancedMenu {
    Write-Host ''
    Write-Host 'Maintenance and direct measurement tools' -ForegroundColor Cyan
    Write-Host '1. Analyze and capture a baseline'
    Write-Host '2. Live performance watch'
    Write-Host '3. Apply one reversible experiment directly'
    Write-Host '4. Re-measure and compare directly'
    Write-Host '5. Revert the most recent applied change'
    Write-Host '6. Status'
    Write-Host '7. Measure Explorer readiness and shell settings'
    Write-Host '8. Measure a selected application workload'
    Write-Host '9. Measure storage locality and declared network readiness'
    Write-Host '0. Show the detailed capability map'
    Write-Host 'B. Back'
    return (Read-Host 'Choose a maintenance action')
}

function Select-LayerInteractive {
    param([string]$Root)

    $state = Get-LayerWorkflowState -Root $Root
    Show-PerformanceLayerMap -Root $Root -State $state
    $selection = Read-Host 'Choose Layer 1-12'
    $layerNumber = 0
    if (-not [int]::TryParse($selection, [ref]$layerNumber) -or $layerNumber -lt 1 -or $layerNumber -gt 12) {
        Write-Warning 'Choose a layer number from 1 through 12.'
        return $false
    }
    Set-LayerWorkflowCurrentLayer -Root $Root -State $state -Layer $layerNumber
    return $true
}

function Select-CandidateInteractive {
    $powerSupport = Get-PowerCandidateSupport
    if ($powerSupport.supported) {
        Write-Host '1. AC High performance processor policy (Tier 2)'
    } else {
        Write-Host '1. AC High performance processor policy [unsupported on this PC]' -ForegroundColor DarkGray
    }
    Write-Host '2. MMCSS SystemResponsiveness = 10 (Tier 2)'
    Write-Host '3. NTFS DisableLastAccess = 1 (Tier 2, reboot)'
    Write-Host '4. Documented visual-effect APIs (Tier 1)'
    Write-Host '5. Fast Startup diagnostic isolation (Tier 2, diagnostic, reboot)'
    switch (Read-Host 'Choose one candidate') {
        '1' {
            if (-not $powerSupport.supported) {
                Write-Host "Unavailable: $($powerSupport.reason)" -ForegroundColor DarkYellow
                Write-Host 'No setting was changed.' -ForegroundColor DarkYellow
                return $null
            }
            return 'PowerAc'
        }
        '2' { return 'MmcssResponsiveness' }
        '3' { return 'NtfsLastAccess' }
        '4' { return 'VisualEffects' }
        '5' { return 'FastStartupDiagnostic' }
        default { throw 'Unknown candidate selection.' }
    }
}

function Confirm-Tier2Interactive {
    param([string]$Name)

    Write-Host ''
    Write-Warning "'$Name' changes machine-wide Windows state."
    Write-Host 'Continue only on a disposable image or dedicated development system with a tested recovery path.' -ForegroundColor Yellow
    $answer = Read-Host 'Does this machine meet that requirement? [y/N]'
    return ($answer -in @('y', 'Y', 'yes', 'YES', 'Yes'))
}

function Invoke-ZBookPerfMain {
    Show-UxRomSplash

    if ($FullDiagnostics) { $script:Action = 'FullDiagnostics' }
    elseif ($ApplyAll) { $script:Action = 'ApplyAll' }
    elseif ($LayerWorkflow) { $script:Action = 'LayerWorkflow' }
    elseif ($Analyze) { $script:Action = 'Analyze' }
    elseif ($Watch) { $script:Action = 'Watch' }
    elseif ($ThermalProfile) { $script:Action = 'ThermalProfile' }
    elseif ($HardwareProfile) { $script:Action = 'HardwareProfile' }
    elseif ($FirmwareProfile) { $script:Action = 'FirmwareProfile' }
    elseif ($DriverProfile) { $script:Action = 'DriverProfile' }
    elseif ($KernelProfile) { $script:Action = 'KernelProfile' }
    elseif ($ShellProfile) { $script:Action = 'ShellProfile' }
    elseif ($WorkloadProfile) { $script:Action = 'WorkloadProfile' }
    elseif ($DependencyProfile) { $script:Action = 'DependencyProfile' }
    elseif ($Enhance) { $script:Action = 'Enhance' }
    elseif ($Remeasure) { $script:Action = 'Remeasure' }
    elseif ($Revert) { $script:Action = 'Revert' }

    $runtime = New-LayerRuntime `
        -Seconds $DurationSeconds `
        -Interval $SampleIntervalSeconds `
        -SkipTrace:$NoTrace `
        -ThermalCalibration $ThermalCalibrationIterations `
        -HardwareCalibration $HardwareCalibrationIterations `
        -FirmwareCalibration $FirmwareCalibrationIterations `
        -DriverCalibration $DriverCalibrationIterations `
        -DriverLimit $DriverDeviceLimit `
        -KernelBlocks $KernelBlockCount `
        -KernelSamples $KernelSamplesPerBlock `
        -KernelInterval $KernelSampleIntervalSeconds `
        -KernelCalibration $KernelCalibrationIterations `
        -ShellRuns $ShellRunCount `
        -ShellWarmups $ShellWarmupRunCount `
        -ShellTimeout $ShellTimeoutMilliseconds `
        -ShellCalibration $ShellProbeCalibrationIterations `
        -WorkloadNames $WorkloadProcessName `
        -WorkloadInterval $WorkloadSampleIntervalMilliseconds `
        -WorkloadCalibration $WorkloadCalibrationIterations `
        -DependencyPaths $DependencyPath `
        -DependencyEndpoints $DependencyEndpoint `
        -DependencyRuns $DependencyProbeRunCount `
        -DependencyTimeout $DependencyTimeoutMilliseconds `
        -DependencyCalibration $DependencyCalibrationIterations `
        -DryRun:$WhatIfPreference

    do {
        $selectedAction = $script:Action
        if ($selectedAction -eq 'Menu') {
            $menuChoice = Show-ZBookPerfMenu
            $layerChoice = 0
            if ([int]::TryParse($menuChoice, [ref]$layerChoice) -and $layerChoice -ge 1 -and $layerChoice -le 12) {
                $selectedAction = "Layer:$layerChoice"
            } else {
                switch ($menuChoice) {
                'd' { $selectedAction = 'FullDiagnostics' }
                'D' { $selectedAction = 'FullDiagnostics' }
                'a' { $selectedAction = 'ApplyAll' }
                'A' { $selectedAction = 'ApplyAll' }
                'k' { $selectedAction = 'KeepLayerChange' }
                'K' { $selectedAction = 'KeepLayerChange' }
                'r' { $selectedAction = 'Revert' }
                'R' { $selectedAction = 'Revert' }
                's' { $selectedAction = 'Status' }
                'S' { $selectedAction = 'Status' }
                'm' { $selectedAction = 'Advanced' }
                'M' { $selectedAction = 'Advanced' }
                'q' { return }
                'Q' { return }
                default { Write-Warning 'Unknown menu choice.'; continue }
                }
            }
        }

        if ($selectedAction -eq 'Advanced') {
            switch (Show-ZBookPerfAdvancedMenu) {
                '1' { $selectedAction = 'Analyze' }
                '2' { $selectedAction = 'Watch' }
                '3' { $selectedAction = 'Enhance' }
                '4' { $selectedAction = 'Remeasure' }
                '5' { $selectedAction = 'Revert' }
                '6' { $selectedAction = 'Status' }
                '7' { $selectedAction = 'ShellProfile' }
                '8' { $selectedAction = 'WorkloadProfile' }
                '9' { $selectedAction = 'DependencyProfile' }
                '0' { $selectedAction = 'LayerMap' }
                'b' { continue }
                'B' { continue }
                default { Write-Warning 'Unknown advanced choice.'; continue }
            }
        }

        if ($selectedAction -like 'Layer:*') {
            $selectedLayerNumber = [int]($selectedAction.Substring(6))
            Invoke-SelectedPerformanceLayer -Root $DataRoot -LayerNumber $selectedLayerNumber -Runtime $runtime
            if ($script:Action -ne 'Menu') { return }
            continue
        }

        switch ($selectedAction) {
            'FullDiagnostics' {
                [void](Invoke-FullSystemDiagnostics -Root $DataRoot -Runtime $runtime)
            }
            'ApplyAll' {
                [void](Invoke-AllEligibleTweaks `
                    -Root $DataRoot `
                    -Runtime $runtime `
                    -Tier2Confirmed:$LabTier2Confirmed `
                    -DryRun:$WhatIfPreference `
                    -Interactive:($script:Action -eq 'Menu'))
            }
            'KeepLayerChange' {
                $state = Get-LayerWorkflowState -Root $DataRoot
                Complete-LayerWorkflowCandidate -Root $DataRoot -State $state
            }
            'LayerWorkflow' {
                Invoke-LayerWorkflow `
                    -Root $DataRoot `
                    -Seconds $DurationSeconds `
                    -Interval $SampleIntervalSeconds `
                    -SkipTrace:$NoTrace `
                    -ThermalCalibration $ThermalCalibrationIterations `
                    -HardwareCalibration $HardwareCalibrationIterations `
                    -FirmwareCalibration $FirmwareCalibrationIterations `
                    -DriverCalibration $DriverCalibrationIterations `
                    -DriverLimit $DriverDeviceLimit `
                    -KernelBlocks $KernelBlockCount `
                    -KernelSamples $KernelSamplesPerBlock `
                    -KernelInterval $KernelSampleIntervalSeconds `
                    -KernelCalibration $KernelCalibrationIterations `
                    -ShellRuns $ShellRunCount `
                    -ShellWarmups $ShellWarmupRunCount `
                    -ShellTimeout $ShellTimeoutMilliseconds `
                    -ShellCalibration $ShellProbeCalibrationIterations `
                    -WorkloadNames $WorkloadProcessName `
                    -WorkloadInterval $WorkloadSampleIntervalMilliseconds `
                    -WorkloadCalibration $WorkloadCalibrationIterations `
                    -DependencyPaths $DependencyPath `
                    -DependencyEndpoints $DependencyEndpoint `
                    -DependencyRuns $DependencyProbeRunCount `
                    -DependencyTimeout $DependencyTimeoutMilliseconds `
                    -DependencyCalibration $DependencyCalibrationIterations `
                    -DryRun:$WhatIfPreference
            }
            'ChooseLayer' {
                if (Select-LayerInteractive -Root $DataRoot) {
                    Invoke-LayerWorkflow `
                        -Root $DataRoot `
                        -Seconds $DurationSeconds `
                        -Interval $SampleIntervalSeconds `
                        -SkipTrace:$NoTrace `
                        -ThermalCalibration $ThermalCalibrationIterations `
                        -HardwareCalibration $HardwareCalibrationIterations `
                        -FirmwareCalibration $FirmwareCalibrationIterations `
                        -DriverCalibration $DriverCalibrationIterations `
                        -DriverLimit $DriverDeviceLimit `
                        -KernelBlocks $KernelBlockCount `
                        -KernelSamples $KernelSamplesPerBlock `
                        -KernelInterval $KernelSampleIntervalSeconds `
                        -KernelCalibration $KernelCalibrationIterations `
                        -ShellRuns $ShellRunCount `
                        -ShellWarmups $ShellWarmupRunCount `
                        -ShellTimeout $ShellTimeoutMilliseconds `
                        -ShellCalibration $ShellProbeCalibrationIterations `
                        -WorkloadNames $WorkloadProcessName `
                        -WorkloadInterval $WorkloadSampleIntervalMilliseconds `
                        -WorkloadCalibration $WorkloadCalibrationIterations `
                        -DependencyPaths $DependencyPath `
                        -DependencyEndpoints $DependencyEndpoint `
                        -DependencyRuns $DependencyProbeRunCount `
                        -DependencyTimeout $DependencyTimeoutMilliseconds `
                        -DependencyCalibration $DependencyCalibrationIterations `
                        -DryRun:$WhatIfPreference
                }
            }
            'LayerMap' { Show-PerformanceLayerMap -Root $DataRoot }
            'Analyze' {
                [void](Invoke-Measurement -Kind baseline -Seconds $DurationSeconds -Interval $SampleIntervalSeconds -Root $DataRoot -SkipTrace:$NoTrace)
            }
            'Watch' { Invoke-LiveWatch -Interval $SampleIntervalSeconds -MaximumSamples $WatchMaxSamples }
            'ThermalProfile' {
                [void](Invoke-ThermalProfile `
                    -Root $DataRoot `
                    -Seconds $DurationSeconds `
                    -IntervalSeconds $SampleIntervalSeconds `
                    -CalibrationIterations $ThermalCalibrationIterations)
            }
            'HardwareProfile' {
                [void](Invoke-HardwareProfile `
                    -Root $DataRoot `
                    -Seconds $DurationSeconds `
                    -IntervalSeconds $SampleIntervalSeconds `
                    -CalibrationIterations $HardwareCalibrationIterations)
            }
            'FirmwareProfile' {
                [void](Invoke-FirmwareProfile `
                    -Root $DataRoot `
                    -CalibrationIterations $FirmwareCalibrationIterations)
            }
            'DriverProfile' {
                [void](Invoke-DriverProfile `
                    -Root $DataRoot `
                    -CalibrationIterations $DriverCalibrationIterations `
                    -DeviceLimit $DriverDeviceLimit)
            }
            'KernelProfile' {
                [void](Invoke-KernelProfile `
                    -Root $DataRoot `
                    -BlockCount $KernelBlockCount `
                    -SamplesPerBlock $KernelSamplesPerBlock `
                    -SampleIntervalSeconds $KernelSampleIntervalSeconds `
                    -CalibrationIterations $KernelCalibrationIterations)
            }
            'ShellProfile' {
                [void](Invoke-ShellProfile `
                    -Root $DataRoot `
                    -RunCount $ShellRunCount `
                    -WarmupRunCount $ShellWarmupRunCount `
                    -TimeoutMilliseconds $ShellTimeoutMilliseconds `
                    -ProbeCalibrationIterations $ShellProbeCalibrationIterations)
            }
            'WorkloadProfile' {
                [void](Invoke-WorkloadProfile `
                    -Root $DataRoot `
                    -ProcessNames $WorkloadProcessName `
                    -Seconds $DurationSeconds `
                    -IntervalMilliseconds $WorkloadSampleIntervalMilliseconds `
                    -CalibrationIterations $WorkloadCalibrationIterations)
            }
            'DependencyProfile' {
                [void](Invoke-DependencyProfile `
                    -Root $DataRoot `
                    -Paths $DependencyPath `
                    -Endpoints $DependencyEndpoint `
                    -ProbeRunCount $DependencyProbeRunCount `
                    -TimeoutMilliseconds $DependencyTimeoutMilliseconds `
                    -CalibrationIterations $DependencyCalibrationIterations)
            }
            'Enhance' {
                $selectedCandidate = $EnhancementCandidate
                if (-not $selectedCandidate) { $selectedCandidate = Select-CandidateInteractive }
                if (-not $selectedCandidate) { continue }
                $tier2ConfirmedForRun = [bool]$LabTier2Confirmed
                $diagnosticConfirmedForRun = [bool]$Diagnostic
                if (
                    $script:Action -eq 'Menu' -and
                    $selectedCandidate -eq 'FastStartupDiagnostic'
                ) {
                    $diagnosticConfirmedForRun = $true
                    Write-Host 'Diagnostic intent accepted from explicit Fast Startup menu selection.' -ForegroundColor DarkYellow
                }
                if (
                    $script:Action -eq 'Menu' -and
                    $selectedCandidate -in $script:MachineCandidates -and
                    -not $tier2ConfirmedForRun
                ) {
                    $tier2ConfirmedForRun = Confirm-Tier2Interactive -Name $selectedCandidate
                    if (-not $tier2ConfirmedForRun) {
                        Write-Host 'Cancelled. No setting was changed.' -ForegroundColor DarkYellow
                        continue
                    }
                }
                Invoke-Enhancement -Name $selectedCandidate -Root $DataRoot -Tier2Confirmed:$tier2ConfirmedForRun -DiagnosticConfirmed:$diagnosticConfirmedForRun -WhatIf:$WhatIfPreference
            }
            'Remeasure' {
                Invoke-ContextAwareRemeasure `
                    -Root $DataRoot `
                    -Seconds $DurationSeconds `
                    -Interval $SampleIntervalSeconds `
                    -SkipTrace:$NoTrace
            }
            'Revert' { Invoke-ContextAwareRevert -Root $DataRoot -DryRun:$WhatIfPreference }
            'Status' { Show-ZBookPerfStatus -Root $DataRoot }
        }
        if ($script:Action -ne 'Menu') { return }
    } while ($true)
}

if ($MyInvocation.InvocationName -ne '.') {
    # Invoke-Expression does not create the script-level $PSCmdlet variable
    # that a directly invoked advanced script receives. Let PowerShell
    # propagate the original exception so the real failure is not masked.
    Invoke-ZBookPerfMain
}

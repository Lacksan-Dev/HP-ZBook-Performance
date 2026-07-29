#requires -Version 5.1

<#
.SYNOPSIS
    Trace-first HP ZBook performance analyzer and reversible experiment harness.

.DESCRIPTION
    EXP-047 records Windows performance evidence and can apply one supported,
    reversible candidate per invocation. Machine-wide candidates require an
    administrator console and explicit confirmation that the computer is a
    recoverable Tier 2 lab system. The script never applies every candidate as
    a bundle.

    No argument opens the interactive console. Automation can use -Action or
    the equivalent action switches.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Menu', 'Analyze', 'Watch', 'ShellProfile', 'WorkloadProfile', 'Enhance', 'Remeasure', 'Revert', 'Status')]
    [string]$Action = 'Menu',

    [switch]$Analyze,
    [switch]$Watch,
    [switch]$ShellProfile,
    [switch]$WorkloadProfile,
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

    [string]$DataRoot = 'C:\ProgramData\ZBookPerf',

    [switch]$NoTrace,
    [switch]$Diagnostic,
    [switch]$LabTier2Confirmed
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ExperimentId = 'EXP-047'
$script:SchemaVersion = 1
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
    $result = [pscustomobject]@{
        FilePath = $FilePath
        Arguments = $Arguments
        ExitCode = $exitCode
        Output = ($output -join [Environment]::NewLine)
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

function Start-WprCapture {
    param([string]$Root, [string]$Stamp, [switch]$Skip)

    $trace = [ordered]@{ status = 'not-started'; reason = $null; etlPath = $null; csvPath = $null; summaryPath = $null }
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

    $start = Invoke-NativeCommand -FilePath 'wpr.exe' -Arguments @('-start', 'GeneralProfile', '-start', 'CPU', '-start', 'DiskIO', '-filemode') -AllowFailure
    if ($start.ExitCode -ne 0) {
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

function Get-PowerCandidateState {
    $active = Get-PowerSchemeGuid -Output (Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/getactivescheme')).Output
    $schemes = (Invoke-NativeCommand -FilePath 'powercfg.exe' -Arguments @('/list')).Output
    if ($schemes -notmatch [regex]::Escape($script:HighPerformanceScheme)) {
        throw 'The built-in High performance scheme is not available. ZBookPerf will not create an undocumented substitute scheme.'
    }

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

    if (-not $Name) { throw '-Candidate is required for Enhance. ZBookPerf intentionally does not apply a bundle.' }
    $isMachine = $Name -in $script:MachineCandidates
    if ($isMachine -and -not (Test-IsAdministrator)) {
        throw "Candidate '$Name' requires an administrator console."
    }
    if ($isMachine -and -not $Tier2Confirmed) {
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

function Show-ZBookPerfStatus {
    param([string]$Root)
    Write-Host "Experiment: $script:ExperimentId" -ForegroundColor Cyan
    Write-Host "Data root: $Root"
    Write-Host "Administrator: $(Test-IsAdministrator)"
    Write-Host "WPR available: $([bool](Get-Command 'wpr.exe' -ErrorAction SilentlyContinue))"
    $log = Get-ChangeLog -Root $Root
    if (@($log.entries).Count -eq 0) {
        Write-Host 'Recorded changes: none'
    } else {
        $log.entries | Select-Object appliedUtc, candidate, status, rebootRequired | Format-Table -AutoSize | Out-Host
    }
}

function Show-ZBookPerfMenu {
    Write-Host ''
    Write-Host 'ZBookPerf - EXP-047' -ForegroundColor Cyan
    Write-Host '1. Analyze and capture a baseline'
    Write-Host '2. Live performance watch'
    Write-Host '3. Enhance (one candidate only)'
    Write-Host '4. Re-measure and compare'
    Write-Host '5. Revert the most recent applied change'
    Write-Host '6. Status'
    Write-Host '7. Layer 10 shell profile (read-only)'
    Write-Host '8. Layer 11 workload runtime profile (read-only)'
    Write-Host 'Q. Quit'
    return (Read-Host 'Choose an action')
}

function Select-CandidateInteractive {
    Write-Host '1. AC High performance processor policy (Tier 2)'
    Write-Host '2. MMCSS SystemResponsiveness = 10 (Tier 2)'
    Write-Host '3. NTFS DisableLastAccess = 1 (Tier 2, reboot)'
    Write-Host '4. Documented visual-effect APIs (Tier 1)'
    Write-Host '5. Fast Startup diagnostic isolation (Tier 2, diagnostic, reboot)'
    switch (Read-Host 'Choose one candidate') {
        '1' { return 'PowerAc' }
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
    if ($Analyze) { $script:Action = 'Analyze' }
    elseif ($Watch) { $script:Action = 'Watch' }
    elseif ($ShellProfile) { $script:Action = 'ShellProfile' }
    elseif ($WorkloadProfile) { $script:Action = 'WorkloadProfile' }
    elseif ($Enhance) { $script:Action = 'Enhance' }
    elseif ($Remeasure) { $script:Action = 'Remeasure' }
    elseif ($Revert) { $script:Action = 'Revert' }

    do {
        $selectedAction = $script:Action
        if ($selectedAction -eq 'Menu') {
            switch (Show-ZBookPerfMenu) {
                '1' { $selectedAction = 'Analyze' }
                '2' { $selectedAction = 'Watch' }
                '3' { $selectedAction = 'Enhance' }
                '4' { $selectedAction = 'Remeasure' }
                '5' { $selectedAction = 'Revert' }
                '6' { $selectedAction = 'Status' }
                '7' { $selectedAction = 'ShellProfile' }
                '8' { $selectedAction = 'WorkloadProfile' }
                'q' { return }
                'Q' { return }
                default { Write-Warning 'Unknown menu choice.'; continue }
            }
        }

        switch ($selectedAction) {
            'Analyze' {
                [void](Invoke-Measurement -Kind baseline -Seconds $DurationSeconds -Interval $SampleIntervalSeconds -Root $DataRoot -SkipTrace:$NoTrace)
            }
            'Watch' { Invoke-LiveWatch -Interval $SampleIntervalSeconds -MaximumSamples $WatchMaxSamples }
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
            'Enhance' {
                $selectedCandidate = $EnhancementCandidate
                if (-not $selectedCandidate) { $selectedCandidate = Select-CandidateInteractive }
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
                [void](Invoke-Measurement -Kind after -Seconds $DurationSeconds -Interval $SampleIntervalSeconds -Root $DataRoot -SkipTrace:$NoTrace)
                Show-MeasurementComparison -Root $DataRoot
            }
            'Revert' { Invoke-RevertChanges -Root $DataRoot -WhatIf:$WhatIfPreference }
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

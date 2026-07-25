[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Check','DryRun','Capture','Verify','Rollback')]
    [string]$Action = 'Check',

    [ValidateSet('SignIn','OutlookCold','OutlookWarm','OutlookSearch','EdgeCold','EdgeInteraction','WindowsSearch','ResumeNetwork','Idle')]
    [string]$Workflow = 'Idle',

    [string]$OutputRoot = (Join-Path $PSScriptRoot 'output'),
    [string]$RunId = (Get-Date -Format 'yyyyMMdd-HHmmss'),
    [switch]$AllowNonHpLabHost
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ExpLog {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('Information','Warning','Error')][string]$Level,
        [Parameter(Mandatory)][string]$Event,
        [Parameter(Mandatory)][hashtable]$Data
    )

    $record = [ordered]@{
        TimestampUtc = [DateTime]::UtcNow.ToString('o')
        Level        = $Level
        Event        = $Event
        Data         = $Data
    }
    $record | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Get-RegistryValueState {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{ Path=$Path; Name=$Name; KeyExists=$false; ValueExists=$false; Type=$null; Value=$null }
    }
    $key = Get-Item -LiteralPath $Path
    $names = @($key.GetValueNames())
    if ($names -notcontains $Name) {
        return [ordered]@{ Path=$Path; Name=$Name; KeyExists=$true; ValueExists=$false; Type=$null; Value=$null }
    }
    [ordered]@{
        Path=$Path
        Name=$Name
        KeyExists=$true
        ValueExists=$true
        Type=$key.GetValueKind($Name).ToString()
        Value=$key.GetValue($Name,$null,'DoNotExpandEnvironmentNames')
    }
}

function Get-FileHashRecord {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    [ordered]@{ Path=(Resolve-Path -LiteralPath $Path).Path; Algorithm='SHA256'; Hash=$hash.Hash }
}

function Get-Exp001Support {
    [CmdletBinding()]
    param([switch]$AllowNonHpLabHost)

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $product = Get-CimInstance Win32_ComputerSystemProduct
    $bios = Get-CimInstance Win32_BIOS
    $isWindows = $env:OS -eq 'Windows_NT'
    $isWindows11 = $isWindows -and ([version]$os.Version).Build -ge 22000
    $isHp = $cs.Manufacturer -match 'HP|Hewlett-Packard'
    $isZBook = ($cs.Model -match 'ZBook') -or ($product.Name -match 'ZBook')
    $supported = $isWindows11 -and (($isHp -and $isZBook) -or $AllowNonHpLabHost)

    [ordered]@{
        Supported=$supported
        Windows=$isWindows
        Windows11OrLater=$isWindows11
        HpManufacturer=$isHp
        ZBookModel=$isZBook
        AllowNonHpLabHost=[bool]$AllowNonHpLabHost
        Manufacturer=$cs.Manufacturer
        Model=$cs.Model
        ProductName=$product.Name
        BiosVersion=($bios.SMBIOSBIOSVersion -join ',')
        OsCaption=$os.Caption
        OsVersion=$os.Version
        OsBuild=$os.BuildNumber
    }
}

function Get-Exp001Inventory {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor
    $bios = Get-CimInstance Win32_BIOS
    $disks = @(Get-CimInstance Win32_DiskDrive | Select-Object Model,FirmwareRevision,Size,InterfaceType,SerialNumber)
    $gpus = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM)
    $nics = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' | Select-Object Description,MACAddress,IPAddress,DefaultIPGateway,DHCPEnabled)
    $services = @('WSearch','WinDefend','wuauserv','DoSvc','OneSyncSvc') | ForEach-Object {
        $service = Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($service) { [ordered]@{ Name=$service.Name; Status=$service.Status.ToString(); StartType=$service.StartType.ToString() } }
    }
    $processes = @('OUTLOOK','msedge','OneDrive','ms-teams','Teams') | ForEach-Object {
        $items = @(Get-Process -Name $_ -ErrorAction SilentlyContinue)
        [ordered]@{ Name=$_; Count=$items.Count; Ids=@($items.Id) }
    }

    $power = (& powercfg /getactivescheme 2>&1 | Out-String).Trim()
    $sleep = (& powercfg /a 2>&1 | Out-String).Trim()

    [ordered]@{
        CapturedUtc=[DateTime]::UtcNow.ToString('o')
        ComputerName=$env:COMPUTERNAME
        UserName=$env:USERNAME
        Os=[ordered]@{ Caption=$os.Caption; Version=$os.Version; Build=$os.BuildNumber; Architecture=$os.OSArchitecture; InstallDate=$os.InstallDate }
        Computer=[ordered]@{ Manufacturer=$cs.Manufacturer; Model=$cs.Model; MemoryBytes=[int64]$cs.TotalPhysicalMemory; Domain=$cs.Domain; PartOfDomain=[bool]$cs.PartOfDomain }
        Cpu=@($cpu | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed)
        Bios=[ordered]@{ Version=($bios.SMBIOSBIOSVersion -join ','); ReleaseDate=$bios.ReleaseDate; SerialNumber=$bios.SerialNumber }
        Disks=$disks
        Gpus=$gpus
        Network=$nics
        Services=$services
        Processes=$processes
        PowerScheme=$power
        SupportedSleepStates=$sleep
        SecureBoot=(try { Confirm-SecureBootUEFI } catch { $null })
        Defender=(try { Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion } catch { $null })
        BitLocker=(try { Get-BitLockerVolume | Select-Object MountPoint,VolumeStatus,ProtectionStatus,EncryptionMethod } catch { $null })
    }
}

function Get-Exp001OriginalState {
    [CmdletBinding()]
    param()

    $tempTask = Get-ScheduledTask -TaskName 'Lacksan-EXP001-*' -ErrorAction SilentlyContinue
    $wpr = @(Get-Process -Name wpr,wprui -ErrorAction SilentlyContinue | Select-Object Name,Id,StartTime)
    [ordered]@{
        CapturedUtc=[DateTime]::UtcNow.ToString('o')
        TemporaryTasks=@($tempTask | Select-Object TaskName,TaskPath,State)
        WprProcesses=$wpr
        Environment=[ordered]@{
            TEMP=$env:TEMP
            TMP=$env:TMP
        }
        Registry=@(
            Get-RegistryValueState -Path 'HKCU:\Environment' -Name 'LACKSAN_EXP001_RUN'
        )
    }
}

function Test-Exp001Prerequisites {
    [CmdletBinding()]
    param([switch]$AllowNonHpLabHost,[Parameter(Mandatory)][string]$OutputRoot)

    $support = Get-Exp001Support -AllowNonHpLabHost:$AllowNonHpLabHost
    $drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot((Resolve-Path -LiteralPath (Split-Path -Parent $OutputRoot) -ErrorAction SilentlyContinue).Path).TrimEnd(':','\')) -ErrorAction SilentlyContinue
    $free = if ($drive) { [int64]$drive.Free } else { $null }
    $checks = [ordered]@{
        SupportedPlatform=[bool]$support.Supported
        PowerCfgAvailable=[bool](Get-Command powercfg.exe -ErrorAction SilentlyContinue)
        CimAvailable=[bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
        HashingAvailable=[bool](Get-Command Get-FileHash -ErrorAction SilentlyContinue)
        OutputParentExists=[bool](Test-Path -LiteralPath (Split-Path -Parent $OutputRoot))
        FreeBytes=$free
        MinimumFreeBytes=1073741824
        StorageReady=($null -eq $free -or $free -ge 1073741824)
    }
    [ordered]@{ Passed=($checks.SupportedPlatform -and $checks.PowerCfgAvailable -and $checks.CimAvailable -and $checks.HashingAvailable -and $checks.OutputParentExists -and $checks.StorageReady); Support=$support; Checks=$checks }
}

function New-Exp001RunDirectory {
    param([Parameter(Mandatory)][string]$OutputRoot,[Parameter(Mandatory)][string]$RunId)
    $path = Join-Path $OutputRoot $RunId
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Save-JsonFile {
    param([Parameter(Mandatory)]$InputObject,[Parameter(Mandatory)][string]$Path)
    $InputObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-Exp001Capture {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory)][string]$Workflow,
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][string]$RunId,
        [switch]$AllowNonHpLabHost,
        [switch]$DryRun
    )

    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    $runPath = New-Exp001RunDirectory -OutputRoot $OutputRoot -RunId $RunId
    $logPath = Join-Path $runPath 'events.jsonl'
    $prereq = Test-Exp001Prerequisites -AllowNonHpLabHost:$AllowNonHpLabHost -OutputRoot $OutputRoot
    $plan = [ordered]@{
        Experiment='EXP-001'
        Workflow=$Workflow
        RunId=$RunId
        DryRun=[bool]$DryRun
        Commands=@('Get-CimInstance','Get-Service','Get-Process','powercfg /getactivescheme','powercfg /a','Get-MpComputerStatus','Get-BitLockerVolume')
        TemporaryResources=@()
        OutputPath=$runPath
        ResetRequired='Defined externally by experiments/EXP-001/experiment-protocol.md'
    }
    Save-JsonFile -InputObject $plan -Path (Join-Path $runPath 'plan.json')
    Write-ExpLog -Path $logPath -Level Information -Event 'PrerequisiteCheck' -Data @{ Passed=$prereq.Passed; Workflow=$Workflow }

    if (-not $prereq.Passed) {
        Save-JsonFile -InputObject $prereq -Path (Join-Path $runPath 'prerequisites.json')
        throw 'EXP-001 prerequisite checks failed.'
    }

    if ($DryRun) {
        Save-JsonFile -InputObject $prereq -Path (Join-Path $runPath 'prerequisites.json')
        $manifest = [ordered]@{ Experiment='EXP-001'; Workflow=$Workflow; RunId=$RunId; Classification='dry-run'; StartedUtc=[DateTime]::UtcNow.ToString('o'); CompletedUtc=[DateTime]::UtcNow.ToString('o'); Files=@() }
        Save-JsonFile -InputObject $manifest -Path (Join-Path $runPath 'manifest.json')
        return $runPath
    }

    $original = Get-Exp001OriginalState
    $inventory = Get-Exp001Inventory
    Save-JsonFile -InputObject $prereq -Path (Join-Path $runPath 'prerequisites.json')
    Save-JsonFile -InputObject $original -Path (Join-Path $runPath 'original-state.json')
    Save-JsonFile -InputObject $inventory -Path (Join-Path $runPath 'inventory.json')

    $started = [DateTime]::UtcNow
    $sample = switch ($Workflow) {
        'Idle' {
            $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 30
            [ordered]@{ CounterPath='\Processor(_Total)\% Processor Time'; Samples=@($cpu.CounterSamples | Select-Object Timestamp,CookedValue) }
        }
        default {
            [ordered]@{ Marker='HarnessReady'; Message='Workflow-specific start/readiness markers require the approved lab probe and operator procedure.' }
        }
    }
    $completed = [DateTime]::UtcNow
    Save-JsonFile -InputObject $sample -Path (Join-Path $runPath 'sample.json')

    $manifest = [ordered]@{
        Experiment='EXP-001'
        Workflow=$Workflow
        RunId=$RunId
        Classification='screening'
        StartedUtc=$started.ToString('o')
        CompletedUtc=$completed.ToString('o')
        ElapsedMilliseconds=[math]::Round(($completed-$started).TotalMilliseconds,3)
        FormalEvidence=$false
        FormalEvidenceReason='Workflow-specific deterministic readiness probes and protocol lock require independent lab qualification.'
        Files=@()
    }
    Save-JsonFile -InputObject $manifest -Path (Join-Path $runPath 'manifest.json')

    $files = Get-ChildItem -LiteralPath $runPath -File | Where-Object Name -ne 'manifest.json' | ForEach-Object { Get-FileHashRecord -Path $_.FullName }
    $manifest.Files=@($files)
    Save-JsonFile -InputObject $manifest -Path (Join-Path $runPath 'manifest.json')
    Write-ExpLog -Path $logPath -Level Information -Event 'CaptureComplete' -Data @{ Workflow=$Workflow; Classification=$manifest.Classification }
    return $runPath
}

function Test-Exp001Run {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RunPath)

    $required = @('plan.json','prerequisites.json','manifest.json','events.jsonl')
    $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $RunPath $_)) })
    $manifestPath = Join-Path $RunPath 'manifest.json'
    $manifest = if (Test-Path -LiteralPath $manifestPath) { Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } else { $null }
    $hashFailures = @()
    if ($manifest -and $manifest.Files) {
        foreach ($file in $manifest.Files) {
            if (-not (Test-Path -LiteralPath $file.Path)) { $hashFailures += "Missing:$($file.Path)"; continue }
            $actual = (Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash
            if ($actual -ne $file.Hash) { $hashFailures += "HashMismatch:$($file.Path)" }
        }
    }
    [ordered]@{ Passed=($missing.Count -eq 0 -and $hashFailures.Count -eq 0 -and $null -ne $manifest); MissingFiles=$missing; HashFailures=$hashFailures; Classification=$manifest.Classification }
}

function Invoke-Exp001Rollback {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)][string]$RunPath)

    $originalPath = Join-Path $RunPath 'original-state.json'
    if (-not (Test-Path -LiteralPath $originalPath)) {
        return [ordered]@{ Passed=$true; ChangedResources=0; Message='No temporary resources or captured mutable state were present.' }
    }
    $original = Get-Content -LiteralPath $originalPath -Raw | ConvertFrom-Json
    $current = Get-Exp001OriginalState
    $differences = @()
    if (($current.TemporaryTasks | ConvertTo-Json -Depth 6 -Compress) -ne ($original.TemporaryTasks | ConvertTo-Json -Depth 6 -Compress)) { $differences += 'TemporaryTasks' }
    if (($current.Registry | ConvertTo-Json -Depth 6 -Compress) -ne ($original.Registry | ConvertTo-Json -Depth 6 -Compress)) { $differences += 'Registry' }
    [ordered]@{ Passed=($differences.Count -eq 0); ChangedResources=0; Differences=$differences; Message='The baseline harness creates no persistent system resources.' }
}

try {
    switch ($Action) {
        'Check' {
            $result = Test-Exp001Prerequisites -AllowNonHpLabHost:$AllowNonHpLabHost -OutputRoot $OutputRoot
            $result | ConvertTo-Json -Depth 10
            if (-not $result.Passed) { exit 2 }
        }
        'DryRun' {
            Invoke-Exp001Capture -Workflow $Workflow -OutputRoot $OutputRoot -RunId $RunId -AllowNonHpLabHost:$AllowNonHpLabHost -DryRun | Write-Output
        }
        'Capture' {
            Invoke-Exp001Capture -Workflow $Workflow -OutputRoot $OutputRoot -RunId $RunId -AllowNonHpLabHost:$AllowNonHpLabHost | Write-Output
        }
        'Verify' {
            $path = Join-Path $OutputRoot $RunId
            $result = Test-Exp001Run -RunPath $path
            $result | ConvertTo-Json -Depth 10
            if (-not $result.Passed) { exit 3 }
        }
        'Rollback' {
            $path = Join-Path $OutputRoot $RunId
            $result = Invoke-Exp001Rollback -RunPath $path
            $result | ConvertTo-Json -Depth 10
            if (-not $result.Passed) { exit 4 }
        }
    }
}
catch {
    $errorRecord = [ordered]@{ TimestampUtc=[DateTime]::UtcNow.ToString('o'); Action=$Action; Workflow=$Workflow; RunId=$RunId; Error=$_.Exception.Message; Category=$_.CategoryInfo.Category.ToString() }
    $errorRecord | ConvertTo-Json -Depth 6 | Write-Error
    exit 1
}

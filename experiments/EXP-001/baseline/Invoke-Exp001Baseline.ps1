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

function Save-JsonFile {
    param([Parameter(Mandatory)]$InputObject,[Parameter(Mandatory)][string]$Path)
    $InputObject | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-ExpLog {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Event,[Parameter(Mandatory)][hashtable]$Data,[ValidateSet('Information','Warning','Error')][string]$Level='Information')
    [ordered]@{ TimestampUtc=[DateTime]::UtcNow.ToString('o'); Level=$Level; Event=$Event; Data=$Data } |
        ConvertTo-Json -Depth 8 -Compress |
        Add-Content -LiteralPath $Path -Encoding UTF8
}

function Get-RegistryValueState {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) {
        return [ordered]@{ Path=$Path; Name=$Name; KeyExists=$false; ValueExists=$false; Type=$null; Value=$null }
    }
    $key = Get-Item -LiteralPath $Path
    if (@($key.GetValueNames()) -notcontains $Name) {
        return [ordered]@{ Path=$Path; Name=$Name; KeyExists=$true; ValueExists=$false; Type=$null; Value=$null }
    }
    [ordered]@{ Path=$Path; Name=$Name; KeyExists=$true; ValueExists=$true; Type=$key.GetValueKind($Name).ToString(); Value=$key.GetValue($Name,$null,'DoNotExpandEnvironmentNames') }
}

function Get-FileHashRecord {
    param([Parameter(Mandatory)][string]$Path)
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
    $runningOnWindows = $env:OS -eq 'Windows_NT'
    $windows11OrLater = $runningOnWindows -and ([version]$os.Version).Build -ge 22000
    $hpManufacturer = $cs.Manufacturer -match 'HP|Hewlett-Packard'
    $zBookModel = ($cs.Model -match 'ZBook') -or ($product.Name -match 'ZBook')
    $supported = $windows11OrLater -and (($hpManufacturer -and $zBookModel) -or $AllowNonHpLabHost)

    [ordered]@{
        Supported=$supported
        Windows=$runningOnWindows
        Windows11OrLater=$windows11OrLater
        HpManufacturer=$hpManufacturer
        ZBookModel=$zBookModel
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
    $cpu = @(Get-CimInstance Win32_Processor | Select-Object Name,Manufacturer,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed)
    $bios = Get-CimInstance Win32_BIOS
    $disks = @(Get-CimInstance Win32_DiskDrive | Select-Object Model,FirmwareRevision,Size,InterfaceType,SerialNumber)
    $gpus = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM)
    $nics = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' | Select-Object Description,MACAddress,IPAddress,DefaultIPGateway,DHCPEnabled)
    $services = @('WSearch','WinDefend','wuauserv','DoSvc') | ForEach-Object {
        $service = Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($service) { [ordered]@{ Name=$service.Name; Status=$service.Status.ToString(); StartType=$service.StartType.ToString() } }
    }
    $processes = @('OUTLOOK','msedge','OneDrive','ms-teams','Teams') | ForEach-Object {
        $items = @(Get-Process -Name $_ -ErrorAction SilentlyContinue)
        [ordered]@{ Name=$_; Count=$items.Count; Ids=@($items.Id) }
    }

    [ordered]@{
        CapturedUtc=[DateTime]::UtcNow.ToString('o')
        ComputerName=$env:COMPUTERNAME
        UserName=$env:USERNAME
        Os=[ordered]@{ Caption=$os.Caption; Version=$os.Version; Build=$os.BuildNumber; Architecture=$os.OSArchitecture; InstallDate=$os.InstallDate }
        Computer=[ordered]@{ Manufacturer=$cs.Manufacturer; Model=$cs.Model; MemoryBytes=[int64]$cs.TotalPhysicalMemory; Domain=$cs.Domain; PartOfDomain=[bool]$cs.PartOfDomain }
        Cpu=$cpu
        Bios=[ordered]@{ Version=($bios.SMBIOSBIOSVersion -join ','); ReleaseDate=$bios.ReleaseDate; SerialNumber=$bios.SerialNumber }
        Disks=$disks
        Gpus=$gpus
        Network=$nics
        Services=@($services)
        Processes=@($processes)
        PowerScheme=((& powercfg /getactivescheme 2>&1 | Out-String).Trim())
        SupportedSleepStates=((& powercfg /a 2>&1 | Out-String).Trim())
        SecureBoot=(try { Confirm-SecureBootUEFI } catch { $null })
        Defender=(try { Get-MpComputerStatus | Select-Object AMServiceEnabled,AntivirusEnabled,RealTimeProtectionEnabled,AntivirusSignatureVersion } catch { $null })
        BitLocker=(try { Get-BitLockerVolume | Select-Object MountPoint,VolumeStatus,ProtectionStatus,EncryptionMethod } catch { $null })
    }
}

function Get-Exp001OriginalState {
    [CmdletBinding()]
    param()

    [ordered]@{
        CapturedUtc=[DateTime]::UtcNow.ToString('o')
        TemporaryTasks=@(Get-ScheduledTask -TaskName 'Lacksan-EXP001-*' -ErrorAction SilentlyContinue | Select-Object TaskName,TaskPath,State)
        WprProcesses=@(Get-Process -Name wpr,wprui -ErrorAction SilentlyContinue | Select-Object Name,Id,StartTime)
        Environment=[ordered]@{ TEMP=$env:TEMP; TMP=$env:TMP }
        Registry=@(Get-RegistryValueState -Path 'HKCU:\Environment' -Name 'LACKSAN_EXP001_RUN')
    }
}

function Test-Exp001Prerequisites {
    [CmdletBinding()]
    param([switch]$AllowNonHpLabHost,[Parameter(Mandatory)][string]$OutputRoot)

    $parent = Split-Path -Parent $OutputRoot
    if ([string]::IsNullOrWhiteSpace($parent)) { $parent = (Get-Location).Path }
    $support = Get-Exp001Support -AllowNonHpLabHost:$AllowNonHpLabHost
    $checks = [ordered]@{
        SupportedPlatform=[bool]$support.Supported
        PowerCfgAvailable=[bool](Get-Command powercfg.exe -ErrorAction SilentlyContinue)
        CimAvailable=[bool](Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
        HashingAvailable=[bool](Get-Command Get-FileHash -ErrorAction SilentlyContinue)
        OutputParentExists=[bool](Test-Path -LiteralPath $parent)
    }
    [ordered]@{ Passed=($checks.SupportedPlatform -and $checks.PowerCfgAvailable -and $checks.CimAvailable -and $checks.HashingAvailable -and $checks.OutputParentExists); Support=$support; Checks=$checks }
}

function New-Exp001RunDirectory {
    param([Parameter(Mandatory)][string]$OutputRoot,[Parameter(Mandatory)][string]$RunId)
    $path = Join-Path $OutputRoot $RunId
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $path
}

function Invoke-Exp001Capture {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Workflow,[Parameter(Mandatory)][string]$OutputRoot,[Parameter(Mandatory)][string]$RunId,[switch]$AllowNonHpLabHost,[switch]$DryRun)

    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    $runPath = New-Exp001RunDirectory -OutputRoot $OutputRoot -RunId $RunId
    $logPath = Join-Path $runPath 'events.jsonl'
    $prerequisites = Test-Exp001Prerequisites -AllowNonHpLabHost:$AllowNonHpLabHost -OutputRoot $OutputRoot
    $plan = [ordered]@{
        Experiment='EXP-001'; Workflow=$Workflow; RunId=$RunId; DryRun=[bool]$DryRun
        Commands=@('Get-CimInstance','Get-Service','Get-Process','powercfg /getactivescheme','powercfg /a','Get-MpComputerStatus','Get-BitLockerVolume')
        TemporaryResources=@(); OutputPath=$runPath
        ResetRequired='Defined by experiments/EXP-001/experiment-protocol.md'
    }
    Save-JsonFile $plan (Join-Path $runPath 'plan.json')
    Save-JsonFile $prerequisites (Join-Path $runPath 'prerequisites.json')
    Write-ExpLog -Path $logPath -Event 'PrerequisiteCheck' -Data @{ Passed=$prerequisites.Passed; Workflow=$Workflow }

    if (-not $prerequisites.Passed) { throw 'EXP-001 prerequisite checks failed.' }

    if ($DryRun) {
        Save-JsonFile ([ordered]@{ Experiment='EXP-001'; Workflow=$Workflow; RunId=$RunId; Classification='dry-run'; StartedUtc=[DateTime]::UtcNow.ToString('o'); CompletedUtc=[DateTime]::UtcNow.ToString('o'); Files=@() }) (Join-Path $runPath 'manifest.json')
        return $runPath
    }

    Save-JsonFile (Get-Exp001OriginalState) (Join-Path $runPath 'original-state.json')
    Save-JsonFile (Get-Exp001Inventory) (Join-Path $runPath 'inventory.json')
    $started = [DateTime]::UtcNow
    $sample = if ($Workflow -eq 'Idle') {
        $counter = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3
        [ordered]@{ CounterPath='\Processor(_Total)\% Processor Time'; Samples=@($counter.CounterSamples | Select-Object Timestamp,CookedValue) }
    } else {
        [ordered]@{ Marker='HarnessReady'; Message='A deterministic workflow-specific readiness probe remains required before formal evidence collection.' }
    }
    $completed = [DateTime]::UtcNow
    Save-JsonFile $sample (Join-Path $runPath 'sample.json')

    $manifest = [ordered]@{
        Experiment='EXP-001'; Workflow=$Workflow; RunId=$RunId; Classification='screening'
        StartedUtc=$started.ToString('o'); CompletedUtc=$completed.ToString('o')
        ElapsedMilliseconds=[math]::Round(($completed-$started).TotalMilliseconds,3)
        FormalEvidence=$false
        FormalEvidenceReason='Deterministic readiness probes and instrumentation-overhead qualification remain pending.'
        Files=@()
    }
    Save-JsonFile $manifest (Join-Path $runPath 'manifest.json')
    $manifest.Files = @(Get-ChildItem -LiteralPath $runPath -File | Where-Object Name -ne 'manifest.json' | ForEach-Object { Get-FileHashRecord $_.FullName })
    Save-JsonFile $manifest (Join-Path $runPath 'manifest.json')
    Write-ExpLog -Path $logPath -Event 'CaptureComplete' -Data @{ Workflow=$Workflow; Classification='screening' }
    $runPath
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
            if ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ne $file.Hash) { $hashFailures += "HashMismatch:$($file.Path)" }
        }
    }
    [ordered]@{ Passed=($missing.Count -eq 0 -and $hashFailures.Count -eq 0 -and $null -ne $manifest); MissingFiles=$missing; HashFailures=$hashFailures; Classification=if($manifest){$manifest.Classification}else{$null} }
}

function Invoke-Exp001Rollback {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RunPath)

    $originalPath = Join-Path $RunPath 'original-state.json'
    if (-not (Test-Path -LiteralPath $originalPath)) { return [ordered]@{ Passed=$true; ChangedResources=0; Differences=@(); Message='No captured mutable state was present.' } }
    $original = Get-Content -LiteralPath $originalPath -Raw | ConvertFrom-Json
    $current = Get-Exp001OriginalState
    $differences = @()
    if (($current.TemporaryTasks | ConvertTo-Json -Depth 6 -Compress) -ne ($original.TemporaryTasks | ConvertTo-Json -Depth 6 -Compress)) { $differences += 'TemporaryTasks' }
    if (($current.Registry | ConvertTo-Json -Depth 6 -Compress) -ne ($original.Registry | ConvertTo-Json -Depth 6 -Compress)) { $differences += 'Registry' }
    [ordered]@{ Passed=($differences.Count -eq 0); ChangedResources=0; Differences=$differences; Message='The harness creates no persistent system resources.' }
}

try {
    switch ($Action) {
        'Check' {
            $result = Test-Exp001Prerequisites -AllowNonHpLabHost:$AllowNonHpLabHost -OutputRoot $OutputRoot
            $result | ConvertTo-Json -Depth 10
            if (-not $result.Passed) { exit 2 }
        }
        'DryRun' { Invoke-Exp001Capture -Workflow $Workflow -OutputRoot $OutputRoot -RunId $RunId -AllowNonHpLabHost:$AllowNonHpLabHost -DryRun }
        'Capture' { Invoke-Exp001Capture -Workflow $Workflow -OutputRoot $OutputRoot -RunId $RunId -AllowNonHpLabHost:$AllowNonHpLabHost }
        'Verify' {
            $result = Test-Exp001Run -RunPath (Join-Path $OutputRoot $RunId)
            $result | ConvertTo-Json -Depth 10
            if (-not $result.Passed) { exit 3 }
        }
        'Rollback' {
            $result = Invoke-Exp001Rollback -RunPath (Join-Path $OutputRoot $RunId)
            $result | ConvertTo-Json -Depth 10
            if (-not $result.Passed) { exit 4 }
        }
    }
}
catch {
    [ordered]@{ TimestampUtc=[DateTime]::UtcNow.ToString('o'); Action=$Action; Workflow=$Workflow; RunId=$RunId; Error=$_.Exception.Message; Category=$_.CategoryInfo.Category.ToString() } |
        ConvertTo-Json -Depth 6 |
        Write-Error
    exit 1
}

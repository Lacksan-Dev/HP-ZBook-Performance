#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Apply','Rollback')]
    [string]$Action = 'Apply',
    [string]$Root = 'C:\ProgramData\ZBookPerf\performance-tuning',
    [bool]$IncludeOmnissaRedirection = $false,
    [bool]$IncludeCoworkService = $false,
    [bool]$SkipHpDriverUpdates = $false,
    [bool]$AllowAutomaticReboot = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SchemaVersion = 1
$script:Operation = 'UX-ROM-Performance-Tuning'
$script:PointerPath = Join-Path $Root 'active-state.json'
$script:LogPath = Join-Path $Root 'events.jsonl'
$script:BestPerformanceMode = [guid]'ded574b5-45a0-4f42-8737-46345c09c238'
$script:RunRegistryPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
$script:ProtectedServiceNames = @(
    'WinDefend','MDCoreSvc','SecurityHealthService','mpssvc',
    'Audiosrv','AudioEndpointBuilder','RtkAudioUniversalService',
    'Tailscale','client_service','ftnlsv3hv','OmnKsmNotifier','ws1etlm'
)
$script:OmnissaRedirectionServices = @('ftscanmgrhv','hznsprrdpwks','USBArbService')
$script:CoworkServices = @('CoworkVMService')

function Write-Event {
    param([string]$Event,[string]$Result,[object]$Data)
    if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
    [ordered]@{
        schemaVersion = $script:SchemaVersion
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        operation = $script:Operation
        action = $Action
        event = $Event
        result = $Result
        data = $Data
    } | ConvertTo-Json -Depth 16 -Compress | Add-Content -LiteralPath $script:LogPath -Encoding UTF8
}

function Write-JsonFile {
    param([string]$Path,[object]$Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporary = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Invoke-Native {
    param([string]$FilePath,[string[]]$Arguments,[int[]]$AllowedExitCodes = @(0))
    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $text = @($output | ForEach-Object {
        if ($_ -is [Management.Automation.ErrorRecord] -and $_.Exception) { $_.Exception.Message } else { [string]$_ }
    }) -join [Environment]::NewLine
    if ($exitCode -notin $AllowedExitCodes) { throw "$FilePath exited with code $exitCode. $text" }
    [pscustomobject]@{ ExitCode=$exitCode; Output=$text }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $product = Get-CimInstance Win32_ComputerSystemProduct
    $enclosures = @(Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue)
    $portableTypes = @(8,9,10,14,30,31,32)
    $portable = @($enclosures | Where-Object { @($_.ChassisTypes | Where-Object { [int]$_ -in $portableTypes }).Count -gt 0 }).Count -gt 0
    $reasons = @()
    if ([string]$os.Caption -notmatch 'Windows 11') { $reasons += 'Windows 11 is required.' }
    if ([string]$computer.Manufacturer -notmatch '(?i)^HP$|Hewlett-Packard') { $reasons += 'HP hardware is required.' }
    if ([string]$computer.Model -notmatch '(?i)ZBook\s+Firefly\s+14.*G8') { $reasons += 'HP ZBook Firefly 14 G8 model identity is required.' }
    if (-not $portable) { $reasons += 'A portable chassis was not detected.' }
    if (-not (Test-IsAdministrator)) { $reasons += 'An elevated PowerShell session is required.' }
    [pscustomobject][ordered]@{
        Supported = ($reasons.Count -eq 0)
        Reasons = @($reasons)
        Windows = [string]$os.Caption
        Build = [string]$os.BuildNumber
        Manufacturer = [string]$computer.Manufacturer
        Model = [string]$computer.Model
        Portable = [bool]$portable
        Elevated = [bool](Test-IsAdministrator)
        MachineUuid = [string]$product.UUID
    }
}

function Assert-Supported {
    param([object]$Support)
    if (-not $Support.Supported) { throw ($Support.Reasons -join ' ') }
}

function Get-ServiceRecord {
    param([string]$Name)
    $service = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $service) { return $null }
    $delayed = $false
    $delayedExists = $false
    $serviceRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (Test-Path -LiteralPath $serviceRegistryPath) {
        $serviceKey = Get-Item -LiteralPath $serviceRegistryPath
        $delayedExists = $serviceKey.GetValueNames() -contains 'DelayedAutoStart'
        if ($delayedExists) {
            $delayedValue = $serviceKey.GetValue('DelayedAutoStart',$null)
            $delayed = ([int]$delayedValue -eq 1)
        }
    }
    [pscustomobject][ordered]@{
        Name = [string]$service.Name
        DisplayName = [string]$service.DisplayName
        StartMode = [string]$service.StartMode
        DelayedAutoStart = [bool]$delayed
        DelayedAutoStartExists = [bool]$delayedExists
        State = [string]$service.State
        PathName = [string]$service.PathName
    }
}

function Get-ProtectedSnapshot {
    $services = @($script:ProtectedServiceNames | ForEach-Object { Get-ServiceRecord -Name $_ } | Where-Object { $null -ne $_ } | Sort-Object Name)
    $problemDevices = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $null -ne $_.ConfigManagerErrorCode -and [int]$_.ConfigManagerErrorCode -ne 0 })
    [pscustomobject][ordered]@{
        Services = @($services | ForEach-Object {
            [pscustomobject][ordered]@{ Name=$_.Name; StartMode=$_.StartMode; DelayedAutoStart=$_.DelayedAutoStart; DelayedAutoStartExists=$_.DelayedAutoStartExists; PathName=$_.PathName }
        })
        ProblemDeviceCount = $problemDevices.Count
    }
}

function Test-ProtectedEquivalent {
    param([object]$Before,[object]$After)
    ($Before | ConvertTo-Json -Depth 12 -Compress) -eq ($After | ConvertTo-Json -Depth 12 -Compress)
}

function Initialize-PowerModeApi {
    if ('UxRom.PerformanceTuningNative' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace UxRom {
    public static class PerformanceTuningNative {
        [DllImport("powrprof.dll")]
        private static extern UInt32 PowerGetUserConfiguredACPowerMode(out Guid powerModeGuid);
        [DllImport("powrprof.dll")]
        private static extern UInt32 PowerSetUserConfiguredACPowerMode(ref Guid powerModeGuid);
        public static Guid GetACMode() {
            Guid value;
            UInt32 result = PowerGetUserConfiguredACPowerMode(out value);
            if (result != 0) { throw new InvalidOperationException("PowerGetUserConfiguredACPowerMode failed: " + result); }
            return value;
        }
        public static void SetACMode(Guid value) {
            UInt32 result = PowerSetUserConfiguredACPowerMode(ref value);
            if (result != 0) { throw new InvalidOperationException("PowerSetUserConfiguredACPowerMode failed: " + result); }
        }
    }
}
'@
}

function Get-AcPowerMode {
    Initialize-PowerModeApi
    [UxRom.PerformanceTuningNative]::GetACMode()
}

function Set-AcPowerMode {
    param([guid]$Mode)
    Initialize-PowerModeApi
    [UxRom.PerformanceTuningNative]::SetACMode($Mode)
}

function Get-RegistryValueRecord {
    param([string]$Path,[string]$Name,[string]$Category)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $key = Get-Item -LiteralPath $Path
    if ($key.GetValueNames() -notcontains $Name) { return $null }
    [pscustomobject][ordered]@{
        Type = 'RegistryValue'
        Category = $Category
        Path = $Path
        Name = $Name
        Kind = $key.GetValueKind($Name).ToString()
        Data = [string]$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
}

function Get-StartupCandidates {
    $records = @()
    foreach ($path in $script:RunRegistryPaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $key = Get-Item -LiteralPath $path
        foreach ($name in $key.GetValueNames()) {
            $data = [string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($name -match '(?i)^Logitech Download Assistant$' -and $data -match '(?i)(LogiLDA\.dll|LogiLDA\.exe|Logitech Download Assistant)') {
                $records += Get-RegistryValueRecord -Path $path -Name $name -Category 'LogitechDownloadAssistant'
                continue
            }
            $edgeName = $name -match '(?i)^(MicrosoftEdgeAutoLaunch|EdgeAutoLaunch|MicrosoftEdgeAutoLaunch_.+|msedge)$'
            $edgeCommand = $data -match '(?i)(^|[\\"\s])msedge\.exe(["\s]|$)' -and $data -match '(?i)(--no-startup-window|--win-session-start|--auto-launch-at-startup|--restore-last-session)'
            $protected = "$name $data" -match '(?i)(edgeupdate|microsoftedgeupdate|webview2|omnissa|horizon|tailscale|remote\s*desktop|windows\s*app|security|defender)'
            if ($edgeName -and $edgeCommand -and -not $protected -and $path -like 'HKCU:*') {
                $records += Get-RegistryValueRecord -Path $path -Name $name -Category 'EdgeAutomaticLaunch'
            }
        }
    }
    $startupFolder = [Environment]::GetFolderPath('Startup')
    if (-not [string]::IsNullOrWhiteSpace($startupFolder)) {
        $oneNote = Join-Path $startupFolder 'Send to OneNote.lnk'
        if (Test-Path -LiteralPath $oneNote -PathType Leaf) {
            $item = Get-Item -LiteralPath $oneNote -Force
            if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                $records += [pscustomobject][ordered]@{
                    Type = 'File'
                    Category = 'SendToOneNote'
                    Path = $item.FullName
                    Hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
                    Length = [int64]$item.Length
                }
            }
        }
    }
    @($records)
}

function Get-HpDriverPackages {
    @(
        [pscustomobject][ordered]@{
            Key='IntelManagementEngine'; SoftPaq='sp172303'; TargetVersion='2547.8.50.0'
            Url='https://ftp.hp.com/pub/softpaq/sp172001-172500/sp172303.exe'
            DevicePattern='(?i)Management Engine Interface'
        },
        [pscustomobject][ordered]@{
            Key='IntelWirelessLan'; SoftPaq='sp165709'; TargetVersion='23.170.1.1'
            Url='https://ftp.hp.com/pub/softpaq/sp165501-166000/sp165709.exe'
            DevicePattern='(?i)Intel\(R\).*Wi-Fi 6 AX201'
        },
        [pscustomobject][ordered]@{
            Key='SynapticsPointing'; SoftPaq='sp173092'; TargetVersion='19.6.1.27'
            Url='https://ftp.hp.com/pub/softpaq/sp173001-173500/sp173092.exe'
            DevicePattern='(?i)Synaptics.*(HID|PointStyk|TouchPad|Pointing)'
        }
    )
}

function Get-DriverRecords {
    param([object]$Package)
    @(
        Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
            Where-Object { "$( $_.DeviceName ) $( $_.FriendlyName )" -match [string]$Package.DevicePattern } |
            Sort-Object DeviceID |
            ForEach-Object {
                [pscustomobject][ordered]@{
                    DeviceID = [string]$_.DeviceID
                    DeviceName = [string]$_.DeviceName
                    DriverVersion = [string]$_.DriverVersion
                    InfName = [string]$_.InfName
                    DriverProviderName = [string]$_.DriverProviderName
                    Manufacturer = [string]$_.Manufacturer
                }
            }
    )
}

function Test-VersionAtLeast {
    param([string]$Actual,[string]$Required)
    try { return ([version]$Actual -ge [version]$Required) } catch { return $false }
}

function Export-OriginalDriverPackages {
    param([object[]]$DriverPlans,[string]$BackupRoot)
    $exports = @()
    foreach ($infName in @($DriverPlans | ForEach-Object { @($_.OriginalDrivers) } | ForEach-Object { $_.InfName } | Where-Object { $_ } | Sort-Object -Unique)) {
        $destination = Join-Path $BackupRoot ([IO.Path]::GetFileNameWithoutExtension($infName))
        if (-not (Test-Path -LiteralPath $destination)) { New-Item -ItemType Directory -Path $destination -Force | Out-Null }
        Invoke-Native -FilePath 'pnputil.exe' -Arguments @('/export-driver',$infName,$destination) | Out-Null
        $files = @(Get-ChildItem -LiteralPath $destination -Filter '*.inf' -File -Recurse -ErrorAction SilentlyContinue)
        if ($files.Count -eq 0) { throw "Original driver export did not produce an INF for $infName." }
        $exports += [pscustomobject][ordered]@{
            InfName = [string]$infName
            Files = @($files | ForEach-Object { [pscustomobject]@{ Path=$_.FullName; Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } })
        }
    }
    @($exports)
}

function Get-DriverPlans {
    $plans = @()
    foreach ($package in Get-HpDriverPackages) {
        $drivers = @(Get-DriverRecords -Package $package)
        if ($drivers.Count -eq 0) { throw "The expected $($package.Key) device family was not detected." }
        $needsUpdate = @($drivers | Where-Object { -not (Test-VersionAtLeast -Actual $_.DriverVersion -Required $package.TargetVersion) }).Count -gt 0
        $plans += [pscustomobject][ordered]@{
            Key=$package.Key; SoftPaq=$package.SoftPaq; TargetVersion=$package.TargetVersion; Url=$package.Url
            DevicePattern=$package.DevicePattern; NeedsUpdate=[bool]$needsUpdate; OriginalDrivers=@($drivers)
        }
    }
    @($plans)
}

function Save-NewState {
    param([object]$Support)
    $runDirectory = Join-Path (Join-Path $Root 'runs') ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff'))
    New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
    $startup = @(Get-StartupCandidates)
    $backupDirectory = Join-Path $runDirectory 'backup'
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    foreach ($record in @($startup | Where-Object Type -eq 'File')) {
        $backupPath = Join-Path $backupDirectory 'Send to OneNote.lnk'
        Copy-Item -LiteralPath $record.Path -Destination $backupPath -Force
        $record | Add-Member -NotePropertyName BackupPath -NotePropertyValue $backupPath
    }
    $services = @()
    $serviceNames = @()
    if ($IncludeOmnissaRedirection) { $serviceNames += $script:OmnissaRedirectionServices }
    if ($IncludeCoworkService) { $serviceNames += $script:CoworkServices }
    foreach ($name in $serviceNames) {
        $record = Get-ServiceRecord -Name $name
        if ($record) { $services += $record }
    }
    $driverPlans = @()
    $driverExports = @()
    if (-not $SkipHpDriverUpdates) {
        $driverPlans = @(Get-DriverPlans)
        $toUpdate = @($driverPlans | Where-Object NeedsUpdate)
        if ($toUpdate.Count -gt 0) {
            $driverExports = @(Export-OriginalDriverPackages -DriverPlans $toUpdate -BackupRoot (Join-Path $backupDirectory 'drivers'))
        }
    }
    $statePath = Join-Path $runDirectory 'state.json'
    $state = [ordered]@{
        schemaVersion = $script:SchemaVersion
        operation = $script:Operation
        phase = 'captured'
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        capturedBootUtc = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        machine = $env:COMPUTERNAME
        machineUuid = [string]$Support.MachineUuid
        userSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
        options = [ordered]@{
            includeOmnissaRedirection = [bool]$IncludeOmnissaRedirection
            includeCoworkService = [bool]$IncludeCoworkService
            skipHpDriverUpdates = [bool]$SkipHpDriverUpdates
        }
        support = [ordered]@{ windows=$Support.Windows; build=$Support.Build; manufacturer=$Support.Manufacturer; model=$Support.Model; portable=$Support.Portable }
        protectedBefore = Get-ProtectedSnapshot
        startup = @($startup)
        originalAcPowerMode = (Get-AcPowerMode).ToString()
        targetServices = @($services)
        driverPlans = @($driverPlans)
        driverExports = @($driverExports)
        requiresReboot = $false
        runDirectory = $runDirectory
        statePath = $statePath
    }
    Write-JsonFile -Path $statePath -Value $state
    Write-JsonFile -Path $script:PointerPath -Value ([ordered]@{ statePath=$statePath; operation=$script:Operation })
    Write-Event -Event 'capture' -Result 'pass' -Data ([ordered]@{
        startupCount=$startup.Count; serviceCount=$services.Count; driverPackageCount=$driverPlans.Count
        driverUpdatesRequired=@($driverPlans | Where-Object NeedsUpdate).Count
    })
    Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
}

function Read-State {
    if (-not (Test-Path -LiteralPath $script:PointerPath)) { throw 'No performance-tuning state artifact is available.' }
    $pointer = Get-Content -LiteralPath $script:PointerPath -Raw | ConvertFrom-Json
    if ($pointer.operation -ne $script:Operation -or -not (Test-Path -LiteralPath ([string]$pointer.statePath))) { throw 'Performance-tuning state pointer validation failed.' }
    $state = Get-Content -LiteralPath ([string]$pointer.statePath) -Raw | ConvertFrom-Json
    $support = Get-SupportState
    if ($state.schemaVersion -ne $script:SchemaVersion -or $state.operation -ne $script:Operation -or
        $state.machine -ne $env:COMPUTERNAME -or $state.machineUuid -ne $support.MachineUuid -or
        $state.userSid -ne ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value) {
        throw 'Performance-tuning state identity validation failed.'
    }
    $state
}

function Save-State {
    param([object]$State)
    $State | Add-Member -NotePropertyName updatedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
    Write-JsonFile -Path ([string]$State.statePath) -Value $State
}

function Get-MutationPlan {
    param([object]$State)
    [pscustomobject][ordered]@{
        StartupRegistrations = @($State.startup | ForEach-Object { $_.Category })
        AcPowerModeWouldChange = ([string]$State.originalAcPowerMode -ne $script:BestPerformanceMode.ToString())
        ServiceNames = @($State.targetServices | ForEach-Object Name)
        DriverUpdates = @($State.driverPlans | Where-Object NeedsUpdate | ForEach-Object { "$($_.SoftPaq):$($_.TargetVersion)" })
        Preserved = @('Microsoft Defender','Windows audio','Tailscale','core Omnissa Horizon client','Edge Update','installed applications and device drivers outside the three HP packages')
        PerformanceClaim = $false
    }
}

function Assert-StartupOriginal {
    param([object]$Record)
    if ($Record.Type -eq 'RegistryValue') {
        $current = Get-RegistryValueRecord -Path $Record.Path -Name $Record.Name -Category $Record.Category
        if (-not $current -or $current.Kind -ne $Record.Kind -or $current.Data -ne $Record.Data) { throw "Startup registration drift detected: $($Record.Category)." }
    } else {
        if (-not (Test-Path -LiteralPath $Record.Path -PathType Leaf)) { throw "Startup file drift detected: $($Record.Category)." }
        if ((Get-FileHash -LiteralPath $Record.Path -Algorithm SHA256).Hash -ne $Record.Hash) { throw "Startup file hash drift detected: $($Record.Category)." }
    }
}

function Remove-StartupRecords {
    param([object]$State)
    foreach ($record in @($State.startup)) {
        if ($record.Type -eq 'RegistryValue') {
            $current = Get-RegistryValueRecord -Path $record.Path -Name $record.Name -Category $record.Category
            if (-not $current) { continue }
            Assert-StartupOriginal -Record $record
            if ($PSCmdlet.ShouldProcess("$($record.Path)::$($record.Name)",'Remove exact sign-in launch registration')) {
                Remove-ItemProperty -LiteralPath $record.Path -Name $record.Name -ErrorAction Stop
            }
        } else {
            if (-not (Test-Path -LiteralPath $record.Path -PathType Leaf)) { continue }
            Assert-StartupOriginal -Record $record
            if ($PSCmdlet.ShouldProcess($record.Path,'Remove exact Send to OneNote sign-in shortcut')) {
                Remove-Item -LiteralPath $record.Path -Force
            }
        }
    }
}

function Test-StartupRemoved {
    param([object]$State)
    foreach ($record in @($State.startup)) {
        if ($record.Type -eq 'RegistryValue') {
            if (Get-RegistryValueRecord -Path $record.Path -Name $record.Name -Category $record.Category) { return $false }
        } elseif (Test-Path -LiteralPath $record.Path) { return $false }
    }
    $true
}

function Restore-StartupRecords {
    param([object]$State)
    foreach ($record in @($State.startup)) {
        if ($record.Type -eq 'RegistryValue') {
            $current = Get-RegistryValueRecord -Path $record.Path -Name $record.Name -Category $record.Category
            if ($current) {
                if ($current.Kind -eq $record.Kind -and $current.Data -eq $record.Data) { continue }
                throw "Rollback overwrite refused for $($record.Category)."
            }
            if ($PSCmdlet.ShouldProcess("$($record.Path)::$($record.Name)",'Restore exact captured sign-in launch registration')) {
                if (-not (Test-Path -LiteralPath $record.Path)) { New-Item -Path $record.Path -Force | Out-Null }
                New-ItemProperty -LiteralPath $record.Path -Name ([string]$record.Name) -Value ([string]$record.Data) -PropertyType ([string]$record.Kind) -Force | Out-Null
            }
        } else {
            if (Test-Path -LiteralPath $record.Path) {
                if ((Get-FileHash -LiteralPath $record.Path -Algorithm SHA256).Hash -eq $record.Hash) { continue }
                throw 'Rollback overwrite refused for Send to OneNote.'
            }
            if (-not (Test-Path -LiteralPath $record.BackupPath -PathType Leaf) -or (Get-FileHash -LiteralPath $record.BackupPath -Algorithm SHA256).Hash -ne $record.Hash) {
                throw 'Send to OneNote rollback backup validation failed.'
            }
            if ($PSCmdlet.ShouldProcess($record.Path,'Restore exact captured Send to OneNote shortcut')) {
                Copy-Item -LiteralPath $record.BackupPath -Destination $record.Path -Force
            }
        }
    }
}

function Set-ServiceManualAndStopped {
    param([object]$Original)
    $current = Get-ServiceRecord -Name $Original.Name
    if (-not $current -or $current.DisplayName -ne $Original.DisplayName -or $current.PathName -ne $Original.PathName) { throw "Service identity drift detected: $($Original.Name)." }
    if ($current.StartMode -ne 'Manual') {
        if ($PSCmdlet.ShouldProcess($Original.Name,'Set optional background service to Manual')) { Set-Service -Name $Original.Name -StartupType Manual }
    }
    $service = Get-Service -Name $Original.Name
    if ($service.Status -ne 'Stopped') {
        if ($PSCmdlet.ShouldProcess($Original.Name,'Stop optional background service')) { Stop-Service -Name $Original.Name -Force }
    }
}

function Restore-ServiceRecord {
    param([object]$Original)
    $current = Get-ServiceRecord -Name $Original.Name
    if (-not $current -or $current.DisplayName -ne $Original.DisplayName -or $current.PathName -ne $Original.PathName) { throw "Service rollback identity drift detected: $($Original.Name)." }
    $startupType = switch ([string]$Original.StartMode) { 'Auto' {'Automatic'} 'Manual' {'Manual'} 'Disabled' {'Disabled'} default { throw "Unsupported original service mode: $($Original.StartMode)" } }
    if ($PSCmdlet.ShouldProcess($Original.Name,'Restore exact captured service configuration')) {
        Set-Service -Name $Original.Name -StartupType $startupType
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Original.Name)"
        if ([bool]$Original.DelayedAutoStartExists) {
            New-ItemProperty -LiteralPath $registryPath -Name DelayedAutoStart -PropertyType DWord -Value ([int][bool]$Original.DelayedAutoStart) -Force | Out-Null
        } else {
            Remove-ItemProperty -LiteralPath $registryPath -Name DelayedAutoStart -ErrorAction SilentlyContinue
        }
        $service = Get-Service -Name $Original.Name
        if ($Original.State -eq 'Running' -and $service.Status -ne 'Running') { Start-Service -Name $Original.Name }
        if ($Original.State -ne 'Running' -and $service.Status -ne 'Stopped') { Stop-Service -Name $Original.Name -Force }
    }
}

function Get-VerifiedSoftPaq {
    param([object]$Plan)
    $packageDirectory = Join-Path $Root 'packages'
    if (-not (Test-Path -LiteralPath $packageDirectory)) { New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null }
    $path = Join-Path $packageDirectory "$($Plan.SoftPaq).exe"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri ([string]$Plan.Url) -OutFile $path -UseBasicParsing
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $path
    $subject = if ($signature.SignerCertificate) { [string]$signature.SignerCertificate.Subject } else { '' }
    if ($signature.Status -ne 'Valid' -or $subject -notmatch '(?i)\bHP Inc\.') { throw "HP signature validation failed for $($Plan.SoftPaq)." }
    [pscustomobject]@{ Path=$path; Sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash; Signer=$subject }
}

function Install-HpDriverUpdates {
    param([object]$State)
    $requiresReboot = $false
    foreach ($plan in @($State.driverPlans | Where-Object NeedsUpdate)) {
        $current = @(Get-DriverRecords -Package $plan)
        if ($current.Count -gt 0 -and @($current | Where-Object { -not (Test-VersionAtLeast $_.DriverVersion $plan.TargetVersion) }).Count -eq 0) { continue }
        $softPaq = Get-VerifiedSoftPaq -Plan $plan
        if ($PSCmdlet.ShouldProcess($plan.SoftPaq,"Install HP-signed driver update $($plan.TargetVersion)")) {
            $process = Start-Process -FilePath $softPaq.Path -ArgumentList '-s' -WindowStyle Hidden -Wait -PassThru
            if ([int]$process.ExitCode -notin @(0,1641,3010)) { throw "$($plan.SoftPaq) failed with exit code $($process.ExitCode)." }
            if ([int]$process.ExitCode -in @(1641,3010)) { $requiresReboot = $true }
            Write-Event -Event 'driver-install' -Result 'pass' -Data ([ordered]@{ softPaq=$plan.SoftPaq; targetVersion=$plan.TargetVersion; sha256=$softPaq.Sha256; exitCode=$process.ExitCode })
        }
        $after = @(Get-DriverRecords -Package $plan)
        if ($after.Count -eq 0) { throw "$($plan.Key) devices disappeared after the HP driver update." }
        if (@($after | Where-Object { -not (Test-VersionAtLeast $_.DriverVersion $plan.TargetVersion) }).Count -gt 0) { $requiresReboot = $true }
        $plan | Add-Member -NotePropertyName AppliedDrivers -NotePropertyValue @($after) -Force
    }
    [bool]$requiresReboot
}

function Restore-HpDrivers {
    param([object]$State)
    foreach ($plan in @($State.driverPlans | Where-Object NeedsUpdate)) {
        $originalInfNames = @($plan.OriginalDrivers | ForEach-Object InfName | Sort-Object -Unique)
        $exports = @($State.driverExports | Where-Object { $_.InfName -in $originalInfNames })
        foreach ($export in $exports) {
            foreach ($file in @($export.Files)) {
                if (-not (Test-Path -LiteralPath $file.Path -PathType Leaf) -or (Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -ne $file.Hash) { throw "Original driver backup validation failed for $($export.InfName)." }
                Invoke-Native -FilePath 'pnputil.exe' -Arguments @('/add-driver',[string]$file.Path) -AllowedExitCodes @(0,259) | Out-Null
            }
        }
        $current = @(Get-DriverRecords -Package $plan)
        $newInfNames = @($current | Where-Object {
            $driver = $_
            $original = @($plan.OriginalDrivers | Where-Object DeviceID -eq $driver.DeviceID)
            $original.Count -ne 1 -or $driver.DriverVersion -ne $original[0].DriverVersion -or $driver.DriverProviderName -ne $original[0].DriverProviderName
        } | ForEach-Object InfName | Where-Object { $_ } | Sort-Object -Unique)
        foreach ($infName in $newInfNames) {
            if ($PSCmdlet.ShouldProcess($infName,"Remove treatment driver package for $($plan.Key)")) {
                Invoke-Native -FilePath 'pnputil.exe' -Arguments @('/delete-driver',$infName,'/uninstall','/force') -AllowedExitCodes @(0,3010) | Out-Null
            }
        }
        foreach ($export in $exports) {
            foreach ($file in @($export.Files)) {
                if ($PSCmdlet.ShouldProcess($file.Path,"Reinstall captured original driver for $($plan.Key)")) {
                    Invoke-Native -FilePath 'pnputil.exe' -Arguments @('/add-driver',[string]$file.Path,'/install') -AllowedExitCodes @(0,259,3010) | Out-Null
                }
            }
        }
    }
    Invoke-Native -FilePath 'pnputil.exe' -Arguments @('/scan-devices') -AllowedExitCodes @(0,3010) | Out-Null
}

function Test-DriverTreatment {
    param([object]$State)
    foreach ($plan in @($State.driverPlans | Where-Object NeedsUpdate)) {
        $current = @(Get-DriverRecords -Package $plan)
        if ($current.Count -eq 0 -or @($current | Where-Object { -not (Test-VersionAtLeast $_.DriverVersion $plan.TargetVersion) }).Count -gt 0) { return $false }
    }
    $true
}

function Test-DriverRollback {
    param([object]$State)
    foreach ($plan in @($State.driverPlans | Where-Object NeedsUpdate)) {
        $current = @(Get-DriverRecords -Package $plan)
        foreach ($original in @($plan.OriginalDrivers)) {
            $match = @($current | Where-Object DeviceID -eq $original.DeviceID)
            if ($match.Count -ne 1 -or $match[0].DriverVersion -ne $original.DriverVersion -or $match[0].DriverProviderName -ne $original.DriverProviderName) { return $false }
        }
    }
    $true
}

function Test-ServiceTreatment {
    param([object]$State)
    foreach ($original in @($State.targetServices)) {
        $current = Get-ServiceRecord -Name $original.Name
        if (-not $current -or $current.StartMode -ne 'Manual' -or $current.State -ne 'Stopped') { return $false }
    }
    $true
}

function Test-ServiceRollback {
    param([object]$State)
    foreach ($original in @($State.targetServices)) {
        $current = Get-ServiceRecord -Name $original.Name
        if (-not $current -or $current.StartMode -ne $original.StartMode -or
            [bool]$current.DelayedAutoStartExists -ne [bool]$original.DelayedAutoStartExists -or
            [bool]$current.DelayedAutoStart -ne [bool]$original.DelayedAutoStart -or $current.State -ne $original.State) { return $false }
    }
    $true
}

function Invoke-ExactRollback {
    param([object]$State,[bool]$RollbackDrivers = $true)
    if ($RollbackDrivers -and @($State.driverPlans | Where-Object NeedsUpdate).Count -gt 0 -and -not (Test-DriverRollback -State $State)) {
        Restore-HpDrivers -State $State
    }
    foreach ($service in @($State.targetServices)) { Restore-ServiceRecord -Original $service }
    if ([string](Get-AcPowerMode) -ne [string]$State.originalAcPowerMode) {
        if ($PSCmdlet.ShouldProcess($State.originalAcPowerMode,'Restore captured AC power mode')) { Set-AcPowerMode -Mode ([guid]$State.originalAcPowerMode) }
    }
    Restore-StartupRecords -State $State
    $driversOk = if (@($State.driverPlans | Where-Object NeedsUpdate).Count -eq 0) { $true } elseif ($RollbackDrivers) { Test-DriverRollback -State $State } else { $false }
    if (-not (Test-ServiceRollback -State $State)) { throw 'Service rollback verification failed.' }
    if ([string](Get-AcPowerMode) -ne [string]$State.originalAcPowerMode) { throw 'AC power-mode rollback verification failed.' }
    foreach ($record in @($State.startup)) { Assert-StartupOriginal -Record $record }
    if ($RollbackDrivers -and -not $driversOk) { throw 'Driver rollback verification failed; a reboot may be required before exact original versions become active.' }
    $State.phase = 'rolled-back'
    $State.requiresReboot = (-not $driversOk)
    Save-State -State $State
    Write-Event -Event 'rollback' -Result 'pass' -Data ([ordered]@{ driversRestored=$driversOk; serviceCount=@($State.targetServices).Count; startupCount=@($State.startup).Count })
    [pscustomobject]@{ RolledBack=$true; DriversRestored=$driversOk; RequiresReboot=[bool]$State.requiresReboot }
}

function Invoke-Apply {
    $support = Get-SupportState
    Assert-Supported -Support $support
    $state = $null
    $resumingCaptured = $false
    if (Test-Path -LiteralPath $script:PointerPath) {
        $state = Read-State
        if ($state.phase -eq 'applied') {
            if ([bool]$state.options.includeOmnissaRedirection -ne $IncludeOmnissaRedirection -or
                [bool]$state.options.includeCoworkService -ne $IncludeCoworkService -or
                [bool]$state.options.skipHpDriverUpdates -ne $SkipHpDriverUpdates) {
                throw 'Requested tuning options differ from the active state; run PerformanceTuneRollback before applying the new option set.'
            }
            $driversVerified = Test-DriverTreatment -State $state
            if (-not (Test-StartupRemoved -State $state) -or -not (Test-ServiceTreatment -State $state) -or [string](Get-AcPowerMode) -ne $script:BestPerformanceMode.ToString()) {
                throw 'An existing applied performance-tuning state has drifted; run PerformanceTuneRollback before applying again.'
            }
            if (-not $driversVerified) {
                $currentBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
                if ([bool]$state.requiresReboot -and $currentBoot -le [datetime]$state.appliedUtc) {
                    return [pscustomobject]@{ Applied=$true; Idempotent=$true; DriversVerified=$false; RequiresReboot=$true; PerformanceClaim=$false }
                }
                throw 'The HP driver treatment is not active after reboot; run PerformanceTuneRollback before applying again.'
            }
            if ([bool]$state.requiresReboot) {
                $state.requiresReboot = $false
                $state | Add-Member -NotePropertyName driverRebootVerifiedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
                Save-State -State $state
            }
            Write-Event -Event 'apply' -Result 'idempotent' -Data @{ mutationCount=0 }
            return [pscustomobject]@{ Applied=$true; Idempotent=$true; DriversVerified=$true; RequiresReboot=$false; PerformanceClaim=$false }
        }
        if ($state.phase -eq 'captured') {
            if ([bool]$state.options.includeOmnissaRedirection -ne $IncludeOmnissaRedirection -or
                [bool]$state.options.includeCoworkService -ne $IncludeCoworkService -or
                [bool]$state.options.skipHpDriverUpdates -ne $SkipHpDriverUpdates) {
                throw 'Requested tuning options differ from the interrupted state; use the same options or run PerformanceTuneRollback.'
            }
            if (-not (Test-ProtectedEquivalent -Before $state.protectedBefore -After (Get-ProtectedSnapshot))) {
                throw 'Protected configuration changed after the interrupted capture; application cannot resume safely.'
            }
            $resumingCaptured = $true
            Write-Event -Event 'resume-captured' -Result 'pass' -Data @{ capturedUtc=$state.capturedUtc }
        } elseif ($state.phase -ne 'rolled-back') {
            throw "An unfinished performance-tuning state exists in phase '$($state.phase)'."
        }
    }
    if (-not $resumingCaptured) {
        $state = Save-NewState -Support $support
    }
    $plan = Get-MutationPlan -State $state
    Write-Event -Event 'internal-preflight' -Result 'pass' -Data $plan
    if ($WhatIfPreference) {
        $null = $PSCmdlet.ShouldProcess($support.Model,'Apply bounded UX-ROM performance tuning')
        if (-not $resumingCaptured) {
            $state.phase = 'rolled-back'
            Save-State -State $state
        }
        return [pscustomobject]@{ Applied=$false; WhatIf=$true; Plan=$plan }
    }
    if (-not (Test-ProtectedEquivalent -Before $state.protectedBefore -After (Get-ProtectedSnapshot))) { throw 'Protected configuration changed after capture; application refused.' }
    try {
        Remove-StartupRecords -State $state
        if ([string](Get-AcPowerMode) -ne $script:BestPerformanceMode.ToString()) {
            if ($PSCmdlet.ShouldProcess($support.Model,'Set the AC-only Windows power mode to Best performance')) { Set-AcPowerMode -Mode $script:BestPerformanceMode }
        }
        foreach ($service in @($state.targetServices)) { Set-ServiceManualAndStopped -Original $service }
        $requiresReboot = if ($SkipHpDriverUpdates) { $false } else { Install-HpDriverUpdates -State $state }
        if (-not (Test-StartupRemoved -State $state)) { throw 'Sign-in cleanup verification failed.' }
        if ([string](Get-AcPowerMode) -ne $script:BestPerformanceMode.ToString()) { throw 'AC power-mode verification failed.' }
        if (-not (Test-ServiceTreatment -State $state)) { throw 'Optional service treatment verification failed.' }
        $driversVerified = if ($SkipHpDriverUpdates) { $true } else { Test-DriverTreatment -State $state }
        if (-not $driversVerified) { $requiresReboot = $true }
        if (-not (Test-ProtectedEquivalent -Before $state.protectedBefore -After (Get-ProtectedSnapshot))) { throw 'A protected service or unrelated device-health scope changed during application.' }
        $state.phase = 'applied'
        $state | Add-Member -NotePropertyName appliedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
        $state.requiresReboot = [bool]$requiresReboot
        Save-State -State $state
        Write-Event -Event 'apply' -Result 'pass' -Data ([ordered]@{
            startupRemoved=@($state.startup).Count; servicesChanged=@($state.targetServices).Count
            hpDriverUpdates=@($state.driverPlans | Where-Object NeedsUpdate).Count; driversVerified=$driversVerified
            acMode=$script:BestPerformanceMode.ToString(); requiresReboot=$requiresReboot; performanceClaim=$false
        })
        $result = [pscustomobject]@{
            Applied=$true; StartupItemsRemoved=@($state.startup).Count; OptionalServicesChanged=@($state.targetServices).Count
            HpDriverUpdates=@($state.driverPlans | Where-Object NeedsUpdate).Count; DriversVerified=$driversVerified
            AcMode='Best performance'; RequiresReboot=[bool]$requiresReboot; RollbackAction='PerformanceTuneRollback'; PerformanceClaim=$false
        }
        if ($requiresReboot -and $AllowAutomaticReboot) {
            Write-Event -Event 'automatic-reboot' -Result 'requested' -Data @{ reason='HP driver activation' }
            Restart-Computer -Force
        }
        $result
    } catch {
        $failure = $_
        Write-Event -Event 'apply' -Result 'fail' -Data @{ message=$failure.Exception.Message }
        try { Invoke-ExactRollback -State $state | Out-Null }
        catch { Write-Event -Event 'failure-rollback' -Result 'fail' -Data @{ message=$_.Exception.Message } }
        throw $failure
    }
}

try {
    switch ($Action) {
        'Apply' { Invoke-Apply }
        'Rollback' {
            $support = Get-SupportState
            Assert-Supported -Support $support
            $state = Read-State
            if ($state.phase -eq 'rolled-back') {
                Write-Event -Event 'rollback' -Result 'idempotent' -Data @{ mutationCount=0 }
                [pscustomobject]@{ RolledBack=$true; Idempotent=$true; RequiresReboot=[bool]$state.requiresReboot }
            } else {
                Invoke-ExactRollback -State $state
            }
        }
    }
} catch {
    Write-Event -Event 'failure' -Result 'fail' -Data @{ action=$Action; message=$_.Exception.Message; type=$_.Exception.GetType().FullName }
    throw
}

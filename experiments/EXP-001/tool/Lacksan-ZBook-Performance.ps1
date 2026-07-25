#requires -Version 5.1
<#
.SYNOPSIS
  Experimental, reversible performance baseline for one validated HP ZBook.

.DESCRIPTION
  Applies a small allow-list of Windows visual-response, capture, and AC power
  settings. The script captures the actual pre-change state, attempts a Windows
  restore point, verifies every change, logs JSON Lines, and can restore the
  captured state.

  This is not a debloat, application installer, Windows Update controller, or
  ISO utility. It is model-locked to the lab system recorded in EXP-001.

.NOTES
  Copyright (c) 2026 Lacksan.
  Experimental. No performance improvement is claimed until controlled,
  repeated measurements are complete.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Interactive', 'Audit', 'Preview', 'Backup', 'Apply', 'Verify', 'Rollback', 'ListBackups', 'Configuration', 'SelfTest')]
    [string]$Mode = 'Interactive',

    [string]$BackupId,

    [switch]$AcceptExperimentalRisk,

    [switch]$AllowNoRestorePoint,

    [switch]$AllowManagedDevice,

    [switch]$NoPrompt,

    [string]$DataRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ToolName = 'Lacksan ZBook Performance'
$script:ToolVersion = '0.1.0-experimental'
$script:SchemaVersion = 1
$script:Expected = [ordered]@{
    Manufacturer = 'HP'
    Model        = 'HP ZBook Firefly 14 inch G8 Mobile Workstation PC'
    CpuPattern   = 'i5-1145G7'
    OsBuild      = '26200'
    BiosVersion  = 'T76 Ver. 01.24.02'
}

if ([string]::IsNullOrWhiteSpace($DataRoot)) {
    $DataRoot = Join-Path $env:ProgramData 'Lacksan\ZBookPerformance'
}

$script:RegistrySettings = @(
    [pscustomobject]@{
        Id = 'UI.TransparencyOff'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Name = 'EnableTransparency'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Sign-out or Explorer restart'
        Basis = 'Windows setting; also represented in WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.WindowAnimationOff'
        Path = 'HKCU:\Control Panel\Desktop\WindowMetrics'
        Name = 'MinAnimate'
        Type = 'String'
        Desired = '0'
        Restart = 'Sign-out'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.MenuDelay200'
        Path = 'HKCU:\Control Panel\Desktop'
        Name = 'MenuShowDelay'
        Type = 'String'
        Desired = '200'
        Restart = 'Sign-out'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.TaskbarAnimationsOff'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Name = 'TaskbarAnimations'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Sign-out or Explorer restart'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.ListSelectionFadeOff'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Name = 'ListviewAlphaSelect'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Sign-out or Explorer restart'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.IconShadowsOff'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Name = 'ListviewShadow'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Sign-out or Explorer restart'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.VisualEffectsPerformance'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        Name = 'VisualFXSetting'
        Type = 'DWord'
        Desired = [int]3
        Restart = 'Sign-out'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.DragContentsOff'
        Path = 'HKCU:\Control Panel\Desktop'
        Name = 'DragFullWindows'
        Type = 'String'
        Desired = '0'
        Restart = 'Sign-out'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.KeyboardDelayMinimum'
        Path = 'HKCU:\Control Panel\Keyboard'
        Name = 'KeyboardDelay'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Sign-out'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'UI.AeroPeekOff'
        Path = 'HKCU:\Software\Microsoft\Windows\DWM'
        Name = 'EnableAeroPeek'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Sign-out or Explorer restart'
        Basis = 'WinUtil visual-effects configuration'
    },
    [pscustomobject]@{
        Id = 'Capture.GameDvrOff'
        Path = 'HKCU:\System\GameConfigStore'
        Name = 'GameDVR_Enabled'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Application restart'
        Basis = 'Windows per-user capture preference'
    },
    [pscustomobject]@{
        Id = 'Capture.AppCaptureOff'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
        Name = 'AppCaptureEnabled'
        Type = 'DWord'
        Desired = [int]0
        Restart = 'Application restart'
        Basis = 'Windows per-user capture preference'
    }
)

$script:ProcessorSubgroup = [guid]'54533251-82be-4824-96c1-47b60b740d00'
$script:PowerSettings = @(
    [pscustomobject]@{
        Id = 'Power.AcEnergyPreference'
        Guid = [guid]'36687f9e-e3a5-4dbf-b1dc-15eb381c6863'
        DesiredAC = [uint32]0
        Label = 'Processor energy performance preference (AC)'
        Tradeoff = 'Highest AC responsiveness preference; may increase heat, fan noise, and energy use.'
    },
    [pscustomobject]@{
        Id = 'Power.AcCoreParkingMinimum'
        Guid = [guid]'0cc5b647-c1df-4637-891a-dec35c318583'
        DesiredAC = [uint32]100
        Label = 'Processor core parking minimum cores (AC)'
        Tradeoff = 'Keeps all logical processors available on AC; may increase heat and energy use.'
    },
    [pscustomobject]@{
        Id = 'Power.AcMaximumProcessorState'
        Guid = [guid]'bc5038f7-23e0-4960-96da-33abaf5935ec'
        DesiredAC = [uint32]100
        Label = 'Maximum processor state (AC)'
        Tradeoff = 'Allows the full processor performance range on AC.'
    },
    [pscustomobject]@{
        Id = 'Power.AcBoostMode'
        Guid = [guid]'be337238-0d82-4146-a960-4f3749d470c7'
        DesiredAC = [uint32]2
        Label = 'Processor performance boost mode (AC)'
        Tradeoff = 'Aggressive boost behavior may increase heat and fan noise.'
    },
    [pscustomobject]@{
        Id = 'Power.AcCoolingPolicy'
        Guid = [guid]'94d3a615-a899-4ac5-ae2b-e4d8f634367f'
        DesiredAC = [uint32]1
        Label = 'System cooling policy (AC)'
        Tradeoff = 'Active cooling may use the fan sooner to preserve performance.'
    }
)

$script:CurrentLog = $null
$script:RunId = [guid]::NewGuid().ToString('N')

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-LabLog {
    param([string]$RequestedMode)

    $preferred = Join-Path $DataRoot 'Logs'
    try {
        New-Item -ItemType Directory -Path $preferred -Force -ErrorAction Stop | Out-Null
        $folder = $preferred
    }
    catch {
        $folder = Join-Path $env:LOCALAPPDATA 'Lacksan\ZBookPerformance\Logs'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
    $script:CurrentLog = Join-Path $folder "$stamp-$RequestedMode-$($script:RunId).jsonl"
    Write-LabEvent -Event 'RunStarted' -Status 'Info' -Data @{
        ToolVersion = $script:ToolVersion
        Mode = $RequestedMode
        IsAdministrator = (Test-IsAdministrator)
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }
}

function Write-LabEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Event,
        [Parameter(Mandatory = $true)][ValidateSet('Info', 'Pass', 'Change', 'Warning', 'Failure')][string]$Status,
        [hashtable]$Data = @{}
    )

    if ([string]::IsNullOrWhiteSpace($script:CurrentLog)) {
        return
    }

    $entry = [ordered]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        RunId = $script:RunId
        Tool = $script:ToolName
        Version = $script:ToolVersion
        Event = $Event
        Status = $Status
        Data = $Data
    }
    $line = $entry | ConvertTo-Json -Depth 12 -Compress
    [IO.File]::AppendAllText($script:CurrentLog, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
}

function Get-JoinState {
    $taskVisibilityAuthoritative = Test-IsAdministrator
    $values = @{
        AzureAdJoined = $false
        EnterpriseJoined = $false
        DomainJoined = $false
        WorkplaceJoined = $false
        MdmUrlPresent = $false
        EnterpriseMgmtTaskCount = 0
    }

    try {
        $lines = & "$env:SystemRoot\System32\dsregcmd.exe" /status 2>$null
        foreach ($line in $lines) {
            if ($line -match '^\s*AzureAdJoined\s*:\s*(YES|NO)') { $values.AzureAdJoined = $Matches[1] -eq 'YES' }
            elseif ($line -match '^\s*EnterpriseJoined\s*:\s*(YES|NO)') { $values.EnterpriseJoined = $Matches[1] -eq 'YES' }
            elseif ($line -match '^\s*DomainJoined\s*:\s*(YES|NO)') { $values.DomainJoined = $Matches[1] -eq 'YES' }
            elseif ($line -match '^\s*WorkplaceJoined\s*:\s*(YES|NO)') { $values.WorkplaceJoined = $Matches[1] -eq 'YES' }
            elseif ($line -match '^\s*(?:MdmUrl|WorkplaceMdmUrl)\s*:\s*(\S.+)$') { $values.MdmUrlPresent = -not [string]::IsNullOrWhiteSpace($Matches[1]) }
        }
    }
    catch {
        Write-LabEvent -Event 'JoinStateRead' -Status 'Warning' -Data @{ Error = $_.Exception.Message }
    }

    try {
        $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object {
            $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*'
        }
        $values.EnterpriseMgmtTaskCount = @($tasks).Count
    }
    catch {
        Write-LabEvent -Event 'EnterpriseManagementTaskRead' -Status 'Warning' -Data @{ Error = $_.Exception.Message }
    }

    $activeManagement = (
        $values.AzureAdJoined -or
        $values.EnterpriseJoined -or
        $values.DomainJoined -or
        $values.MdmUrlPresent -or
        $values.EnterpriseMgmtTaskCount -gt 0
    )

    return [pscustomobject]@{
        AzureAdJoined = $values.AzureAdJoined
        EnterpriseJoined = $values.EnterpriseJoined
        DomainJoined = $values.DomainJoined
        WorkplaceJoined = $values.WorkplaceJoined
        MdmUrlPresent = $values.MdmUrlPresent
        EnterpriseMgmtTaskCount = $values.EnterpriseMgmtTaskCount
        EnterpriseMgmtTaskVisibility = if ($taskVisibilityAuthoritative) { 'Authoritative' } else { 'LimitedUntilElevated' }
        ActiveManagementDetected = $activeManagement
    }
}

function Get-SystemSnapshot {
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $cpu = @(Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty Name)
    $gpu = @(Get-CimInstance -ClassName Win32_VideoController | ForEach-Object {
        [pscustomobject]@{ Name = $_.Name; DriverVersion = $_.DriverVersion }
    })
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    $join = Get-JoinState
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value

    [pscustomobject]@{
        CapturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        ComputerName = $env:COMPUTERNAME
        UserSid = $sid
        Manufacturer = [string]$computer.Manufacturer
        Model = [string]$computer.Model
        TotalPhysicalMemoryBytes = [uint64]$computer.TotalPhysicalMemory
        Cpu = $cpu
        OsCaption = [string]$os.Caption
        OsVersion = [string]$os.Version
        OsBuild = [string]$os.BuildNumber
        BiosVersion = [string]$bios.SMBIOSBIOSVersion
        BiosReleaseDate = if ($bios.ReleaseDate) { ([datetime]$bios.ReleaseDate).ToString('o') } else { $null }
        Graphics = $gpu
        OnBattery = if ($battery) { [int]$battery.BatteryStatus -eq 1 } else { $false }
        JoinState = $join
    }
}

function Test-SupportedSystem {
    param(
        [Parameter(Mandatory = $true)]$Snapshot,
        [switch]$PermitManaged
    )

    $reasons = New-Object Collections.Generic.List[string]
    if ($Snapshot.Manufacturer -ne $script:Expected.Manufacturer) {
        $reasons.Add("Manufacturer '$($Snapshot.Manufacturer)' is not validated '$($script:Expected.Manufacturer)'.")
    }
    if ($Snapshot.Model -ne $script:Expected.Model) {
        $reasons.Add("Model '$($Snapshot.Model)' is not validated '$($script:Expected.Model)'.")
    }
    if (-not (@($Snapshot.Cpu) -join ' ' -match [regex]::Escape($script:Expected.CpuPattern))) {
        $reasons.Add("Processor is not the validated $($script:Expected.CpuPattern).")
    }
    if ($Snapshot.OsBuild -ne $script:Expected.OsBuild) {
        $reasons.Add("Windows build '$($Snapshot.OsBuild)' is not validated '$($script:Expected.OsBuild)'.")
    }
    if ($Snapshot.BiosVersion -ne $script:Expected.BiosVersion) {
        $reasons.Add("BIOS '$($Snapshot.BiosVersion)' is not validated '$($script:Expected.BiosVersion)'.")
    }
    if ($Snapshot.JoinState.ActiveManagementDetected -and -not $PermitManaged) {
        $reasons.Add('Active domain, Entra, MDM, or EnterpriseMgmt control was detected. Use -AllowManagedDevice only with administrator approval.')
    }

    [pscustomobject]@{
        Supported = $reasons.Count -eq 0
        Reasons = @($reasons)
    }
}

function Initialize-PowerNative {
    if ('LacksanPowerNative' -as [type]) {
        return
    }

    $source = @'
using System;
using System.Runtime.InteropServices;

public static class LacksanPowerNative
{
    [DllImport("powrprof.dll")]
    public static extern uint PowerGetActiveScheme(IntPtr UserRootPowerKey, out IntPtr ActivePolicyGuid);

    [DllImport("powrprof.dll")]
    public static extern uint PowerSetActiveScheme(IntPtr UserRootPowerKey, ref Guid SchemeGuid);

    [DllImport("powrprof.dll")]
    public static extern uint PowerReadACValueIndex(IntPtr RootPowerKey, ref Guid SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, out uint AcValueIndex);

    [DllImport("powrprof.dll")]
    public static extern uint PowerReadDCValueIndex(IntPtr RootPowerKey, ref Guid SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, out uint DcValueIndex);

    [DllImport("powrprof.dll")]
    public static extern uint PowerWriteACValueIndex(IntPtr RootPowerKey, ref Guid SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, uint AcValueIndex);

    [DllImport("powrprof.dll")]
    public static extern uint PowerWriteDCValueIndex(IntPtr RootPowerKey, ref Guid SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, uint DcValueIndex);

    [DllImport("kernel32.dll")]
    public static extern IntPtr LocalFree(IntPtr hMem);
}
'@
    Add-Type -TypeDefinition $source -Language CSharp
}

function Get-ActivePowerScheme {
    Initialize-PowerNative
    $pointer = [IntPtr]::Zero
    $status = [LacksanPowerNative]::PowerGetActiveScheme([IntPtr]::Zero, [ref]$pointer)
    if ($status -ne 0 -or $pointer -eq [IntPtr]::Zero) {
        throw "PowerGetActiveScheme failed with Win32 status $status."
    }
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStructure($pointer, [type][guid])
    }
    finally {
        [void][LacksanPowerNative]::LocalFree($pointer)
    }
}

function Get-PowerValue {
    param(
        [Parameter(Mandatory = $true)][guid]$Scheme,
        [Parameter(Mandatory = $true)][guid]$Setting
    )

    Initialize-PowerNative
    $subgroup = $script:ProcessorSubgroup
    [uint32]$ac = 0
    [uint32]$dc = 0
    $acStatus = [LacksanPowerNative]::PowerReadACValueIndex(
        [IntPtr]::Zero, [ref]$Scheme, [ref]$subgroup, [ref]$Setting, [ref]$ac
    )
    $dcStatus = [LacksanPowerNative]::PowerReadDCValueIndex(
        [IntPtr]::Zero, [ref]$Scheme, [ref]$subgroup, [ref]$Setting, [ref]$dc
    )
    if ($acStatus -ne 0 -or $dcStatus -ne 0) {
        throw "Power value read failed for $Setting (AC=$acStatus, DC=$dcStatus)."
    }
    [pscustomobject]@{ AC = $ac; DC = $dc }
}

function Set-PowerValue {
    param(
        [Parameter(Mandatory = $true)][guid]$Scheme,
        [Parameter(Mandatory = $true)][guid]$Setting,
        [Parameter(Mandatory = $true)][uint32]$AC,
        [Parameter(Mandatory = $true)][uint32]$DC
    )

    Initialize-PowerNative
    $subgroup = $script:ProcessorSubgroup
    $acStatus = [LacksanPowerNative]::PowerWriteACValueIndex(
        [IntPtr]::Zero, [ref]$Scheme, [ref]$subgroup, [ref]$Setting, $AC
    )
    if ($acStatus -ne 0) {
        throw "Power AC value write failed for $Setting (status $acStatus)."
    }
    $dcStatus = [LacksanPowerNative]::PowerWriteDCValueIndex(
        [IntPtr]::Zero, [ref]$Scheme, [ref]$subgroup, [ref]$Setting, $DC
    )
    if ($dcStatus -ne 0) {
        throw "Power DC value write failed for $Setting (status $dcStatus)."
    }
}

function Set-ActivePowerScheme {
    param([Parameter(Mandatory = $true)][guid]$Scheme)
    Initialize-PowerNative
    $status = [LacksanPowerNative]::PowerSetActiveScheme([IntPtr]::Zero, [ref]$Scheme)
    if ($status -ne 0) {
        throw "PowerSetActiveScheme failed with Win32 status $status."
    }
}

function Get-RegistryState {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $keyExists = Test-Path -LiteralPath $Path
    if (-not $keyExists) {
        return [pscustomobject]@{
            KeyExists = $false
            ValueExists = $false
            Type = $null
            Value = $null
        }
    }

    $key = Get-Item -LiteralPath $Path
    $valueExists = @($key.GetValueNames()) -contains $Name
    if (-not $valueExists) {
        return [pscustomobject]@{
            KeyExists = $true
            ValueExists = $false
            Type = $null
            Value = $null
        }
    }

    [pscustomobject]@{
        KeyExists = $true
        ValueExists = $true
        Type = $key.GetValueKind($Name).ToString()
        Value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
}

function Test-EquivalentValue {
    param($Actual, $Expected, [string]$Type)
    if ($Type -in @('DWord', 'QWord')) {
        return [uint64]$Actual -eq [uint64]$Expected
    }
    if ($Type -eq 'Binary') {
        return [Convert]::ToBase64String([byte[]]$Actual) -eq [Convert]::ToBase64String([byte[]]$Expected)
    }
    if ($Type -eq 'MultiString') {
        return (@($Actual) -join "`0") -ceq (@($Expected) -join "`0")
    }
    return [string]$Actual -ceq [string]$Expected
}

function Set-RegistryValueExact {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')][string]$Type,
        [Parameter(Mandatory = $true)]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    $existing = Get-RegistryState -Path $Path -Name $Name
    if ($existing.ValueExists -and $existing.Type -ne $Type) {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -Force
    }
    if (-not (Get-RegistryState -Path $Path -Name $Name).ValueExists) {
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
    }
    else {
        Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Force
    }
}

function Restore-RegistryState {
    param([Parameter(Mandatory = $true)]$Entry)

    if ($Entry.Original.ValueExists) {
        $value = $Entry.Original.Value
        if ($Entry.Original.Type -eq 'Binary') {
            $value = [byte[]]@($value)
        }
        elseif ($Entry.Original.Type -eq 'MultiString') {
            $value = [string[]]@($value)
        }
        Set-RegistryValueExact -Path $Entry.Path -Name $Entry.Name -Type $Entry.Original.Type -Value $value
        return
    }

    if (Test-Path -LiteralPath $Entry.Path) {
        $key = Get-Item -LiteralPath $Entry.Path
        if (@($key.GetValueNames()) -contains $Entry.Name) {
            Remove-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -Force
        }
        if (-not $Entry.Original.KeyExists) {
            $key = Get-Item -LiteralPath $Entry.Path
            if (@($key.GetValueNames()).Count -eq 0 -and @($key.GetSubKeyNames()).Count -eq 0) {
                Remove-Item -LiteralPath $Entry.Path -Force
            }
        }
    }
}

function Get-ConfigurationState {
    $scheme = Get-ActivePowerScheme
    $registry = foreach ($setting in $script:RegistrySettings) {
        $current = Get-RegistryState -Path $setting.Path -Name $setting.Name
        [pscustomobject]@{
            Id = $setting.Id
            Kind = 'Registry'
            Current = if ($current.ValueExists) { $current.Value } else { '<absent>' }
            Desired = $setting.Desired
            Compliant = (
                $current.ValueExists -and
                $current.Type -eq $setting.Type -and
                (Test-EquivalentValue -Actual $current.Value -Expected $setting.Desired -Type $setting.Type)
            )
            Detail = "$($setting.Path)\$($setting.Name)"
        }
    }
    $power = foreach ($setting in $script:PowerSettings) {
        $current = Get-PowerValue -Scheme $scheme -Setting $setting.Guid
        [pscustomobject]@{
            Id = $setting.Id
            Kind = 'Power'
            Current = [uint32]$current.AC
            Desired = [uint32]$setting.DesiredAC
            Compliant = [uint32]$current.AC -eq [uint32]$setting.DesiredAC
            Detail = "$($setting.Label); DC retained at $($current.DC)"
        }
    }
    return @($registry) + @($power)
}

function Show-Audit {
    $snapshot = Get-SystemSnapshot
    $support = Test-SupportedSystem -Snapshot $snapshot -PermitManaged:$AllowManagedDevice
    Write-LabEvent -Event 'SupportDetection' -Status $(if ($support.Supported) { 'Pass' } else { 'Warning' }) -Data @{
        Supported = $support.Supported
        Reasons = @($support.Reasons)
        Manufacturer = $snapshot.Manufacturer
        Model = $snapshot.Model
        OsBuild = $snapshot.OsBuild
        BiosVersion = $snapshot.BiosVersion
        JoinState = $snapshot.JoinState
    }

    Write-Host ''
    Write-Host "$($script:ToolName) $($script:ToolVersion)"
    Write-Host "Computer:     $($snapshot.Manufacturer) $($snapshot.Model)"
    Write-Host "CPU:          $(@($snapshot.Cpu) -join '; ')"
    Write-Host "Windows:      $($snapshot.OsCaption), build $($snapshot.OsBuild)"
    Write-Host "BIOS:         $($snapshot.BiosVersion)"
    Write-Host "Managed:      $($snapshot.JoinState.ActiveManagementDetected)"
    Write-Host "Work account: $($snapshot.JoinState.WorkplaceJoined)"
    Write-Host "Mgmt audit:   $($snapshot.JoinState.EnterpriseMgmtTaskVisibility)"
    Write-Host "Supported:    $($support.Supported)"
    foreach ($reason in $support.Reasons) {
        Write-Host "  - $reason" -ForegroundColor Yellow
    }
    Write-Host "Log:          $($script:CurrentLog)"
    return [pscustomobject]@{ Snapshot = $snapshot; Support = $support }
}

function Show-Preview {
    $audit = Show-Audit
    $states = Get-ConfigurationState
    Write-Host ''
    Write-Host 'Allow-listed baseline preview'
    $states | Select-Object Id, Kind, Current, Desired, Compliant | Format-Table -AutoSize
    $pending = @($states | Where-Object { -not $_.Compliant })
    Write-Host "$($pending.Count) of $($states.Count) setting(s) would change."
    Write-Host 'No services, scheduled tasks, applications, update controls, security controls, or firmware settings are changed.'
    Write-LabEvent -Event 'PreviewCompleted' -Status 'Info' -Data @{
        Supported = $audit.Support.Supported
        Pending = @($pending | Select-Object Id, Current, Desired)
    }
    return $states
}

function Convert-RegistryProviderPath {
    param([string]$Path)
    if ($Path -like 'HKCU:\*') { return 'HKCU\' + $Path.Substring(6) }
    if ($Path -like 'HKLM:\*') { return 'HKLM\' + $Path.Substring(6) }
    throw "Registry export does not support path '$Path'."
}

function New-LabBackup {
    param(
        [Parameter(Mandatory = $true)]$Snapshot,
        [switch]$PermitNoRestorePoint
    )

    if (-not (Test-IsAdministrator)) {
        throw 'Backup requires an elevated Windows PowerShell session.'
    }

    $backupRoot = Join-Path $DataRoot 'Backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $id = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') + '-' + $script:RunId.Substring(0, 8)
    $path = Join-Path $backupRoot $id
    $registryFolder = Join-Path $path 'registry'
    New-Item -ItemType Directory -Path $registryFolder -Force | Out-Null

    $scheme = Get-ActivePowerScheme
    $registryState = foreach ($setting in $script:RegistrySettings) {
        [pscustomobject]@{
            Id = $setting.Id
            Path = $setting.Path
            Name = $setting.Name
            Original = Get-RegistryState -Path $setting.Path -Name $setting.Name
        }
    }
    $powerState = foreach ($setting in $script:PowerSettings) {
        $current = Get-PowerValue -Scheme $scheme -Setting $setting.Guid
        [pscustomobject]@{
            Id = $setting.Id
            SubgroupGuid = $script:ProcessorSubgroup.ToString()
            SettingGuid = $setting.Guid.ToString()
            OriginalAC = [uint32]$current.AC
            OriginalDC = [uint32]$current.DC
        }
    }

    $exportResults = @()
    $index = 0
    foreach ($keyPath in @($script:RegistrySettings.Path | Sort-Object -Unique)) {
        $index++
        $target = Join-Path $registryFolder ('key-{0:d2}.reg' -f $index)
        $nativePath = Convert-RegistryProviderPath -Path $keyPath
        & "$env:SystemRoot\System32\reg.exe" export $nativePath $target /y *> $null
        $exportResults += [pscustomobject]@{
            Path = $keyPath
            File = Split-Path -Leaf $target
            Succeeded = $LASTEXITCODE -eq 0
        }
    }

    $powerExport = Join-Path $path 'active-power-plan.pow'
    & "$env:SystemRoot\System32\powercfg.exe" /export $powerExport $scheme.ToString() *> $null
    $powerExportSucceeded = $LASTEXITCODE -eq 0

    $restorePoint = [ordered]@{
        Attempted = $true
        Succeeded = $false
        Error = $null
    }
    try {
        Checkpoint-Computer -Description "Lacksan ZBook Performance $id" -RestorePointType MODIFY_SETTINGS
        $restorePoint.Succeeded = $true
    }
    catch {
        $restorePoint.Error = $_.Exception.Message
    }

    $manifest = [ordered]@{
        SchemaVersion = $script:SchemaVersion
        ToolName = $script:ToolName
        ToolVersion = $script:ToolVersion
        BackupId = $id
        CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        Machine = $Snapshot
        ActivePowerScheme = $scheme.ToString()
        Registry = @($registryState)
        Power = @($powerState)
        RegistryExports = @($exportResults)
        PowerPlanExportSucceeded = $powerExportSucceeded
        RestorePoint = $restorePoint
    }
    $manifestPath = Join-Path $path 'manifest.json'
    $manifestJson = $manifest | ConvertTo-Json -Depth 18
    [IO.File]::WriteAllText($manifestPath, $manifestJson, (New-Object Text.UTF8Encoding($false)))
    $hash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    [IO.File]::WriteAllText((Join-Path $path 'manifest.sha256'), $hash + [Environment]::NewLine, (New-Object Text.ASCIIEncoding))

    Write-LabEvent -Event 'BackupCreated' -Status $(if ($restorePoint.Succeeded) { 'Pass' } else { 'Warning' }) -Data @{
        BackupId = $id
        Path = $path
        RestorePoint = $restorePoint
        PowerPlanExportSucceeded = $powerExportSucceeded
        FailedRegistryExports = @($exportResults | Where-Object { -not $_.Succeeded } | Select-Object -ExpandProperty Path)
    }

    if (-not $restorePoint.Succeeded -and -not $PermitNoRestorePoint) {
        throw "The state manifest was saved as '$id', but Windows did not create a restore point. No tweaks were applied. Error: $($restorePoint.Error)"
    }

    [pscustomobject]@{ Id = $id; Path = $path; Manifest = $manifest }
}

function Get-BackupPath {
    param([string]$RequestedId)
    $root = Join-Path $DataRoot 'Backups'
    if (-not (Test-Path -LiteralPath $root)) {
        throw "No backup folder exists at '$root'."
    }
    if (-not [string]::IsNullOrWhiteSpace($RequestedId)) {
        if ($RequestedId -match '[\\/]' -or $RequestedId -notmatch '^[A-Za-z0-9._-]+$') {
            throw 'BackupId contains invalid characters.'
        }
        $selected = Join-Path $root $RequestedId
        if (-not (Test-Path -LiteralPath $selected -PathType Container)) {
            throw "Backup '$RequestedId' was not found."
        }
        return $selected
    }
    $latest = Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) {
        throw "No backups were found in '$root'."
    }
    return $latest.FullName
}

function Read-VerifiedManifest {
    param([Parameter(Mandatory = $true)][string]$BackupPath)
    $manifestPath = Join-Path $BackupPath 'manifest.json'
    $hashPath = Join-Path $BackupPath 'manifest.sha256'
    if (-not (Test-Path -LiteralPath $manifestPath) -or -not (Test-Path -LiteralPath $hashPath)) {
        throw "Backup '$BackupPath' is incomplete."
    }
    $expectedHash = (Get-Content -LiteralPath $hashPath -Raw).Trim()
    $actualHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    if ($actualHash -cne $expectedHash) {
        throw "Backup manifest hash verification failed for '$BackupPath'."
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([int]$manifest.SchemaVersion -ne $script:SchemaVersion) {
        throw "Unsupported backup schema '$($manifest.SchemaVersion)'."
    }
    return $manifest
}

function Invoke-RestoreBackup {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$Automatic
    )

    if (-not (Test-IsAdministrator)) {
        throw 'Rollback requires an elevated Windows PowerShell session.'
    }
    $manifest = Read-VerifiedManifest -BackupPath $Path
    $snapshot = Get-SystemSnapshot
    if ($manifest.Machine.Model -ne $snapshot.Model -or $manifest.Machine.UserSid -ne $snapshot.UserSid) {
        throw 'The backup belongs to a different model or Windows user SID.'
    }

    foreach ($entry in $manifest.Registry) {
        Restore-RegistryState -Entry $entry
        Write-LabEvent -Event 'RegistryRollback' -Status 'Change' -Data @{ Id = $entry.Id }
    }

    $scheme = [guid]$manifest.ActivePowerScheme
    foreach ($entry in $manifest.Power) {
        Set-PowerValue -Scheme $scheme -Setting ([guid]$entry.SettingGuid) -AC ([uint32]$entry.OriginalAC) -DC ([uint32]$entry.OriginalDC)
        Write-LabEvent -Event 'PowerRollback' -Status 'Change' -Data @{
            Id = $entry.Id
            AC = [uint32]$entry.OriginalAC
            DC = [uint32]$entry.OriginalDC
        }
    }
    Set-ActivePowerScheme -Scheme $scheme

    $failures = New-Object Collections.Generic.List[string]
    foreach ($entry in $manifest.Registry) {
        $actual = Get-RegistryState -Path $entry.Path -Name $entry.Name
        if ([bool]$actual.ValueExists -ne [bool]$entry.Original.ValueExists) {
            $failures.Add($entry.Id)
        }
        elseif ($entry.Original.ValueExists) {
            if ($actual.Type -ne $entry.Original.Type -or -not (Test-EquivalentValue -Actual $actual.Value -Expected $entry.Original.Value -Type $actual.Type)) {
                $failures.Add($entry.Id)
            }
        }
    }
    foreach ($entry in $manifest.Power) {
        $actual = Get-PowerValue -Scheme $scheme -Setting ([guid]$entry.SettingGuid)
        if ([uint32]$actual.AC -ne [uint32]$entry.OriginalAC -or [uint32]$actual.DC -ne [uint32]$entry.OriginalDC) {
            $failures.Add($entry.Id)
        }
    }

    if ($failures.Count -gt 0) {
        Write-LabEvent -Event 'RollbackVerification' -Status 'Failure' -Data @{ Failed = @($failures); Automatic = [bool]$Automatic }
        throw "Rollback verification failed for: $(@($failures) -join ', ')."
    }
    Write-LabEvent -Event 'RollbackVerification' -Status 'Pass' -Data @{
        BackupId = $manifest.BackupId
        Automatic = [bool]$Automatic
    }
    Write-Host "Rollback verified from backup '$($manifest.BackupId)'."
    Write-Host 'The backup was retained. Sign out or restart Windows to reload all per-user visual settings.'
}

function Assert-ApplyPrerequisites {
    param([Parameter(Mandatory = $true)]$Snapshot)
    if (-not (Test-IsAdministrator)) {
        throw 'Apply requires Windows PowerShell 5.1 started with Run as administrator.'
    }
    $support = Test-SupportedSystem -Snapshot $Snapshot -PermitManaged:$AllowManagedDevice
    if (-not $support.Supported) {
        throw "Support detection failed: $(@($support.Reasons) -join ' ')"
    }
    if (-not $AcceptExperimentalRisk) {
        throw 'Apply requires -AcceptExperimentalRisk. This baseline is experimental and may increase heat, fan noise, and AC energy use.'
    }
}

function Invoke-LabApply {
    $snapshot = Get-SystemSnapshot
    Assert-ApplyPrerequisites -Snapshot $snapshot
    $states = Get-ConfigurationState
    $pending = @($states | Where-Object { -not $_.Compliant })
    if ($pending.Count -eq 0) {
        Write-Host 'The allow-listed baseline is already compliant. No backup or write was needed.'
        Write-LabEvent -Event 'ApplyIdempotent' -Status 'Pass' -Data @{ SettingCount = $states.Count }
        return
    }

    $backup = New-LabBackup -Snapshot $snapshot -PermitNoRestorePoint:$AllowNoRestorePoint
    try {
        foreach ($setting in $script:RegistrySettings) {
            $before = Get-RegistryState -Path $setting.Path -Name $setting.Name
            $compliant = (
                $before.ValueExists -and
                $before.Type -eq $setting.Type -and
                (Test-EquivalentValue -Actual $before.Value -Expected $setting.Desired -Type $setting.Type)
            )
            if (-not $compliant) {
                Set-RegistryValueExact -Path $setting.Path -Name $setting.Name -Type $setting.Type -Value $setting.Desired
                Write-LabEvent -Event 'RegistryApply' -Status 'Change' -Data @{
                    Id = $setting.Id
                    Before = $before
                    Desired = $setting.Desired
                }
            }
        }

        $scheme = Get-ActivePowerScheme
        foreach ($setting in $script:PowerSettings) {
            $before = Get-PowerValue -Scheme $scheme -Setting $setting.Guid
            if ([uint32]$before.AC -ne [uint32]$setting.DesiredAC) {
                Set-PowerValue -Scheme $scheme -Setting $setting.Guid -AC $setting.DesiredAC -DC $before.DC
                Write-LabEvent -Event 'PowerApply' -Status 'Change' -Data @{
                    Id = $setting.Id
                    BeforeAC = [uint32]$before.AC
                    DesiredAC = [uint32]$setting.DesiredAC
                    RetainedDC = [uint32]$before.DC
                }
            }
        }
        Set-ActivePowerScheme -Scheme $scheme

        $after = Get-ConfigurationState
        $failed = @($after | Where-Object { -not $_.Compliant })
        if ($failed.Count -gt 0) {
            throw "Post-apply verification failed for: $(@($failed.Id) -join ', ')."
        }
        Write-LabEvent -Event 'ApplyVerification' -Status 'Pass' -Data @{
            BackupId = $backup.Id
            Changed = @($pending.Id)
            RebootPersistence = 'Pending'
        }
        Write-Host "Apply and immediate verification succeeded. Backup: $($backup.Id)"
        Write-Host 'Sign out or restart Windows to reload visual settings. Reboot-persistence validation remains pending.'
        Write-Host 'AC tuning may increase heat, fan noise, and power consumption; battery/DC values were preserved.'
    }
    catch {
        Write-LabEvent -Event 'ApplyFailed' -Status 'Failure' -Data @{ Error = $_.Exception.Message; BackupId = $backup.Id }
        try {
            Invoke-RestoreBackup -Path $backup.Path -Automatic
        }
        catch {
            Write-LabEvent -Event 'AutomaticRollbackFailed' -Status 'Failure' -Data @{ Error = $_.Exception.Message; BackupId = $backup.Id }
            throw "Apply failed and automatic rollback also failed. Backup '$($backup.Id)' is preserved. Rollback error: $($_.Exception.Message)"
        }
        throw 'Apply failed; the captured state was automatically restored and verified.'
    }
}

function Invoke-LabVerify {
    $states = Get-ConfigurationState
    $states | Select-Object Id, Kind, Current, Desired, Compliant | Format-Table -AutoSize
    $failed = @($states | Where-Object { -not $_.Compliant })
    Write-LabEvent -Event 'Verification' -Status $(if ($failed.Count -eq 0) { 'Pass' } else { 'Failure' }) -Data @{
        Failed = @($failed | Select-Object -ExpandProperty Id)
    }
    if ($failed.Count -gt 0) {
        throw "Verification failed for $($failed.Count) setting(s): $(@($failed.Id) -join ', ')."
    }
    Write-Host 'All allow-listed settings verify successfully.'
}

function Show-Configuration {
    Write-Host ''
    Write-Host 'Registry and preference settings'
    $script:RegistrySettings | Select-Object Id, Desired, Restart, Basis | Format-Table -Wrap -AutoSize
    Write-Host ''
    Write-Host 'AC-only processor settings'
    $script:PowerSettings | Select-Object Id, DesiredAC, Label, Tradeoff | Format-Table -Wrap -AutoSize
    Write-Host ''
    Write-Host 'Excluded: software installs/removal, debloat, services, scheduled tasks, Windows Update, security controls, firmware writes, and ISO creation.'
}

function Show-Backups {
    $root = Join-Path $DataRoot 'Backups'
    if (-not (Test-Path -LiteralPath $root)) {
        Write-Host 'No backups exist.'
        return
    }
    $items = foreach ($folder in Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending) {
        try {
            $manifest = Read-VerifiedManifest -BackupPath $folder.FullName
            [pscustomobject]@{
                BackupId = $manifest.BackupId
                CreatedUtc = $manifest.CreatedUtc
                Model = $manifest.Machine.Model
                RestorePoint = $manifest.RestorePoint.Succeeded
                Integrity = 'Verified'
            }
        }
        catch {
            [pscustomobject]@{
                BackupId = $folder.Name
                CreatedUtc = $null
                Model = $null
                RestorePoint = $null
                Integrity = 'FAILED'
            }
        }
    }
    $items | Format-Table -AutoSize
}

function Invoke-SelfTest {
    $failures = New-Object Collections.Generic.List[string]
    $ids = @($script:RegistrySettings.Id) + @($script:PowerSettings.Id)
    foreach ($duplicate in $ids | Group-Object | Where-Object { $_.Count -gt 1 }) {
        $failures.Add("Duplicate setting id: $($duplicate.Name)")
    }
    foreach ($setting in $script:RegistrySettings) {
        if ($setting.Path -notmatch '^HKC[UL]:\\') { $failures.Add("Invalid registry hive: $($setting.Id)") }
        if ($setting.Type -notin @('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')) {
            $failures.Add("Invalid registry type: $($setting.Id)")
        }
    }
    foreach ($setting in $script:PowerSettings) {
        if ($setting.Guid -eq [guid]::Empty) { $failures.Add("Empty power GUID: $($setting.Id)") }
        if ([uint32]$setting.DesiredAC -gt 100 -and $setting.Id -ne 'Power.AcBoostMode') {
            $failures.Add("Out-of-range AC value: $($setting.Id)")
        }
    }
    if ($failures.Count -gt 0) {
        Write-LabEvent -Event 'SelfTest' -Status 'Failure' -Data @{ Failures = @($failures) }
        throw "Self-test failed: $(@($failures) -join '; ')"
    }
    Initialize-PowerNative
    [void](Get-ActivePowerScheme)
    Write-LabEvent -Event 'SelfTest' -Status 'Pass' -Data @{ SettingCount = $ids.Count }
    Write-Host "Self-test passed for $($ids.Count) allow-listed settings."
}

function Start-Interactive {
    do {
        Clear-Host
        Write-Host "$($script:ToolName) $($script:ToolVersion) [EXPERIMENTAL]"
        Write-Host '1. Audit this computer'
        Write-Host '2. Preview baseline'
        Write-Host '3. Apply baseline'
        Write-Host '4. Verify baseline'
        Write-Host '5. Roll back latest backup'
        Write-Host '6. List backups'
        Write-Host '7. Show configuration'
        Write-Host '8. Exit'
        $choice = Read-Host 'Choose'
        try {
            switch ($choice) {
                '1' { [void](Show-Audit) }
                '2' { [void](Show-Preview) }
                '3' {
                    if (-not (Test-IsAdministrator)) {
                        Write-Host 'Close this window and start Windows PowerShell with Run as administrator.' -ForegroundColor Yellow
                    }
                    else {
                        $confirm = Read-Host 'Type APPLY to accept experimental AC heat/noise/energy tradeoffs'
                        if ($confirm -ceq 'APPLY') {
                            $script:AcceptExperimentalRisk = $true
                            Invoke-LabApply
                        }
                    }
                }
                '4' { Invoke-LabVerify }
                '5' {
                    if (-not (Test-IsAdministrator)) {
                        Write-Host 'Rollback requires Windows PowerShell started with Run as administrator.' -ForegroundColor Yellow
                    }
                    else {
                        $confirm = Read-Host 'Type ROLLBACK to restore the latest backup'
                        if ($confirm -ceq 'ROLLBACK') {
                            Invoke-RestoreBackup -Path (Get-BackupPath)
                        }
                    }
                }
                '6' { Show-Backups }
                '7' { Show-Configuration }
                '8' { return }
                default { Write-Host 'Unknown selection.' -ForegroundColor Yellow }
            }
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-LabEvent -Event 'InteractiveActionFailed' -Status 'Failure' -Data @{ Error = $_.Exception.Message; Choice = $choice }
        }
        if ($choice -ne '8') {
            [void](Read-Host 'Press Enter to continue')
        }
    } while ($true)
}

Initialize-LabLog -RequestedMode $Mode
try {
    if ($WhatIfPreference -and $Mode -in @('Apply', 'Backup', 'Rollback')) {
        Write-Host '-WhatIf selected; showing the dry-run preview. No backup or setting is written.'
        [void](Show-Preview)
    }
    else {
        switch ($Mode) {
            'Interactive' { Start-Interactive }
            'Audit' { [void](Show-Audit) }
            'Preview' { [void](Show-Preview) }
            'Backup' {
                $snapshot = Get-SystemSnapshot
                $support = Test-SupportedSystem -Snapshot $snapshot -PermitManaged:$AllowManagedDevice
                if (-not $support.Supported) { throw "Support detection failed: $(@($support.Reasons) -join ' ')" }
                $backup = New-LabBackup -Snapshot $snapshot -PermitNoRestorePoint:$AllowNoRestorePoint
                Write-Host "Backup created: $($backup.Id)"
            }
            'Apply' { Invoke-LabApply }
            'Verify' { Invoke-LabVerify }
            'Rollback' { Invoke-RestoreBackup -Path (Get-BackupPath -RequestedId $BackupId) }
            'ListBackups' { Show-Backups }
            'Configuration' { Show-Configuration }
            'SelfTest' { Invoke-SelfTest }
        }
    }
    Write-LabEvent -Event 'RunCompleted' -Status 'Pass' -Data @{ Mode = $Mode }
}
catch {
    Write-LabEvent -Event 'RunCompleted' -Status 'Failure' -Data @{ Mode = $Mode; Error = $_.Exception.Message }
    Write-Error $_.Exception.Message
    exit 1
}

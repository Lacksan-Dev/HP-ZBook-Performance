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
    [Parameter(Position = 0)]
    [Alias('Mode')]
    [string]$Action = 'Menu',

    [string]$BackupId,

    # Retained as no-op compatibility switches for version 0.1 commands.
    [switch]$AcceptExperimentalRisk,

    [switch]$AllowNoRestorePoint,

    [switch]$AllowManagedDevice,

    [ValidateRange(3, 21)]
    [int]$BenchmarkRuns = 7,

    [Security.SecureString]$AutoLoginPassword,

    [string]$RestartStateId,

    [string]$DataRoot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ToolName = 'Lacksan ZBook Performance'
$script:ToolVersion = '0.2.0-experimental'
$script:SchemaVersion = 1
$script:ScreeningEvidenceClass = 'PreProtocolScreening'
$script:FormalBaselineEligible = $false
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
$script:OriginalScriptPath = $PSCommandPath
$script:OriginalScriptText = $MyInvocation.MyCommand.Definition

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
        DesiredAC = [uint32]33
        Label = 'Processor energy performance preference (AC)'
        Tradeoff = 'Retains the measured balanced AC value; crossover screening found no consistent responsiveness benefit from the more aggressive value 0.'
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
        EnrollmentSpecificTaskCount = 0
        GenericMaintenanceTaskPresent = $false
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
        $tasks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object {
            $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*'
        })
        $values.EnterpriseMgmtTaskCount = @($tasks).Count
        $generic = @($tasks | Where-Object {
            $_.TaskPath -eq '\Microsoft\Windows\EnterpriseMgmt\' -and
            $_.TaskName -eq 'MDMMaintenenceTask'
        })
        $values.GenericMaintenanceTaskPresent = $generic.Count -gt 0
        $enrollmentSpecific = @($tasks | Where-Object {
            -not (
                $_.TaskPath -eq '\Microsoft\Windows\EnterpriseMgmt\' -and
                $_.TaskName -eq 'MDMMaintenenceTask'
            )
        })
        $values.EnrollmentSpecificTaskCount = $enrollmentSpecific.Count
    }
    catch {
        Write-LabEvent -Event 'EnterpriseManagementTaskRead' -Status 'Warning' -Data @{ Error = $_.Exception.Message }
    }

    $activeManagement = (
        $values.AzureAdJoined -or
        $values.EnterpriseJoined -or
        $values.DomainJoined -or
        $values.MdmUrlPresent -or
        $values.EnrollmentSpecificTaskCount -gt 0
    )

    return [pscustomobject]@{
        AzureAdJoined = $values.AzureAdJoined
        EnterpriseJoined = $values.EnterpriseJoined
        DomainJoined = $values.DomainJoined
        WorkplaceJoined = $values.WorkplaceJoined
        MdmUrlPresent = $values.MdmUrlPresent
        EnterpriseMgmtTaskCount = $values.EnterpriseMgmtTaskCount
        EnrollmentSpecificTaskCount = $values.EnrollmentSpecificTaskCount
        GenericMaintenanceTaskPresent = $values.GenericMaintenanceTaskPresent
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
        OnBattery = Get-IsOnBattery
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
        $reasons.Add('This PC appears to be controlled by a domain or device-management service. Tuning stopped to avoid conflicting with organization policy.')
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
    [StructLayout(LayoutKind.Sequential)]
    public struct SYSTEM_POWER_STATUS
    {
        public byte ACLineStatus;
        public byte BatteryFlag;
        public byte BatteryLifePercent;
        public byte SystemStatusFlag;
        public uint BatteryLifeTime;
        public uint BatteryFullLifeTime;
    }

    [DllImport("kernel32.dll")]
    public static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS Status);

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

function Initialize-AutoLogonNative {
    if ('LacksanAutoLogonNative' -as [type]) {
        return
    }

    $source = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class LacksanAutoLogonNative
{
    [StructLayout(LayoutKind.Sequential)]
    private struct LSA_OBJECT_ATTRIBUTES
    {
        public int Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public uint Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct LSA_UNICODE_STRING
    {
        public ushort Length;
        public ushort MaximumLength;
        public IntPtr Buffer;
    }

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool LogonUser(
        string lpszUsername,
        string lpszDomain,
        string lpszPassword,
        int dwLogonType,
        int dwLogonProvider,
        out IntPtr phToken);

    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr hObject);

    [DllImport("advapi32.dll", PreserveSig = true)]
    private static extern uint LsaOpenPolicy(
        IntPtr SystemName,
        ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
        uint DesiredAccess,
        out IntPtr PolicyHandle);

    [DllImport("advapi32.dll", PreserveSig = true)]
    private static extern uint LsaStorePrivateData(
        IntPtr PolicyHandle,
        ref LSA_UNICODE_STRING KeyName,
        IntPtr PrivateData);

    [DllImport("advapi32.dll", PreserveSig = true)]
    private static extern uint LsaRetrievePrivateData(
        IntPtr PolicyHandle,
        ref LSA_UNICODE_STRING KeyName,
        out IntPtr PrivateData);

    [DllImport("advapi32.dll")]
    private static extern uint LsaNtStatusToWinError(uint Status);

    [DllImport("advapi32.dll")]
    private static extern uint LsaClose(IntPtr PolicyHandle);

    [DllImport("advapi32.dll")]
    private static extern uint LsaFreeMemory(IntPtr Buffer);

    private const uint POLICY_CREATE_SECRET = 0x00000020;
    private const uint POLICY_GET_PRIVATE_INFORMATION = 0x00000004;

    private static LSA_UNICODE_STRING AllocateString(string value)
    {
        LSA_UNICODE_STRING result = new LSA_UNICODE_STRING();
        result.Buffer = Marshal.StringToHGlobalUni(value);
        result.Length = checked((ushort)(value.Length * 2));
        result.MaximumLength = checked((ushort)((value.Length + 1) * 2));
        return result;
    }

    private static void FreeString(ref LSA_UNICODE_STRING value)
    {
        if (value.Buffer != IntPtr.Zero)
        {
            Marshal.ZeroFreeGlobalAllocUnicode(value.Buffer);
            value.Buffer = IntPtr.Zero;
        }
    }

    private static IntPtr OpenPolicy(uint access)
    {
        LSA_OBJECT_ATTRIBUTES attributes = new LSA_OBJECT_ATTRIBUTES();
        attributes.Length = Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));
        IntPtr policy;
        uint status = LsaOpenPolicy(IntPtr.Zero, ref attributes, access, out policy);
        if (status != 0)
        {
            throw new Win32Exception((int)LsaNtStatusToWinError(status));
        }
        return policy;
    }

    public static bool ValidateCredential(string user, string domain, string password)
    {
        IntPtr token;
        bool valid = LogonUser(user, domain, password, 2, 0, out token);
        if (valid && token != IntPtr.Zero)
        {
            CloseHandle(token);
        }
        return valid;
    }

    public static void StoreDefaultPassword(string password)
    {
        IntPtr policy = OpenPolicy(POLICY_CREATE_SECRET);
        LSA_UNICODE_STRING key = AllocateString("DefaultPassword");
        LSA_UNICODE_STRING secret = new LSA_UNICODE_STRING();
        IntPtr secretPointer = IntPtr.Zero;
        try
        {
            if (password != null)
            {
                secret = AllocateString(password);
                secretPointer = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(LSA_UNICODE_STRING)));
                Marshal.StructureToPtr(secret, secretPointer, false);
            }
            uint status = LsaStorePrivateData(policy, ref key, secretPointer);
            if (status != 0)
            {
                throw new Win32Exception((int)LsaNtStatusToWinError(status));
            }
        }
        finally
        {
            if (secretPointer != IntPtr.Zero)
            {
                Marshal.FreeHGlobal(secretPointer);
            }
            FreeString(ref secret);
            FreeString(ref key);
            LsaClose(policy);
        }
    }

    public static bool HasDefaultPassword()
    {
        IntPtr policy = OpenPolicy(POLICY_GET_PRIVATE_INFORMATION);
        LSA_UNICODE_STRING key = AllocateString("DefaultPassword");
        IntPtr privateData = IntPtr.Zero;
        try
        {
            uint status = LsaRetrievePrivateData(policy, ref key, out privateData);
            if (status == 0)
            {
                return privateData != IntPtr.Zero;
            }
            uint win32 = LsaNtStatusToWinError(status);
            if (win32 == 2)
            {
                return false;
            }
            throw new Win32Exception((int)win32);
        }
        finally
        {
            if (privateData != IntPtr.Zero)
            {
                LsaFreeMemory(privateData);
            }
            FreeString(ref key);
            LsaClose(policy);
        }
    }
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

function Get-IsOnBattery {
    Initialize-PowerNative
    $status = New-Object LacksanPowerNative+SYSTEM_POWER_STATUS
    if (-not [LacksanPowerNative]::GetSystemPowerStatus([ref]$status)) {
        throw 'Windows could not report the current AC/battery state.'
    }
    if ($status.ACLineStatus -eq 255) {
        throw 'Windows reports an unknown AC/battery state.'
    }
    return $status.ACLineStatus -eq 0
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

function Get-RestartSafetyState {
    $taskName = 'Lacksan-ZBookPerformance-Resume'
    $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $autoAdmin = Get-RegistryState -Path $winlogon -Name 'AutoAdminLogon'
    $taskPresent = $false
    $taskVisibility = 'Available'
    $taskStateId = $null
    try {
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
        $taskPresent = $null -ne $task
        if ($taskPresent) {
            $taskArguments = @($task.Actions | ForEach-Object { [string]$_.Arguments }) -join ' '
            $stateMatch = [regex]::Match($taskArguments, '(?i)(?:^|\s)-RestartStateId\s+"?([A-Za-z0-9-]+)"?')
            if ($stateMatch.Success) {
                $taskStateId = $stateMatch.Groups[1].Value
            }
        }
    }
    catch {
        $taskVisibility = 'Unavailable'
    }

    $stateRoot = Join-Path $DataRoot 'RestartTests'
    $stateRecords = @()
    if (Test-Path -LiteralPath $stateRoot) {
        $stateRecords = @(
            Get-ChildItem -LiteralPath $stateRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'restart-state.json' } |
                Where-Object { Test-Path -LiteralPath $_ }
        )
    }
    $matchingTaskStatePresent = $false
    $matchingTaskStateValid = $false
    $matchingTaskStateStatus = 'NotApplicable'
    if ($taskPresent) {
        if ([string]::IsNullOrWhiteSpace($taskStateId)) {
            $matchingTaskStateStatus = 'TaskStateIdMissing'
        }
        else {
            $matchingTaskManifestPath = Join-Path (Join-Path $stateRoot $taskStateId) 'restart-state.json'
            $matchingTaskStatePresent = Test-Path -LiteralPath $matchingTaskManifestPath
            if (-not $matchingTaskStatePresent) {
                $matchingTaskStateStatus = 'ManifestMissing'
            }
            else {
                try {
                    $matchingTaskState = Read-IntegrityProtectedJson -Path $matchingTaskManifestPath
                    if (
                        [string]$matchingTaskState.StateId -cne $taskStateId -or
                        [string]$matchingTaskState.TaskName -cne $taskName
                    ) {
                        $matchingTaskStateStatus = 'IdentityMismatch'
                    }
                    else {
                        $matchingTaskStateValid = $true
                        $matchingTaskStateStatus = 'Valid'
                    }
                }
                catch {
                    $matchingTaskStateStatus = 'IntegrityInvalid'
                }
            }
        }
    }

    $registryPrepared = (
        $autoAdmin.ValueExists -and
        [string]$autoAdmin.Value -eq '1'
    )
    $recoveryNeeded = $registryPrepared -or $taskPresent
    $toolRecoveryAvailable = $taskPresent -and $matchingTaskStateValid

    return [pscustomobject]@{
        RecoveryNeeded = $recoveryNeeded
        RegistryPrepared = $registryPrepared
        ResumeTaskPresent = $taskPresent
        ResumeTaskVisibility = $taskVisibility
        TaskStateId = $taskStateId
        MatchingTaskStatePresent = $matchingTaskStatePresent
        MatchingTaskStateValid = $matchingTaskStateValid
        MatchingTaskStateStatus = $matchingTaskStateStatus
        ToolRecoveryAvailable = $toolRecoveryAvailable
        PreservedStateRecordCount = $stateRecords.Count
    }
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

    $states = Get-ConfigurationState
    $pending = @($states | Where-Object { -not $_.Compliant })
    $passedCount = $states.Count - $pending.Count
    Write-LabEvent -Event 'ConfigurationState' -Status $(if ($pending.Count -eq 0) { 'Pass' } else { 'Info' }) -Data @{
        PassedCount = $passedCount
        TotalCount = $states.Count
        PendingCount = $pending.Count
        PendingIds = @($pending | Select-Object -ExpandProperty Id)
    }
    $restartSafety = Get-RestartSafetyState
    Write-LabEvent -Event 'RestartSafetyState' -Status $(if ($restartSafety.RecoveryNeeded) { 'Warning' } else { 'Pass' }) -Data @{
        RecoveryNeeded = $restartSafety.RecoveryNeeded
        RegistryPrepared = $restartSafety.RegistryPrepared
        ResumeTaskPresent = $restartSafety.ResumeTaskPresent
        ResumeTaskVisibility = $restartSafety.ResumeTaskVisibility
        TaskStateId = $restartSafety.TaskStateId
        MatchingTaskStatePresent = $restartSafety.MatchingTaskStatePresent
        MatchingTaskStateValid = $restartSafety.MatchingTaskStateValid
        MatchingTaskStateStatus = $restartSafety.MatchingTaskStateStatus
        ToolRecoveryAvailable = $restartSafety.ToolRecoveryAvailable
        PreservedStateRecordCount = $restartSafety.PreservedStateRecordCount
    }
    Write-Host ''
    Write-Host "$($script:ToolName) $($script:ToolVersion)"
    Write-Host ''
    if ($support.Supported) {
        Write-Host 'READY TO TUNE: YES' -ForegroundColor Green
        Write-Host 'This is the HP ZBook model and Windows version validated by the lab.'
    }
    else {
        Write-Host 'READY TO TUNE: NO' -ForegroundColor Red
        foreach ($reason in $support.Reasons) {
            Write-Host "Why: $reason" -ForegroundColor Yellow
        }
    }
    Write-Host ''
    Write-Host "Computer: $($snapshot.Model)"
    Write-Host "Windows:  build $($snapshot.OsBuild), BIOS $($snapshot.BiosVersion)"
    if ($snapshot.JoinState.ActiveManagementDetected) {
        Write-Host 'Device control: organization management detected; Tune will stop unless explicitly overridden.' -ForegroundColor Yellow
    }
    elseif ($snapshot.JoinState.WorkplaceJoined) {
        Write-Host 'Device control: personal PC checks passed; a work account is connected but no active management endpoint was found.'
    }
    else {
        Write-Host 'Device control: personal/unmanaged checks passed.'
    }
    if ($pending.Count -eq 0) {
        Write-Host "Tuning state: APPLIED ($passedCount of $($states.Count) checks pass)" -ForegroundColor Green
    }
    else {
        Write-Host "Tuning state: NOT YET APPLIED ($passedCount of $($states.Count) checks pass; $($pending.Count) change(s) available)" -ForegroundColor Cyan
    }
    if ($restartSafety.RecoveryNeeded -and $restartSafety.ToolRecoveryAvailable) {
        Write-Host 'Restart test: ATTENTION - one-time auto-login or its resume task is still prepared.' -ForegroundColor Yellow
        Write-Host 'Recovery: run this tool with StopAutoLogin before leaving the computer unattended.' -ForegroundColor Yellow
    }
    elseif ($restartSafety.RegistryPrepared) {
        Write-Host 'Restart test: ATTENTION - Windows automatic sign-in is enabled, but no matching Lacksan recovery task and state record were found.' -ForegroundColor Yellow
        Write-Host 'Safety: this tool will not claim ownership or change that configuration automatically.' -ForegroundColor Yellow
    }
    elseif ($restartSafety.ResumeTaskPresent) {
        Write-Host 'Restart test: ATTENTION - the Lacksan resume task exists without its matching recovery record.' -ForegroundColor Yellow
        Write-Host 'Safety: automatic cleanup is not attempted because the original state cannot be verified.' -ForegroundColor Yellow
    }
    elseif ($restartSafety.ResumeTaskVisibility -eq 'Unavailable') {
        Write-Host 'Restart test: UNKNOWN - scheduled-task status could not be read. Run Check from an administrator PowerShell window.' -ForegroundColor Yellow
    }
    elseif ($restartSafety.PreservedStateRecordCount -gt 0) {
        Write-Host "Restart test: no active auto-login; $($restartSafety.PreservedStateRecordCount) preserved restart record(s)."
    }
    else {
        Write-Host 'Restart test: NOT PREPARED (automatic sign-in is off).'
    }
    Write-Host "Details log: $($script:CurrentLog)"
    return [pscustomobject]@{ Snapshot = $snapshot; Support = $support; RestartSafety = $restartSafety }
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

function Get-Median {
    param([Parameter(Mandatory = $true)][double[]]$Values)
    if ($Values.Count -eq 0) {
        return $null
    }
    $sorted = @($Values | Sort-Object)
    $middle = [math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) {
        return [double]$sorted[$middle]
    }
    return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2
}

function Measure-ProcessLaunch {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$Arguments
    )

    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FileName
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not $process.Start()) {
            throw "Could not start '$FileName'."
        }
        if (-not $process.WaitForExit(30000)) {
            try { $process.Kill() } catch {}
            throw "'$FileName' did not exit within 30 seconds."
        }
        $watch.Stop()
        if ($process.ExitCode -ne 0) {
            throw "'$FileName' exited with code $($process.ExitCode)."
        }
        return [double]$watch.Elapsed.TotalMilliseconds
    }
    finally {
        $watch.Stop()
        $process.Dispose()
    }
}

function Measure-CpuBurst {
    param([Parameter(Mandatory = $true)][byte[]]$Buffer)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        for ($index = 0; $index -lt 48; $index++) {
            [void]$algorithm.ComputeHash($Buffer)
        }
        $watch.Stop()
        return [double]$watch.Elapsed.TotalMilliseconds
    }
    finally {
        $watch.Stop()
        $algorithm.Dispose()
    }
}

function Get-BenchmarkRoot {
    $preferred = Join-Path $DataRoot 'Benchmarks'
    try {
        New-Item -ItemType Directory -Path $preferred -Force -ErrorAction Stop | Out-Null
        return $preferred
    }
    catch {
        $fallback = Join-Path $env:LOCALAPPDATA 'Lacksan\ZBookPerformance\Benchmarks'
        New-Item -ItemType Directory -Path $fallback -Force | Out-Null
        return $fallback
    }
}

function Wait-BenchmarkReady {
    param(
        [int]$StableSamplesRequired = 3,
        [int]$TimeoutSeconds = 30
    )
    $samples = @()
    $stable = 0
    $watch = [Diagnostics.Stopwatch]::StartNew()
    Write-Host 'Waiting briefly for low background activity...'
    while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds -and $stable -lt $StableSamplesRequired) {
        $entry = [ordered]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
            CpuPercent = $null
            DiskPercent = $null
            Status = 'Observed'
            Error = $null
        }
        try {
            $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction Stop
            $disk = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction Stop
            $entry.CpuPercent = [double]$cpu.PercentProcessorTime
            $entry.DiskPercent = [double]$disk.PercentDiskTime
            if ($entry.CpuPercent -le 20 -and $entry.DiskPercent -le 20) {
                $stable++
            }
            else {
                $stable = 0
            }
        }
        catch {
            $entry.Status = 'Unavailable'
            $entry.Error = $_.Exception.Message
            $stable++
        }
        $samples += [pscustomobject]$entry
        if ($stable -lt $StableSamplesRequired) {
            Start-Sleep -Seconds 1
        }
    }
    $watch.Stop()
    return [pscustomobject]@{
        Satisfied = $stable -ge $StableSamplesRequired
        StableSamplesRequired = $StableSamplesRequired
        TimeoutSeconds = $TimeoutSeconds
        WaitedSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
        Samples = $samples
    }
}

function Invoke-QuickBenchmark {
    param([ValidateSet('Current', 'Before', 'After', 'BeforeRestart', 'AfterRestart')][string]$Label = 'Current')

    $snapshot = Get-SystemSnapshot
    $support = Test-SupportedSystem -Snapshot $snapshot -PermitManaged:$AllowManagedDevice
    if (-not $support.Supported) {
        throw "Benchmark stopped: $(@($support.Reasons) -join ' ')"
    }
    if ($snapshot.OnBattery -and $Label -in @('Before', 'After')) {
        throw 'Plug in the ZBook before a before/after test. The candidate processor tuning changes AC power only.'
    }
    if ($snapshot.OnBattery) {
        Write-Host 'Power note: running on battery. This result cannot evaluate the AC-only tuning change.' -ForegroundColor Yellow
    }
    $readiness = Wait-BenchmarkReady
    $configuration = Get-ConfigurationState
    $pending = @($configuration | Where-Object { -not $_.Compliant })
    $configurationState = if ($pending.Count -eq 0) { 'Tuned' } else { 'Untuned' }
    $buffer = New-Object byte[] (4MB)
    for ($index = 0; $index -lt $buffer.Length; $index += 4096) {
        $buffer[$index] = [byte](($index / 4096) % 251)
    }

    $definitions = @(
        [pscustomobject]@{
            Id = 'Process.PowerShellStart'
            Name = 'PowerShell startup'
            Measure = {
                Measure-ProcessLaunch -FileName "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Arguments '-NoLogo -NoProfile -NonInteractive -Command "exit 0"'
            }
        },
        [pscustomobject]@{
            Id = 'Process.CommandPromptStart'
            Name = 'Command Prompt startup'
            Measure = {
                Measure-ProcessLaunch -FileName "$env:SystemRoot\System32\cmd.exe" -Arguments '/d /c exit 0'
            }
        },
        [pscustomobject]@{
            Id = 'Cpu.Sha256Burst'
            Name = 'CPU burst'
            Measure = {
                Measure-CpuBurst -Buffer $buffer
            }
        }
    )

    Write-Host ''
    Write-Host "Running quick benchmark: $Label / $configurationState"
    Write-Host "$BenchmarkRuns measured runs per test. Lower time is better."

    $metrics = foreach ($definition in $definitions) {
        $warmup = [ordered]@{ Status = 'Pass'; Milliseconds = $null; Error = $null }
        try {
            $warmup.Milliseconds = [math]::Round([double](& $definition.Measure), 3)
        }
        catch {
            $warmup.Status = 'Failure'
            $warmup.Error = $_.Exception.Message
        }

        $rawRuns = @()
        for ($run = 1; $run -le $BenchmarkRuns; $run++) {
            $entry = [ordered]@{
                Run = $run
                Status = 'Pass'
                Milliseconds = $null
                Error = $null
            }
            try {
                $entry.Milliseconds = [math]::Round([double](& $definition.Measure), 3)
            }
            catch {
                $entry.Status = 'Failure'
                $entry.Error = $_.Exception.Message
            }
            $rawRuns += [pscustomobject]$entry
        }
        $valid = @($rawRuns | Where-Object { $_.Status -eq 'Pass' } | Select-Object -ExpandProperty Milliseconds)
        $median = if ($valid.Count -gt 0) { [math]::Round((Get-Median -Values $valid), 3) } else { $null }
        [pscustomobject]@{
            Id = $definition.Id
            Name = $definition.Name
            Unit = 'ms'
            LowerIsBetter = $true
            Warmup = [pscustomobject]$warmup
            Runs = $rawRuns
            ValidRunCount = $valid.Count
            FailedRunCount = $BenchmarkRuns - $valid.Count
            Median = $median
        }
    }

    $record = [ordered]@{
        SchemaVersion = 1
        ToolVersion = $script:ToolVersion
        BenchmarkId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') + '-' + $script:RunId.Substring(0, 8)
        CapturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        Label = $Label
        ConfigurationState = $configurationState
        PendingSettingCount = $pending.Count
        RunCountRequested = $BenchmarkRuns
        EvidenceClass = $script:ScreeningEvidenceClass
        FormalBaselineEligible = $script:FormalBaselineEligible
        Environment = $snapshot
        Readiness = $readiness
        Metrics = @($metrics)
        Interpretation = 'Pre-protocol screening only. Excluded from the EXP-001 formal observational baseline and its workflow medians.'
    }
    $root = Get-BenchmarkRoot
    $path = Join-Path $root "$($record.BenchmarkId)-$Label-$configurationState.json"
    [IO.File]::WriteAllText($path, ($record | ConvertTo-Json -Depth 18), (New-Object Text.UTF8Encoding($false)))
    Write-LabEvent -Event 'QuickBenchmark' -Status $(if (@($metrics | Where-Object { $_.ValidRunCount -lt $BenchmarkRuns }).Count -eq 0) { 'Pass' } else { 'Warning' }) -Data @{
        BenchmarkId = $record.BenchmarkId
        Label = $Label
        ConfigurationState = $configurationState
        EvidenceClass = $record.EvidenceClass
        FormalBaselineEligible = $record.FormalBaselineEligible
        Path = $path
        Medians = @($metrics | Select-Object Id, Median, ValidRunCount, FailedRunCount)
    }

    Write-Host ''
    $metrics | Select-Object Name, Median, Unit, ValidRunCount, FailedRunCount | Format-Table -AutoSize | Out-Host
    Write-Host "Raw results: $path"
    Write-Host 'Evidence class: PRE-PROTOCOL SCREENING - excluded from the EXP-001 formal baseline.'
    return [pscustomobject]@{ Record = [pscustomobject]$record; Path = $path }
}

function Merge-BenchmarkBlocks {
    param(
        [Parameter(Mandatory = $true)][object[]]$Blocks,
        [Parameter(Mandatory = $true)][ValidateSet('Before', 'After')][string]$Label
    )
    if ($Blocks.Count -lt 2) {
        throw 'At least two benchmark blocks are required for an aggregate.'
    }
    $expectedConfigurationState = if ($Label -eq 'Before') { 'Untuned' } else { 'Tuned' }
    $blockRecords = @($Blocks | ForEach-Object { $_.Record })
    $stateMismatches = @($blockRecords | Where-Object { $_.ConfigurationState -cne $expectedConfigurationState })
    if ($stateMismatches.Count -gt 0) {
        throw "Cannot aggregate $Label blocks because $($stateMismatches.Count) block(s) do not report configuration state '$expectedConfigurationState'."
    }
    $pendingCounts = @(
        $blockRecords |
            ForEach-Object { [int]$_.PendingSettingCount } |
            Sort-Object -Unique
    )
    if ($pendingCounts.Count -ne 1) {
        throw "Cannot aggregate $Label blocks because their pending-setting counts are inconsistent."
    }
    $aggregatePendingCount = [int]$pendingCounts[0]
    if (
        ($expectedConfigurationState -eq 'Tuned' -and $aggregatePendingCount -ne 0) -or
        ($expectedConfigurationState -eq 'Untuned' -and $aggregatePendingCount -lt 1)
    ) {
        throw "Cannot aggregate $Label blocks because pending-setting count $aggregatePendingCount conflicts with configuration state '$expectedConfigurationState'."
    }
    $first = $Blocks[0].Record
    $metrics = foreach ($metric in $first.Metrics) {
        $combined = @()
        for ($blockIndex = 0; $blockIndex -lt $Blocks.Count; $blockIndex++) {
            $matching = @($Blocks[$blockIndex].Record.Metrics | Where-Object { $_.Id -eq $metric.Id }) | Select-Object -First 1
            foreach ($run in $matching.Runs) {
                $combined += [pscustomobject]@{
                    Block = $blockIndex + 1
                    Run = $run.Run
                    Status = $run.Status
                    Milliseconds = $run.Milliseconds
                    Error = $run.Error
                }
            }
        }
        $valid = @($combined | Where-Object { $_.Status -eq 'Pass' } | Select-Object -ExpandProperty Milliseconds)
        [pscustomobject]@{
            Id = $metric.Id
            Name = $metric.Name
            Unit = 'ms'
            LowerIsBetter = $true
            Warmup = $null
            Runs = $combined
            ValidRunCount = $valid.Count
            FailedRunCount = $combined.Count - $valid.Count
            Median = if ($valid.Count -gt 0) { [math]::Round((Get-Median -Values $valid), 3) } else { $null }
        }
    }
    $aggregate = [ordered]@{
        SchemaVersion = 1
        ToolVersion = $script:ToolVersion
        BenchmarkId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') + '-aggregate-' + $script:RunId.Substring(0, 8)
        CapturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        Label = $Label
        ConfigurationState = $expectedConfigurationState
        PendingSettingCount = $aggregatePendingCount
        RunCountRequested = @($metrics | Select-Object -First 1).Runs.Count
        EvidenceClass = $script:ScreeningEvidenceClass
        FormalBaselineEligible = $script:FormalBaselineEligible
        Environment = $first.Environment
        SourceBenchmarkIds = @($Blocks | ForEach-Object { $_.Record.BenchmarkId })
        Metrics = @($metrics)
        Interpretation = "Aggregate of $($Blocks.Count) raw blocks. Pre-protocol screening only; excluded from the EXP-001 formal baseline."
    }
    $root = Get-BenchmarkRoot
    $path = Join-Path $root "$($aggregate.BenchmarkId)-$Label-$($aggregate.ConfigurationState).json"
    [IO.File]::WriteAllText($path, ($aggregate | ConvertTo-Json -Depth 18), (New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{ Record = [pscustomobject]$aggregate; Path = $path }
}

function Show-BenchmarkComparison {
    param(
        [string]$BeforePath,
        [string]$AfterPath
    )

    $root = Get-BenchmarkRoot
    if ([string]::IsNullOrWhiteSpace($BeforePath)) {
        $beforeFile = Get-ChildItem -LiteralPath $root -Filter '*.json' -File |
            Sort-Object LastWriteTime -Descending |
            Where-Object {
                try { (Get-Content $_.FullName -Raw | ConvertFrom-Json).ConfigurationState -eq 'Untuned' } catch { $false }
            } |
            Select-Object -First 1
        if ($beforeFile) { $BeforePath = $beforeFile.FullName }
    }
    if ([string]::IsNullOrWhiteSpace($AfterPath)) {
        $afterFile = Get-ChildItem -LiteralPath $root -Filter '*.json' -File |
            Sort-Object LastWriteTime -Descending |
            Where-Object {
                try { (Get-Content $_.FullName -Raw | ConvertFrom-Json).ConfigurationState -eq 'Tuned' } catch { $false }
            } |
            Select-Object -First 1
        if ($afterFile) { $AfterPath = $afterFile.FullName }
    }
    if ([string]::IsNullOrWhiteSpace($BeforePath) -or [string]::IsNullOrWhiteSpace($AfterPath)) {
        throw 'A before/after pair was not found. Run Benchmark before Tune, run it again after Tune, then use Compare.'
    }

    $before = Get-Content -LiteralPath $BeforePath -Raw | ConvertFrom-Json
    $after = Get-Content -LiteralPath $AfterPath -Raw | ConvertFrom-Json
    $rows = foreach ($beforeMetric in $before.Metrics) {
        $afterMetric = @($after.Metrics | Where-Object { $_.Id -eq $beforeMetric.Id }) | Select-Object -First 1
        if (-not $afterMetric -or $null -eq $beforeMetric.Median -or $null -eq $afterMetric.Median) {
            continue
        }
        $change = if ([double]$beforeMetric.Median -ne 0) {
            [math]::Round((([double]$afterMetric.Median - [double]$beforeMetric.Median) / [double]$beforeMetric.Median) * 100, 1)
        }
        else { $null }
        $result = if ($null -eq $change) { 'Not comparable' }
            elseif ($change -lt 0) { "$([math]::Abs($change))% faster" }
            elseif ($change -gt 0) { "$change% slower" }
            else { 'No change' }
        [pscustomobject]@{
            Test = $beforeMetric.Name
            BeforeMs = [double]$beforeMetric.Median
            AfterMs = [double]$afterMetric.Median
            Result = $result
            ChangePercent = $change
        }
    }
    if (@($rows).Count -eq 0) {
        throw 'The selected benchmark files have no comparable successful metrics.'
    }

    Write-Host ''
    Write-Host 'Quick before/after comparison'
    $rows | Select-Object Test, BeforeMs, AfterMs, Result | Format-Table -AutoSize | Out-Host
    Write-Host 'Negative time is faster. Treat this as screening evidence until the controlled workflow protocol is complete.'

    $comparison = [ordered]@{
        SchemaVersion = 1
        CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        EvidenceClass = $script:ScreeningEvidenceClass
        FormalBaselineEligible = $script:FormalBaselineEligible
        BeforeBenchmarkId = $before.BenchmarkId
        AfterBenchmarkId = $after.BenchmarkId
        BeforePath = $BeforePath
        AfterPath = $AfterPath
        Results = @($rows)
        Decision = 'No design or customer claim from this quick comparison alone.'
    }
    $comparisonPath = Join-Path $root "$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ'))-comparison.json"
    [IO.File]::WriteAllText($comparisonPath, ($comparison | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    Write-Host "Comparison record: $comparisonPath"
    Write-LabEvent -Event 'BenchmarkComparison' -Status 'Pass' -Data @{ Path = $comparisonPath; Results = @($rows) }
    return [pscustomobject]@{ Record = [pscustomobject]$comparison; Path = $comparisonPath }
}

function Invoke-FullBeforeAfterTest {
    if (-not (Test-IsAdministrator)) {
        throw 'FullTest requires administrator rights.'
    }
    $snapshot = Get-SystemSnapshot
    $support = Test-SupportedSystem -Snapshot $snapshot -PermitManaged:$AllowManagedDevice
    if (-not $support.Supported) {
        throw "Before/after test stopped: $(@($support.Reasons) -join ' ')"
    }

    $initialState = Get-ConfigurationState
    $startedTuned = @($initialState | Where-Object { -not $_.Compliant }).Count -eq 0
    $beforeBlocks = @()
    $afterBlocks = @()
    try {
        if ($startedTuned) {
            Write-Host 'Restoring the latest protected pre-tune state for the before measurement...'
            Invoke-RestoreBackup -Path (Get-BackupPath)
            $restoredState = Get-ConfigurationState
            if (@($restoredState | Where-Object { -not $_.Compliant }).Count -eq 0) {
                throw 'The latest backup is already tuned, so it cannot provide a valid before state.'
            }
        }

        Write-Host 'Block A1: untuned'
        $beforeBlocks += Invoke-QuickBenchmark -Label Before
        Invoke-LabApply
        Write-Host 'Block B1: tuned'
        $afterBlocks += Invoke-QuickBenchmark -Label After
        Write-Host 'Block B2: tuned repeat'
        $afterBlocks += Invoke-QuickBenchmark -Label After

        Write-Host 'Restoring the protected pre-tune state for counterbalanced block A2...'
        Invoke-RestoreBackup -Path (Get-BackupPath)
        Write-Host 'Block A2: untuned repeat'
        $beforeBlocks += Invoke-QuickBenchmark -Label Before

        Write-Host 'Block B3: tuned, reversed-order session'
        Invoke-LabApply
        $afterBlocks += Invoke-QuickBenchmark -Label After
        Write-Host 'Block A3: untuned, reversed-order session'
        Invoke-RestoreBackup -Path (Get-BackupPath)
        $beforeBlocks += Invoke-QuickBenchmark -Label Before
        Write-Host 'Block A4: untuned repeat'
        $beforeBlocks += Invoke-QuickBenchmark -Label Before
        Write-Host 'Block B4: final tuned state'
        Invoke-LabApply
        $afterBlocks += Invoke-QuickBenchmark -Label After
        $beforeAggregate = Merge-BenchmarkBlocks -Blocks $beforeBlocks -Label Before
        $afterAggregate = Merge-BenchmarkBlocks -Blocks $afterBlocks -Label After
        [void](Show-BenchmarkComparison -BeforePath $beforeAggregate.Path -AfterPath $afterAggregate.Path)
        Write-Host ''
        Write-Host 'The aggregate uses both A-B-B-A and B-A-A-B orderings to reduce position bias.'
        Write-Host 'The tuned state is active. No restart was required for the quick CPU/process tests.'
        Write-Host 'Use RestartTest separately to validate settings that reload at sign-in.'
    }
    catch {
        $originalError = $_.Exception.Message
        if ($startedTuned) {
            try {
                $current = Get-ConfigurationState
                if (@($current | Where-Object { -not $_.Compliant }).Count -gt 0) {
                    Invoke-LabApply
                }
            }
            catch {
                throw "$originalError The test also could not restore the initial tuned state: $($_.Exception.Message)"
            }
        }
        throw $originalError
    }
}

function Get-PersistentScriptPath {
    if (-not [string]::IsNullOrWhiteSpace($script:OriginalScriptPath) -and (Test-Path -LiteralPath $script:OriginalScriptPath)) {
        return (Resolve-Path -LiteralPath $script:OriginalScriptPath).Path
    }
    if ([string]::IsNullOrWhiteSpace($script:OriginalScriptText) -or $script:OriginalScriptText.Length -lt 10000) {
        throw 'This action must run from the downloaded .ps1 file so Windows can resume it after restart.'
    }
    $cache = Join-Path $env:LOCALAPPDATA 'Lacksan\ZBookPerformance\Lacksan-ZBook-Performance.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $cache) -Force | Out-Null
    [IO.File]::WriteAllText($cache, $script:OriginalScriptText, (New-Object Text.UTF8Encoding($false)))
    return $cache
}

function Invoke-ElevatedRelaunch {
    param([Parameter(Mandatory = $true)][string]$RequestedAction)
    if (Test-IsAdministrator) {
        return $false
    }
    $scriptPath = Get-PersistentScriptPath
    $argumentLine = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" -Action "' + $RequestedAction + '" -BenchmarkRuns ' + $BenchmarkRuns
    if (-not [string]::IsNullOrWhiteSpace($BackupId)) {
        $argumentLine += ' -BackupId "' + $BackupId + '"'
    }
    if (-not [string]::IsNullOrWhiteSpace($DataRoot)) {
        $argumentLine += ' -DataRoot "' + $DataRoot + '"'
    }
    Write-Host 'Opening the administrator run...'
    $process = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Verb RunAs `
        -ArgumentList $argumentLine `
        -WindowStyle Normal `
        -Wait `
        -PassThru
    if ($process.ExitCode -ne 0) {
        throw "The administrator run ended with code $($process.ExitCode). Check the latest log for details."
    }
    return $true
}

function Get-RestartStateRoot {
    $root = Join-Path $DataRoot 'RestartTests'
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    return $root
}

function Write-IntegrityProtectedJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 18), (New-Object Text.UTF8Encoding($false)))
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    [IO.File]::WriteAllText($Path + '.sha256', $hash + [Environment]::NewLine, (New-Object Text.ASCIIEncoding))
}

function Read-IntegrityProtectedJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path) -or -not (Test-Path -LiteralPath ($Path + '.sha256'))) {
        throw "Restart state is incomplete at '$Path'."
    }
    $expected = (Get-Content -LiteralPath ($Path + '.sha256') -Raw).Trim()
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -cne $expected) {
        throw "Restart state integrity verification failed at '$Path'."
    }
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-AutoLoginRegistryCapture {
    $path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    foreach ($name in @('AutoAdminLogon', 'DefaultUserName', 'DefaultDomainName', 'AutoLogonCount', 'DefaultPassword')) {
        [pscustomobject]@{
            Id = "AutoLogin.$name"
            Path = $path
            Name = $name
            Original = Get-RegistryState -Path $path -Name $name
        }
    }
}

function Register-RestartResumeTask {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$StateId,
        [Parameter(Mandatory = $true)][string]$TaskName
    )
    if (Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue) {
        throw "The restart-resume task '$TaskName' already exists. Use StopAutoLogin before starting another restart test."
    }
    $quotedScript = '"' + $ScriptPath + '"'
    $quotedRoot = '"' + $DataRoot + '"'
    $arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File $quotedScript -Action Resume -RestartStateId $StateId -BenchmarkRuns $BenchmarkRuns -DataRoot $quotedRoot"
    $taskAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $principal = New-ScheduledTaskPrincipal `
        -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) `
        -LogonType Interactive `
        -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
    Register-ScheduledTask `
        -TaskName $TaskName `
        -TaskPath '\' `
        -Action $taskAction `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description 'One-time Lacksan ZBook post-restart verification and autologon cleanup.' `
        -Force | Out-Null
}

function Enable-OneTimeAutoLogin {
    param([Security.SecureString]$Password)
    if (-not (Test-IsAdministrator)) {
        throw 'RestartTest requires administrator rights.'
    }
    Initialize-AutoLogonNative
    $registryCapture = @(Get-AutoLoginRegistryCapture)
    $autoAdmin = $registryCapture | Where-Object { $_.Name -eq 'AutoAdminLogon' } | Select-Object -First 1
    $plainDefaultPassword = $registryCapture | Where-Object { $_.Name -eq 'DefaultPassword' } | Select-Object -First 1
    if (
        ($autoAdmin.Original.ValueExists -and [string]$autoAdmin.Original.Value -eq '1') -or
        $plainDefaultPassword.Original.ValueExists -or
        [LacksanAutoLogonNative]::HasDefaultPassword()
    ) {
        throw 'Windows auto-login is already configured. The tool will not overwrite an existing credential secret.'
    }
    if ($null -eq $Password) {
        $Password = Read-Host 'Enter this Windows account password (masked; never logged)' -AsSecureString
    }
    if ($null -eq $Password -or $Password.Length -eq 0) {
        throw 'A Windows account password is required for automatic sign-in.'
    }

    $scriptPath = Get-PersistentScriptPath
    $stateId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') + '-' + $script:RunId.Substring(0, 8)
    $taskName = 'Lacksan-ZBookPerformance-Resume'
    $stateFolder = Join-Path (Get-RestartStateRoot) $stateId
    New-Item -ItemType Directory -Path $stateFolder -Force | Out-Null
    $manifestPath = Join-Path $stateFolder 'restart-state.json'
    $manifest = [ordered]@{
        SchemaVersion = 1
        StateId = $stateId
        CreatedUtc = (Get-Date).ToUniversalTime().ToString('o')
        BootTimeBefore = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        UserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        UserName = $env:USERNAME
        Domain = $env:USERDOMAIN
        TaskName = $taskName
        ScriptPath = $scriptPath
        Registry = $registryCapture
        ExistingLsaSecret = $false
        Status = 'Prepared'
    }
    Write-IntegrityProtectedJson -Value $manifest -Path $manifestPath

    $bstr = [IntPtr]::Zero
    $plain = $null
    try {
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        if (-not [LacksanAutoLogonNative]::ValidateCredential($env:USERNAME, $env:USERDOMAIN, $plain)) {
            throw 'Windows rejected the supplied account password. Auto-login was not enabled.'
        }
        [LacksanAutoLogonNative]::StoreDefaultPassword($plain)
        $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        Set-RegistryValueExact -Path $winlogon -Name 'AutoAdminLogon' -Type String -Value '1'
        Set-RegistryValueExact -Path $winlogon -Name 'DefaultUserName' -Type String -Value $env:USERNAME
        Set-RegistryValueExact -Path $winlogon -Name 'DefaultDomainName' -Type String -Value $env:USERDOMAIN
        Set-RegistryValueExact -Path $winlogon -Name 'AutoLogonCount' -Type DWord -Value ([int]1)
        if ((Get-RegistryState -Path $winlogon -Name 'DefaultPassword').ValueExists) {
            Remove-ItemProperty -LiteralPath $winlogon -Name 'DefaultPassword' -Force
        }
        Register-RestartResumeTask -ScriptPath $scriptPath -StateId $stateId -TaskName $taskName
        Write-LabEvent -Event 'OneTimeAutoLoginEnabled' -Status 'Change' -Data @{
            StateId = $stateId
            TaskName = $taskName
            PasswordStorage = 'LSA secret'
        }
        return [pscustomobject]@{ StateId = $stateId; ManifestPath = $manifestPath; TaskName = $taskName }
    }
    catch {
        try { [LacksanAutoLogonNative]::StoreDefaultPassword($null) } catch {}
        foreach ($entry in $registryCapture) {
            try { Restore-RegistryState -Entry $entry } catch {}
        }
        try { Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false -ErrorAction SilentlyContinue } catch {}
        throw
    }
    finally {
        $plain = $null
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Restore-AutoLoginState {
    param([Parameter(Mandatory = $true)]$State)
    Initialize-AutoLogonNative
    [LacksanAutoLogonNative]::StoreDefaultPassword($null)
    foreach ($entry in $State.Registry) {
        Restore-RegistryState -Entry $entry
    }
    Unregister-ScheduledTask -TaskName $State.TaskName -TaskPath '\' -Confirm:$false -ErrorAction SilentlyContinue

    $verificationFailures = New-Object Collections.Generic.List[string]
    try {
        if ([LacksanAutoLogonNative]::HasDefaultPassword()) {
            $verificationFailures.Add('LsaSecretStillPresent')
        }
    }
    catch {
        $verificationFailures.Add('LsaSecretVerificationUnavailable')
    }
    foreach ($entry in $State.Registry) {
        try {
            $current = Get-RegistryState -Path $entry.Path -Name $entry.Name
            $matchesOriginal = $current.ValueExists -eq $entry.Original.ValueExists
            if ($matchesOriginal -and $entry.Original.ValueExists) {
                $matchesOriginal = (
                    [string]$current.Type -ceq [string]$entry.Original.Type -and
                    (Test-EquivalentValue -Actual $current.Value -Expected $entry.Original.Value -Type $entry.Original.Type)
                )
            }
            if (-not $matchesOriginal) {
                $verificationFailures.Add($entry.Id)
            }
        }
        catch {
            $verificationFailures.Add("$($entry.Id).VerificationUnavailable")
        }
    }
    try {
        if (Get-ScheduledTask -TaskName $State.TaskName -TaskPath '\' -ErrorAction SilentlyContinue) {
            $verificationFailures.Add('ResumeTaskStillPresent')
        }
    }
    catch {
        $verificationFailures.Add('ResumeTaskVerificationUnavailable')
    }
    if ($verificationFailures.Count -gt 0) {
        Write-LabEvent -Event 'AutoLoginCleanupVerification' -Status 'Failure' -Data @{
            StateId = $State.StateId
            Failures = @($verificationFailures)
        }
        throw "One-time auto-login cleanup could not be verified: $(@($verificationFailures) -join ', ')."
    }
    Write-LabEvent -Event 'AutoLoginCleanupVerification' -Status 'Pass' -Data @{
        StateId = $State.StateId
        RegistryValueCount = @($State.Registry).Count
        LsaSecretPresent = $false
        ResumeTaskPresent = $false
    }
    Write-LabEvent -Event 'OneTimeAutoLoginRemoved' -Status 'Pass' -Data @{ StateId = $State.StateId; TaskName = $State.TaskName }
}

function Get-RestartStateManifestPath {
    param([string]$StateId)
    $root = Get-RestartStateRoot
    if (-not [string]::IsNullOrWhiteSpace($StateId)) {
        $candidate = Join-Path (Join-Path $root $StateId) 'restart-state.json'
        if (-not (Test-Path -LiteralPath $candidate)) {
            throw "Restart state '$StateId' was not found."
        }
        return $candidate
    }
    $latest = Get-ChildItem -LiteralPath $root -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'restart-state.json' } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if (-not $latest) {
        throw 'No restart-test state was found.'
    }
    return $latest
}

function Invoke-RestartResume {
    if (-not (Test-IsAdministrator)) {
        throw 'The post-restart verification task did not receive administrator rights.'
    }
    $manifestPath = Get-RestartStateManifestPath -StateId $RestartStateId
    $state = Read-IntegrityProtectedJson -Path $manifestPath
    $verificationError = $null
    try {
        $currentBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
        if ($currentBoot -le [datetime]$state.BootTimeBefore) {
            throw 'Windows has not rebooted since the restart test was prepared.'
        }
        Invoke-LabVerify
        $benchmark = Invoke-QuickBenchmark -Label AfterRestart
        $result = [ordered]@{
            StateId = $state.StateId
            CompletedUtc = (Get-Date).ToUniversalTime().ToString('o')
            RebootObserved = $true
            Verification = 'Pass'
            BenchmarkPath = $benchmark.Path
        }
        Write-IntegrityProtectedJson -Value $result -Path (Join-Path (Split-Path -Parent $manifestPath) 'restart-result.json')
        Write-LabEvent -Event 'RestartPersistenceVerification' -Status 'Pass' -Data $result
    }
    catch {
        $verificationError = $_.Exception.Message
        Write-LabEvent -Event 'RestartPersistenceVerification' -Status 'Failure' -Data @{ StateId = $state.StateId; Error = $verificationError }
    }
    finally {
        Restore-AutoLoginState -State $state
    }
    if ($verificationError) {
        throw $verificationError
    }
    Write-Host 'Restart verification passed. One-time auto-login was removed.'
}

function Invoke-StopAutoLogin {
    if (-not (Test-IsAdministrator)) {
        throw 'StopAutoLogin requires administrator rights.'
    }
    $safety = Get-RestartSafetyState
    if (-not $safety.RecoveryNeeded) {
        throw 'No active Lacksan restart test was found. Automatic sign-in was not changed.'
    }
    if (-not $safety.ToolRecoveryAvailable) {
        throw 'Cleanup stopped because the active auto-login or resume task does not have a matching, valid Lacksan recovery record.'
    }
    if (
        -not [string]::IsNullOrWhiteSpace($RestartStateId) -and
        [string]$RestartStateId -cne [string]$safety.TaskStateId
    ) {
        throw "Cleanup stopped because requested state '$RestartStateId' does not match the active resume task."
    }
    $manifestPath = Get-RestartStateManifestPath -StateId $safety.TaskStateId
    $state = Read-IntegrityProtectedJson -Path $manifestPath
    Restore-AutoLoginState -State $state
    Write-Host 'The one-time auto-login credential and resume task were removed.'
}

function Invoke-RestartTest {
    if (-not (Test-IsAdministrator)) {
        throw 'RestartTest requires administrator rights.'
    }
    $snapshot = Get-SystemSnapshot
    $support = Test-SupportedSystem -Snapshot $snapshot -PermitManaged:$AllowManagedDevice
    if (-not $support.Supported) {
        throw "Restart test stopped: $(@($support.Reasons) -join ' ')"
    }
    $states = Get-ConfigurationState
    if (@($states | Where-Object { -not $_.Compliant }).Count -gt 0) {
        Invoke-LabApply
    }
    [void](Invoke-QuickBenchmark -Label BeforeRestart)
    $prepared = Enable-OneTimeAutoLogin -Password $AutoLoginPassword
    Write-Host ''
    Write-Host 'One-time automatic sign-in is enabled with an LSA-protected credential.' -ForegroundColor Yellow
    Write-Host 'Windows will restart in 30 seconds. Run shutdown /a to cancel the restart.'
    Write-Host 'After sign-in, the tool will verify persistence, run a quick benchmark, remove auto-login, and delete its resume task.'
    Write-LabEvent -Event 'RestartScheduled' -Status 'Change' -Data @{ StateId = $prepared.StateId; DelaySeconds = 30 }
    & "$env:SystemRoot\System32\shutdown.exe" /r /t 30 /d p:0:0 /c 'Lacksan ZBook performance restart verification'
    if ($LASTEXITCODE -ne 0) {
        $state = Read-IntegrityProtectedJson -Path $prepared.ManifestPath
        Restore-AutoLoginState -State $state
        throw "Windows rejected the restart request with code $LASTEXITCODE. Auto-login was removed."
    }
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
    Initialize-AutoLogonNative
    [void](Get-ActivePowerScheme)
    if (Test-IsAdministrator) {
        [void][LacksanAutoLogonNative]::HasDefaultPassword()
    }
    Write-LabEvent -Event 'SelfTest' -Status 'Pass' -Data @{ SettingCount = $ids.Count }
    Write-Host "Self-test passed for $($ids.Count) allow-listed settings."
}

function Resolve-FriendlyAction {
    param([string]$Requested)
    switch ($Requested.ToLowerInvariant()) {
        'menu' { return 'Menu' }
        'interactive' { return 'Menu' }
        'check' { return 'Check' }
        'audit' { return 'Check' }
        'benchmark' { return 'Benchmark' }
        'tune' { return 'Tune' }
        'apply' { return 'Tune' }
        'fulltest' { return 'FullTest' }
        'beforeafter' { return 'FullTest' }
        'compare' { return 'Compare' }
        'undo' { return 'Undo' }
        'rollback' { return 'Undo' }
        'restarttest' { return 'RestartTest' }
        'resume' { return 'Resume' }
        'stopautologin' { return 'StopAutoLogin' }
        'backups' { return 'Backups' }
        'listbackups' { return 'Backups' }
        'settings' { return 'Settings' }
        'configuration' { return 'Settings' }
        'details' { return 'Details' }
        'preview' { return 'Details' }
        'test' { return 'Test' }
        'selftest' { return 'Test' }
        'backup' { return 'Backup' }
        'verify' { return 'Check' }
        default {
            throw "Unknown action '$Requested'. Use Menu, Check, Benchmark, Tune, FullTest, Compare, Undo, RestartTest, StopAutoLogin, Backups, or Settings."
        }
    }
}

function Start-Interactive {
    do {
        Write-Host ''
        Write-Host "$($script:ToolName) $($script:ToolVersion) [EXPERIMENTAL]"
        Write-Host '1. Run complete before/after test'
        Write-Host '2. Run quick benchmark'
        Write-Host '3. Tune this ZBook'
        Write-Host '4. Check status'
        Write-Host '5. Undo tuning'
        Write-Host '6. Restart and verify automatically'
        Write-Host '7. More: settings and backups'
        Write-Host '8. Exit'
        $choice = Read-Host 'Choose'
        try {
            switch ($choice) {
                '1' {
                    if (-not (Invoke-ElevatedRelaunch -RequestedAction FullTest)) {
                        Invoke-FullBeforeAfterTest
                    }
                }
                '2' { [void](Invoke-QuickBenchmark -Label Current) }
                '3' {
                    if (-not (Invoke-ElevatedRelaunch -RequestedAction Tune)) {
                        Invoke-LabApply
                    }
                }
                '4' { [void](Show-Audit) }
                '5' {
                    if (-not (Invoke-ElevatedRelaunch -RequestedAction Undo)) {
                        Invoke-RestoreBackup -Path (Get-BackupPath)
                    }
                }
                '6' {
                    if (-not (Invoke-ElevatedRelaunch -RequestedAction RestartTest)) {
                        Invoke-RestartTest
                    }
                }
                '7' {
                    Show-Configuration
                    Show-Backups
                }
                '8' { return }
                default { Write-Host 'Unknown selection.' -ForegroundColor Yellow }
            }
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-LabEvent -Event 'InteractiveActionFailed' -Status 'Failure' -Data @{ Error = $_.Exception.Message; Choice = $choice }
        }
    } while ($true)
}

$resolvedAction = Resolve-FriendlyAction -Requested $Action
Initialize-LabLog -RequestedMode $resolvedAction
try {
    if ($WhatIfPreference -and $resolvedAction -in @('Tune', 'Backup', 'Undo', 'FullTest', 'RestartTest', 'StopAutoLogin')) {
        Write-Host '-WhatIf selected; showing the dry-run preview. No backup or setting is written.'
        [void](Show-Preview)
    }
    else {
        $elevatedActions = @('Tune', 'Backup', 'Undo', 'FullTest', 'RestartTest', 'StopAutoLogin')
        if ($resolvedAction -in $elevatedActions -and -not (Test-IsAdministrator)) {
            if (Invoke-ElevatedRelaunch -RequestedAction $resolvedAction) {
                Write-Host "$resolvedAction completed in the administrator window."
                Write-LabEvent -Event 'ElevatedRelaunchCompleted' -Status 'Pass' -Data @{ Action = $resolvedAction }
                Write-LabEvent -Event 'RunCompleted' -Status 'Pass' -Data @{ Action = $resolvedAction }
                exit 0
            }
        }
        switch ($resolvedAction) {
            'Menu' { Start-Interactive }
            'Check' { [void](Show-Audit) }
            'Benchmark' { [void](Invoke-QuickBenchmark -Label Current) }
            'Tune' { Invoke-LabApply }
            'FullTest' { Invoke-FullBeforeAfterTest }
            'Compare' { [void](Show-BenchmarkComparison) }
            'Undo' { Invoke-RestoreBackup -Path (Get-BackupPath -RequestedId $BackupId) }
            'RestartTest' { Invoke-RestartTest }
            'Resume' { Invoke-RestartResume }
            'StopAutoLogin' { Invoke-StopAutoLogin }
            'Backups' { Show-Backups }
            'Settings' { Show-Configuration }
            'Details' { [void](Show-Preview) }
            'Test' { Invoke-SelfTest }
            'Backup' {
                $snapshot = Get-SystemSnapshot
                $support = Test-SupportedSystem -Snapshot $snapshot -PermitManaged:$AllowManagedDevice
                if (-not $support.Supported) { throw "Support detection failed: $(@($support.Reasons) -join ' ')" }
                $backup = New-LabBackup -Snapshot $snapshot -PermitNoRestorePoint:$AllowNoRestorePoint
                Write-Host "Backup created: $($backup.Id)"
            }
        }
    }
    Write-LabEvent -Event 'RunCompleted' -Status 'Pass' -Data @{ Action = $resolvedAction }
}
catch {
    Write-LabEvent -Event 'RunCompleted' -Status 'Failure' -Data @{ Action = $resolvedAction; Error = $_.Exception.Message }
    Write-Error $_.Exception.Message
    exit 1
}

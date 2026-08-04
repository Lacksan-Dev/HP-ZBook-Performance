[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-120-state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-120.jsonl",
    [string]$SecurityFloorPath = "$env:ProgramData\Lacksan\EXP-120-security-floor.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Experiment = 'EXP-120'

function Write-ExpLog($Event, $Result, $Data) {
    $parent = Split-Path $LogPath -Parent
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [ordered]@{
        schemaVersion = 2
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        experiment = $Experiment
        action = $Action
        event = $Event
        result = $Result
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        data = $Data
    } | ConvertTo-Json -Compress -Depth 24 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Test-Elevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Same($Left, $Right) {
    ($Left | ConvertTo-Json -Compress -Depth 24) -eq ($Right | ConvertTo-Json -Compress -Depth 24)
}

function Resolve-ServiceExecutable($PathName) {
    $expanded = [Environment]::ExpandEnvironmentVariables(([string]$PathName).Trim())
    if ($expanded.StartsWith('"')) {
        $end = $expanded.IndexOf('"', 1)
        if ($end -gt 1) { return $expanded.Substring(1, $end - 1) }
    } elseif ($expanded -match '^([^ ]+\.exe)(?:\s|$)') {
        return $matches[1]
    }
    $null
}

function Get-ServiceRegistryValue($ServiceName, $ValueName) {
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
    if (!(Test-Path -LiteralPath $path)) { return [pscustomobject]@{ Exists=$false; Kind=$null; Data=$null } }
    $key = Get-Item -LiteralPath $path
    if ($key.GetValueNames() -notcontains $ValueName) { return [pscustomobject]@{ Exists=$false; Kind=$null; Data=$null } }
    [pscustomobject]@{
        Exists = $true
        Kind = $key.GetValueKind($ValueName).ToString()
        Data = $key.GetValue($ValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
}

function Get-ManagementState {
    $computer = Get-CimInstance Win32_ComputerSystem
    $enrollments = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^[0-9A-Fa-f-]{36}$' }).Count
    $omadm = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^[0-9A-Fa-f-]{36}$' }).Count
    $configMgr = [bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
    [pscustomobject]@{
        Managed = ([bool]$computer.PartOfDomain -or $configMgr -or ($enrollments -gt 0 -and $omadm -gt 0))
        DomainJoined = [bool]$computer.PartOfDomain
        EnrollmentCount = $enrollments
        OmadmCount = $omadm
        ConfigMgr = $configMgr
    }
}

function Get-ProtectedSnapshot {
    $services = @('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale') | ForEach-Object {
        Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue
    } | Where-Object { $_ } | Sort-Object Name | Select-Object Name,State,StartMode,PathName
    $devices = @(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
        $_.Class -match '(?i)keyboard|hidclass|system' -and $_.FriendlyName -match '(?i)HP|hotkey|keyboard|HID|ACPI'
    } | Sort-Object InstanceId | Select-Object InstanceId,Status,Class,FriendlyName)
    [pscustomobject]@{ Services=@($services); HotkeyDevices=$devices }
}

function Get-SecurityFloor($Model) {
    if (!(Test-Path -LiteralPath $SecurityFloorPath)) { return $null }
    $floor = Get-Content -LiteralPath $SecurityFloorPath -Raw | ConvertFrom-Json
    if ($floor.schemaVersion -ne 1 -or $floor.bulletin -ne 'HPSBHF04102 Rev. 2' -or $floor.model -ne $Model -or !$floor.minimumVersion -or !$floor.sourceUrl) { return $null }
    if ([string]$floor.sourceUrl -notmatch '^https://support\.hp\.com/.+hpsbhf04102') { return $null }
    $floor
}

function Get-HotkeyProducts {
    @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match '(?i)^HP Hotkey Support$' -and $_.Publisher -match '(?i)HP Inc|Hewlett-Packard' } |
        Select-Object DisplayName,DisplayVersion,Publisher,InstallLocation,PSChildName)
}

function Get-Candidate {
    $rows = @(Get-CimInstance Win32_Service -Filter "Name='HotKeyServiceUWP'")
    if ($rows.Count -ne 1) { return $null }
    $service = $rows[0]
    if ($service.DisplayName -notmatch '(?i)HP Hotkey UWP Service') { return $null }
    $exe = Resolve-ServiceExecutable $service.PathName
    if (!$exe -or !(Test-Path -LiteralPath $exe -PathType Leaf) -or [IO.Path]::GetFileName($exe) -ne 'HotKeyServiceUWP.exe') { return $null }
    $signature = Get-AuthenticodeSignature -LiteralPath $exe
    $publisher = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
    if ($signature.Status -ne 'Valid' -or $publisher -notmatch '(?i)HP Inc|Hewlett-Packard') { return $null }
    $product = @(Get-HotkeyProducts)
    if ($product.Count -ne 1) { return $null }
    $serviceApi = Get-Service $service.Name
    [pscustomobject]@{
        Name = $service.Name
        DisplayName = $service.DisplayName
        State = $service.State
        StartMode = $service.StartMode
        StartName = $service.StartName
        PathName = $service.PathName
        ServiceType = $service.ServiceType
        Dependencies = @($serviceApi.ServicesDependedOn | ForEach-Object Name | Sort-Object)
        Dependents = @($serviceApi.DependentServices | ForEach-Object Name | Sort-Object)
        RegistryStart = Get-ServiceRegistryValue $service.Name 'Start'
        DelayedAutoStart = Get-ServiceRegistryValue $service.Name 'DelayedAutoStart'
        RecoveryText = ((& sc.exe qfailure $service.Name 2>$null) -join "`n")
        TriggerText = ((& sc.exe qtriggerinfo $service.Name 2>$null) -join "`n")
        Executable = [pscustomobject]@{
            Path = $exe
            Version = (Get-Item -LiteralPath $exe).VersionInfo.FileVersion
            Sha256 = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
            Publisher = $publisher
            Thumbprint = $signature.SignerCertificate.Thumbprint
        }
        Product = $product[0]
    }
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $management = Get-ManagementState
    $candidate = Get-Candidate
    $securityFloor = Get-SecurityFloor $computer.Model
    $reasons = @()
    if ($os.Caption -notmatch 'Windows 11') { $reasons += 'Windows 11 required' }
    if ($computer.Manufacturer -notmatch '(?i)^HP$|Hewlett-Packard') { $reasons += 'HP platform required' }
    if (!(Test-Elevated)) { $reasons += 'elevation required' }
    if ($management.Managed) { $reasons += 'enterprise management ownership detected' }
    if (!$candidate) {
        $reasons += 'exact signed HotKeyServiceUWP and HP Hotkey Support identity required'
    } else {
        if ($candidate.ServiceType -match '(?i)driver') { $reasons += 'driver-backed service refused' }
        if ($candidate.Dependencies.Count -or $candidate.Dependents.Count) { $reasons += 'dependency-sensitive service refused' }
        if ($candidate.StartMode -notin @('Auto','Automatic') -or ($candidate.DelayedAutoStart.Exists -and [int]$candidate.DelayedAutoStart.Data -ne 0)) { $reasons += 'Automatic non-delayed baseline required' }
        if (!$securityFloor) {
            $reasons += 'model-bound HPSBHF04102 security floor evidence required'
        } else {
            try {
                if ([version]$candidate.Product.DisplayVersion -lt [version]$securityFloor.minimumVersion) { $reasons += 'HP Hotkey Support version below model security floor' }
            } catch { $reasons += 'security version comparison failed' }
        }
    }
    [pscustomobject]@{
        Supported = ($reasons.Count -eq 0)
        Reasons = $reasons
        OS = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        BIOS = Get-CimInstance Win32_BIOS | Select-Object SMBIOSBIOSVersion,ReleaseDate
        Elevated = Test-Elevated
        Management = $management
        SecurityFloor = $securityFloor
        Service = $candidate
        Protected = Get-ProtectedSnapshot
        EvidenceStatus = 'needs-evidence'
    }
}

function Save-State($Support) {
    if (Test-Path -LiteralPath $StatePath) { throw 'State overwrite refused.' }
    $parent = Split-Path $StatePath -Parent
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $state = [ordered]@{
        schemaVersion = 2
        experiment = $Experiment
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        capturedBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        support = $Support
        protected = $Support.Protected
        evidenceStatus = 'needs-evidence'
    }
    $state | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}

function Read-State {
    if (!(Test-Path -LiteralPath $StatePath)) { throw 'Captured state required.' }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.schemaVersion -ne 2 -or $state.experiment -ne $Experiment -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid) { throw 'State identity mismatch.' }
    $state
}

function Assert-NoDrift($State) {
    $current = Get-Candidate
    $original = $State.support.Service
    if (!$current -or $current.Name -ne $original.Name -or $current.PathName -ne $original.PathName -or $current.Executable.Sha256 -ne $original.Executable.Sha256 -or $current.Executable.Thumbprint -ne $original.Executable.Thumbprint -or $current.Product.DisplayVersion -ne $original.Product.DisplayVersion) { throw 'Service package or executable identity drift detected.' }
    if ((Get-ManagementState).Managed) { throw 'Management drift detected.' }
    if (!(Test-Same $current.Dependencies $original.Dependencies) -or !(Test-Same $current.Dependents $original.Dependents) -or $current.RecoveryText -ne $original.RecoveryText -or $current.TriggerText -ne $original.TriggerText) { throw 'Service dependency trigger or recovery drift detected.' }
    if (!(Test-Same (Get-ProtectedSnapshot) $State.protected)) { throw 'Protected security update remote-access or device state drift detected.' }
    $floor = Get-SecurityFloor $State.support.Model
    if (!$floor -or $floor.minimumVersion -ne $State.support.SecurityFloor.minimumVersion) { throw 'Security-floor evidence drift detected.' }
    $current
}

function Test-Delayed($Service) {
    $Service.StartMode -in @('Auto','Automatic') -and $Service.DelayedAutoStart.Exists -and [int]$Service.DelayedAutoStart.Data -eq 1
}

try {
    $support = Get-SupportState
    Write-ExpLog 'support-detection' $(if ($support.Supported) { 'pass' } else { 'refused' }) $support
    switch ($Action) {
        'Check' { $support }
        'Capture' {
            if (!$support.Supported) { throw ($support.Reasons -join '; ') }
            Save-State $support
        }
        'DryRun' {
            if (!$support.Supported) { throw ($support.Reasons -join '; ') }
            $result = [pscustomobject]@{
                WouldChange = $true
                MutationCount = 1
                Service = $support.Service.Name
                From = 'Automatic'
                To = 'Automatic (Delayed Start)'
                PreserveRunningState = $true
                RebootPersistenceRequired = $true
                Rollback = 'restore exact captured startup mode, DelayedAutoStart value/type/existence, and running state'
                EvidenceStatus = 'needs-evidence'
            }
            Write-ExpLog 'dry-run' 'pass' $result
            $result
        }
        'Apply' {
            $state = Read-State
            $current = Assert-NoDrift $state
            if (Test-Delayed $current) {
                Write-ExpLog 'apply' 'idempotent' @{ mutationCount=0 }
                return $current
            }
            if ($current.StartMode -ne $state.support.Service.StartMode -or !(Test-Same $current.DelayedAutoStart $state.support.Service.DelayedAutoStart)) { throw 'Configuration drift detected.' }
            $runningState = $current.State
            if ($WhatIfPreference) {
                Write-ExpLog 'apply' 'whatif' @{ mutationCount=0 }
                return
            }
            if ($PSCmdlet.ShouldProcess($current.Name, 'Set Automatic Delayed Start while preserving running state')) {
                Set-Service -Name $current.Name -StartupType Automatic
                $serviceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$($current.Name)"
                New-ItemProperty -LiteralPath $serviceKey -Name DelayedAutoStart -PropertyType DWord -Value 1 -Force | Out-Null
            } else { return }
            $after = Get-Candidate
            if (!(Test-Delayed $after) -or $after.State -ne $runningState) { throw 'Apply verification failed.' }
            Write-ExpLog 'apply' 'pass' @{ mutationCount=1; before=$current; after=$after }
            $after
        }
        'Verify' {
            $state = Read-State
            $current = Assert-NoDrift $state
            if (!(Test-Delayed $current)) { throw 'Delayed-start treatment absent.' }
            Write-ExpLog 'verify' 'pass' $current
            $current
        }
        'VerifyReboot' {
            $state = Read-State
            $current = Assert-NoDrift $state
            $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
            if ($boot -le [datetime]$state.capturedBootTime) { throw 'Later boot required.' }
            if (!(Test-Delayed $current)) { throw 'Treatment failed reboot persistence.' }
            Write-ExpLog 'verify-reboot' 'pass' @{ boot=$boot.ToString('o'); service=$current; evidenceStatus='needs-evidence' }
            $current
        }
        'Rollback' {
            $state = Read-State
            $current = Assert-NoDrift $state
            $original = $state.support.Service
            if (!(Test-Delayed $current)) {
                if ($current.StartMode -eq $original.StartMode -and $current.State -eq $original.State -and (Test-Same $current.DelayedAutoStart $original.DelayedAutoStart)) {
                    Write-ExpLog 'rollback' 'idempotent' @{ mutationCount=0 }
                    return $current
                }
                throw 'Rollback collision detected.'
            }
            if ($WhatIfPreference) {
                Write-ExpLog 'rollback' 'whatif' @{ mutationCount=0 }
                return
            }
            if ($PSCmdlet.ShouldProcess($current.Name, 'Restore exact captured HP Hotkey UWP service state')) {
                Set-Service -Name $current.Name -StartupType Automatic
                $serviceKey = "HKLM:\SYSTEM\CurrentControlSet\Services\$($current.Name)"
                if ($original.DelayedAutoStart.Exists) {
                    $kind = [Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$original.DelayedAutoStart.Kind, $true)
                    (Get-Item -LiteralPath $serviceKey).SetValue('DelayedAutoStart', $original.DelayedAutoStart.Data, $kind)
                } else {
                    Remove-ItemProperty -LiteralPath $serviceKey -Name DelayedAutoStart -ErrorAction SilentlyContinue
                }
                $serviceApi = Get-Service $current.Name
                if ($original.State -eq 'Running' -and $serviceApi.Status -ne 'Running') { Start-Service $current.Name }
                if ($original.State -eq 'Stopped' -and $serviceApi.Status -ne 'Stopped') { Stop-Service $current.Name }
            } else { return }
            $after = Get-Candidate
            if ($after.StartMode -ne $original.StartMode -or $after.State -ne $original.State -or !(Test-Same $after.DelayedAutoStart $original.DelayedAutoStart)) { throw 'Exact rollback verification failed.' }
            Write-ExpLog 'rollback' 'pass' @{ mutationCount=1; restoredExactOriginal=$true }
            $after
        }
    }
} catch {
    Write-ExpLog 'failure' 'fail' @{ stage=$Action; message=$_.Exception.Message; type=$_.Exception.GetType().FullName; evidenceStatus='needs-evidence' }
    throw
}

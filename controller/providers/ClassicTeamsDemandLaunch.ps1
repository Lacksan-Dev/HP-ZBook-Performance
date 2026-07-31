[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath,
    [string]$LogPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$experiment = 'EXP-049'
$provider = 'classic-teams-demand-launch'
$runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$valueName = 'com.squirrel.Teams.Teams'
$protectedPattern = '(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|securityhealth|defender|credential|bitlocker|firewall|windows update|recovery|intune|sccm|configmgr|mdm|ms-teams\.exe'

function Write-StructuredLog([string]$Event,[string]$Result,[object]$Data) {
    if ([string]::IsNullOrWhiteSpace($LogPath)) { return }
    $parent = Split-Path -Parent $LogPath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [ordered]@{
        schemaVersion = 1
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        experiment = $experiment
        provider = $provider
        action = $Action
        event = $Event
        result = $Result
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        data = $Data
    } | ConvertTo-Json -Compress -Depth 16 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)) | ForEach-Object { $_.ToString('x2') }) -join '' }
    finally { $sha.Dispose() }
}

function Get-ManagementState {
    $computer = Get-CimInstance Win32_ComputerSystem
    $signals = [ordered]@{
        DomainJoined = [bool]$computer.PartOfDomain
        MdmEnrollments = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count
        PolicyManager = Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device'
        ConfigMgr = [bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
        RunPolicy = (Test-Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run') -or (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run')
    }
    [pscustomobject]@{ Managed = ($signals.DomainJoined -or $signals.MdmEnrollments -gt 0 -or $signals.PolicyManager -or $signals.ConfigMgr -or $signals.RunPolicy); Signals = $signals }
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $management = Get-ManagementState
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match '(?i)^HP$|Hewlett-Packard')
        OS = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        Managed = $management.Managed
        ManagementSignals = $management.Signals
    }
}

function Get-ProtectedSnapshot {
    $services = foreach ($name in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale') {
        $service = Get-Service $name -ErrorAction SilentlyContinue
        if ($service) { [ordered]@{ Name = $service.Name; Status = $service.Status.ToString(); StartType = $service.StartType.ToString() } }
    }
    $newTeams = @(Get-AppxPackage -Name MSTeams -ErrorAction SilentlyContinue | ForEach-Object { [ordered]@{ Name = $_.Name; Version = $_.Version.ToString(); Status = $_.Status.ToString() } })
    $normalized = [ordered]@{ Services = @($services); NewTeamsPackages = @($newTeams) } | ConvertTo-Json -Compress -Depth 8
    [pscustomobject]@{ Hash = Get-TextHash $normalized; Snapshot = $normalized }
}

function Resolve-ClassicTeamsCommand([string]$Command) {
    $expanded = [Environment]::ExpandEnvironmentVariables($Command).Trim()
    $pattern = '^\s*"(?<update>[^"]+\\Update\.exe)"\s+--processStart\s+"?Teams\.exe"?\s+--process-start-args\s+"?--system-initiated"?\s*$'
    if ($expanded -notmatch $pattern) { return $null }
    $update = [IO.Path]::GetFullPath($matches.update)
    if ($update -notmatch '(?i)\\Microsoft\\Teams\\Update\.exe$' -or $update -match $protectedPattern) { return $null }
    $teams = Join-Path (Split-Path -Parent $update) 'current\Teams.exe'
    [pscustomobject]@{ ExpandedCommand = $expanded; UpdatePath = $update; TeamsPath = $teams }
}

function Get-FileIdentity([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $item = Get-Item -LiteralPath $Path
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    $publisher = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
    [pscustomobject]@{
        Path = $item.FullName
        Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        FileVersion = $item.VersionInfo.FileVersion
        ProductName = $item.VersionInfo.ProductName
        CompanyName = $item.VersionInfo.CompanyName
        SignatureStatus = $signature.Status.ToString()
        Publisher = $publisher
        PublisherThumbprint = if ($signature.SignerCertificate) { $signature.SignerCertificate.Thumbprint } else { $null }
        ValidMicrosoftPublisher = ($signature.Status -eq 'Valid' -and $publisher -match '(?i)Microsoft Corporation')
    }
}

function Get-Candidates {
    if (!(Test-Path -LiteralPath $runPath)) { return @() }
    $key = Get-Item -LiteralPath $runPath
    if (!($key.GetValueNames() -contains $valueName)) { return @() }
    $data = [string]$key.GetValue($valueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    if ($data -match $protectedPattern) { return @() }
    $resolved = Resolve-ClassicTeamsCommand $data
    if (!$resolved) { return @() }
    $updateIdentity = Get-FileIdentity $resolved.UpdatePath
    $teamsIdentity = Get-FileIdentity $resolved.TeamsPath
    if (!$updateIdentity -or !$teamsIdentity -or !$updateIdentity.ValidMicrosoftPublisher -or !$teamsIdentity.ValidMicrosoftPublisher) { return @() }
    $acl = Get-Acl -LiteralPath $runPath
    @([pscustomobject]@{
        Path = $runPath
        Name = $valueName
        Kind = $key.GetValueKind($valueName).ToString()
        Data = $data
        ExpandedCommand = $resolved.ExpandedCommand
        Update = $updateIdentity
        Teams = $teamsIdentity
        KeyOwner = $acl.Owner
        KeySddl = $acl.Sddl
    })
}

function Assert-Eligible([object]$Support,[object[]]$Candidates) {
    if (!$Support.Supported) { throw 'Provider requires an HP system running Windows 11.' }
    if ($Support.Managed) { throw 'Enterprise-management or enforced Run policy signals are present; mutation is refused.' }
    if ($Candidates.Count -eq 0) { throw 'No eligible exact classic Teams Squirrel Run registration was found.' }
    if ($Candidates.Count -gt 1) { throw 'Multiple eligible classic Teams Run registrations were found.' }
}

function Save-State([object]$Support,[object[]]$Candidates) {
    Assert-Eligible $Support $Candidates
    if ([string]::IsNullOrWhiteSpace($StatePath)) { throw 'StatePath is required.' }
    if (Test-Path -LiteralPath $StatePath) { throw 'State artifact already exists; overwrite refused.' }
    $protected = Get-ProtectedSnapshot
    $state = [ordered]@{
        schemaVersion = 1
        experiment = $experiment
        provider = $provider
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        capturedBootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        support = $Support
        protectedScopeHash = $protected.Hash
        entry = $Candidates[0]
    }
    $parent = Split-Path -Parent $StatePath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $state | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}

function Read-State {
    if ([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)) { throw 'State artifact is missing.' }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.schemaVersion -ne 1 -or $state.experiment -ne $experiment -or $state.provider -ne $provider -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid) { throw 'State identity validation failed.' }
    $state
}

function Test-Removed([object]$State) {
    if (!(Test-Path -LiteralPath $State.entry.Path)) { return $true }
    !((Get-Item -LiteralPath $State.entry.Path).GetValueNames() -contains [string]$State.entry.Name)
}

function Assert-BinaryIdentity([object]$State) {
    foreach ($name in 'Update','Teams') {
        $expected = $State.entry.$name
        $current = Get-FileIdentity ([string]$expected.Path)
        if (!$current -or !$current.ValidMicrosoftPublisher -or $current.Sha256 -ne [string]$expected.Sha256 -or $current.PublisherThumbprint -ne [string]$expected.PublisherThumbprint) { throw "Classic Teams $name binary identity drift detected." }
    }
}

function Test-Restored([object]$State) {
    if (!(Test-Path -LiteralPath $State.entry.Path)) { return $false }
    $key = Get-Item -LiteralPath $State.entry.Path
    if (!($key.GetValueNames() -contains [string]$State.entry.Name)) { return $false }
    $data = [string]$key.GetValue($State.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $data -eq [string]$State.entry.Data -and $key.GetValueKind($State.entry.Name).ToString() -eq [string]$State.entry.Kind
}

try {
    $support = Get-SupportState
    Write-StructuredLog 'support-detection' $(if ($support.Supported) { 'pass' } else { 'unsupported' }) $support
    switch ($Action) {
        'Check' {
            $candidates = Get-Candidates
            Write-StructuredLog 'candidate-inventory' 'pass' @{ count = $candidates.Count; names = @($candidates.Name) }
            [pscustomobject]@{ Support = $support; Candidates = $candidates; Profile = 'ClassicTeamsDemandLaunch' }
        }
        'Capture' {
            $state = Save-State $support (Get-Candidates)
            Write-StructuredLog 'capture' 'pass' @{ path = $state.entry.Path; name = $state.entry.Name }
            $state
        }
        'DryRun' {
            $candidates = Get-Candidates
            Assert-Eligible $support $candidates
            $result = [pscustomobject]@{ Profile = 'ClassicTeamsDemandLaunch'; WouldChange = $true; MutationCount = 1; Path = $candidates[0].Path; Name = $candidates[0].Name; PreserveClassicTeamsFiles = $true; PreserveNewTeamsStartupTask = $true; RebootPersistenceCheckRequired = $true; Rollback = 'Restore exact captured value name, kind, and unexpanded data.' }
            Write-StructuredLog 'dry-run' 'pass' $result
            $result
        }
        'Apply' {
            $state = if (Test-Path -LiteralPath $StatePath) { Read-State } else { Save-State $support (Get-Candidates) }
            if (Test-Removed $state) { Assert-BinaryIdentity $state; Write-StructuredLog 'apply' 'idempotent' @{ mutationCount = 0 }; return [pscustomobject]@{ Applied = $true; MutationCount = 0 } }
            Assert-Eligible $support (Get-Candidates)
            Assert-BinaryIdentity $state
            if ((Get-ProtectedSnapshot).Hash -ne [string]$state.protectedScopeHash) { throw 'Protected-scope drift detected.' }
            if ($WhatIfPreference) { Write-StructuredLog 'apply' 'whatif' @{ mutationCount = 0 }; return [pscustomobject]@{ Applied = $false; WhatIf = $true; MutationCount = 0 } }
            if ($PSCmdlet.ShouldProcess("$($state.entry.Path)::$($state.entry.Name)",'Remove exact classic Teams Run registration')) { Remove-ItemProperty -LiteralPath $state.entry.Path -Name $state.entry.Name }
            if (!(Test-Removed $state)) { throw 'Apply verification failed.' }
            Assert-BinaryIdentity $state
            Write-StructuredLog 'apply' 'pass' @{ mutationCount = 1 }
            [pscustomobject]@{ Applied = $true; MutationCount = 1 }
        }
        'Verify' {
            $state = Read-State
            if (!(Test-Removed $state)) { throw 'Immediate removal verification failed.' }
            Assert-BinaryIdentity $state
            Write-StructuredLog 'verify' 'pass' @{ removed = $true; binariesPreserved = $true }
            $true
        }
        'VerifyReboot' {
            $state = Read-State
            $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
            if ($boot -le [datetime]$state.capturedBootTime) { throw 'A later boot is required for reboot-persistence verification.' }
            if (!(Test-Removed $state)) { throw 'Reboot-persistence verification failed.' }
            Assert-BinaryIdentity $state
            Write-StructuredLog 'verify-reboot' 'pass' @{ bootTime = $boot.ToString('o'); removed = $true }
            $true
        }
        'Rollback' {
            $state = Read-State
            if (!(Test-Removed $state)) { if (Test-Restored $state) { Write-StructuredLog 'rollback' 'idempotent' @{ mutationCount = 0 }; return [pscustomobject]@{ RolledBack = $true; MutationCount = 0 } }; throw 'Rollback overwrite refused because the destination value exists.' }
            if ($support.Managed) { throw 'Enterprise-management ownership appeared; rollback refused.' }
            Assert-BinaryIdentity $state
            if ((Get-ProtectedSnapshot).Hash -ne [string]$state.protectedScopeHash) { throw 'Rollback protected-scope drift detected.' }
            if ($WhatIfPreference) { Write-StructuredLog 'rollback' 'whatif' @{ mutationCount = 0 }; return [pscustomobject]@{ RolledBack = $false; WhatIf = $true; MutationCount = 0 } }
            if ($PSCmdlet.ShouldProcess("$($state.entry.Path)::$($state.entry.Name)",'Restore exact classic Teams Run registration')) {
                if (!(Test-Path -LiteralPath $state.entry.Path)) { New-Item -Path $state.entry.Path -Force | Out-Null }
                (Get-Item -LiteralPath $state.entry.Path).SetValue([string]$state.entry.Name,[string]$state.entry.Data,[Microsoft.Win32.RegistryValueKind]::$($state.entry.Kind))
            }
            if (!(Test-Restored $state)) { throw 'Exact rollback verification failed.' }
            Write-StructuredLog 'rollback' 'pass' @{ mutationCount = 1; restoredExactOriginal = $true }
            [pscustomobject]@{ RolledBack = $true; MutationCount = 1 }
        }
    }
} catch {
    Write-StructuredLog 'failure' 'fail' @{ stage = $Action; message = $_.Exception.Message; type = $_.Exception.GetType().FullName; statePath = $StatePath }
    throw
}

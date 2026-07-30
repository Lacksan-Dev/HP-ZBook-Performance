[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath = (Join-Path $PSScriptRoot 'state.json'),
    [string]$LogPath = (Join-Path $PSScriptRoot 'events.jsonl')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Experiment = 'EXP-080'
$script:RunPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
$script:ProtectedTokens = @(
    'omnissa','vmware horizon','windows app','remote desktop','mstsc','tailscale',
    'windows security','securityhealth','defender','credential','bitlocker','firewall',
    'accessibility','narrator','magnify','windows update','recovery'
)

function Write-ExpLog {
    param([string]$Event,[string]$Result,[hashtable]$Data = @{})
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $record = [ordered]@{
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        experiment   = $script:Experiment
        action       = $Action
        event        = $Event
        result       = $Result
        data         = $Data
    }
    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Compress -Depth 10) -Encoding UTF8
}

function Test-IsElevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $isWindows11 = $os.Caption -match 'Windows 11'
    $isHp = $computer.Manufacturer -match 'HP|Hewlett-Packard'
    [pscustomobject]@{
        Supported    = ($isWindows11 -and $isHp)
        OS           = $os.Caption
        Build        = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model        = $computer.Model
        Elevated     = Test-IsElevated
    }
}

function Test-EnterpriseManaged {
    $signals = [ordered]@{}
    $signals.DomainJoined = [bool](Get-CimInstance Win32_ComputerSystem).PartOfDomain
    $signals.MdmEnrollments = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count
    $signals.PolicyManager = Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device'
    $signals.ConfigMgr = [bool](Get-Service -Name CcmExec -ErrorAction SilentlyContinue)
    $managed = $signals.DomainJoined -or $signals.MdmEnrollments -gt 0 -or $signals.PolicyManager -or $signals.ConfigMgr
    [pscustomobject]@{ Managed = $managed; Signals = $signals }
}

function Test-ProtectedIdentity {
    param([string]$Name,[string]$Command)
    $identity = ($Name + ' ' + $Command).ToLowerInvariant()
    foreach ($token in $script:ProtectedTokens) { if ($identity.Contains($token)) { return $true } }
    return $false
}

function Resolve-CommandExecutable {
    param([string]$Command)
    $expanded = [Environment]::ExpandEnvironmentVariables($Command).Trim()
    $candidate = $null
    if ($expanded -match '^\s*"([^"]+\.exe)"') { $candidate = $matches[1] }
    elseif ($expanded -match '^\s*([^\s]+\.exe)') { $candidate = $matches[1] }
    if (-not $candidate) { return $null }
    try { return [IO.Path]::GetFullPath($candidate) } catch { return $null }
}

function Get-PublisherState {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    $subject = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
    [pscustomobject]@{
        Status = $signature.Status.ToString()
        Subject = $subject
        ValidLogitech = ($signature.Status -eq 'Valid' -and $subject -match '(?i)(Logitech|Logi)')
    }
}

function Test-ApprovedIdentity {
    param([string]$Name,[string]$Command,[string]$Executable)
    if (Test-ProtectedIdentity $Name $Command) { return $false }
    $nameMatch = $Name -match '(?i)^(Logitech Download Assistant|Logi Download Assistant|LogitechDownloadAssistant|LDA)$'
    $exeMatch = $Executable -match '(?i)\\(Logitech Download Assistant|Logi Download Assistant)\\.*\.exe$' -or
                [IO.Path]::GetFileName($Executable) -match '(?i)^(LogiLDA|LogitechDownloadAssistant|LDA)\.exe$'
    $excluded = ($Name + ' ' + $Command + ' ' + $Executable) -match '(?i)(options|g hub|bolt|tune|firmware|driver|receiver|unifying|update|updater)'
    return ($nameMatch -and $exeMatch -and -not $excluded)
}

function Get-RunCandidates {
    $items = foreach ($path in $script:RunPaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $key = Get-Item -LiteralPath $path
        foreach ($name in $key.GetValueNames()) {
            $data = [string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $exe = Resolve-CommandExecutable $data
            if (-not $exe) { continue }
            if (-not (Test-ApprovedIdentity $name $data $exe)) { continue }
            $publisher = Get-PublisherState $exe
            if (-not $publisher -or -not $publisher.ValidLogitech) { continue }
            [pscustomobject]@{
                Path = $path
                Name = $name
                Kind = $key.GetValueKind($name).ToString()
                Data = $data
                Executable = $exe
                PublisherStatus = $publisher.Status
                PublisherSubject = $publisher.Subject
                Scope = if ($path.StartsWith('HKCU:')) { 'CurrentUser' } else { 'LocalMachine' }
            }
        }
    }
    return @($items)
}

function Assert-SingleCandidate {
    param([object[]]$Candidates)
    if ($Candidates.Count -eq 0) { throw 'No eligible Logitech Download Assistant Run registration was found.' }
    if ($Candidates.Count -gt 1) { throw 'Multiple eligible Logitech Download Assistant Run registrations were found.' }
    if ($Candidates[0].Scope -eq 'LocalMachine' -and -not (Test-IsElevated)) { throw 'Elevation is required for the machine-wide registration.' }
}

function Save-State {
    param([object[]]$Candidates)
    Assert-SingleCandidate $Candidates
    $state = [ordered]@{
        schemaVersion = 1
        experiment = $script:Experiment
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        entry = $Candidates[0]
    }
    $parent = Split-Path -Parent $StatePath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $state | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    return $state
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.schemaVersion -ne 1 -or $state.experiment -ne $script:Experiment -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid) {
        throw 'State identity validation failed.'
    }
    return $state
}

function Test-EntryMatchesState {
    param($Entry,$StateEntry)
    return ($Entry.Path -eq $StateEntry.Path -and $Entry.Name -eq $StateEntry.Name -and $Entry.Kind -eq $StateEntry.Kind -and
            $Entry.Data -eq $StateEntry.Data -and $Entry.Executable -eq $StateEntry.Executable -and
            $Entry.PublisherSubject -eq $StateEntry.PublisherSubject)
}

function Test-Removed {
    param($State)
    if (-not (Test-Path -LiteralPath $State.entry.Path)) { return $true }
    $key = Get-Item -LiteralPath $State.entry.Path
    return -not ($key.GetValueNames() -contains [string]$State.entry.Name)
}

function Test-Restored {
    param($State)
    if (-not (Test-Path -LiteralPath $State.entry.Path)) { return $false }
    $key = Get-Item -LiteralPath $State.entry.Path
    if (-not ($key.GetValueNames() -contains [string]$State.entry.Name)) { return $false }
    $actual = [string]$key.GetValue($State.entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $kind = $key.GetValueKind($State.entry.Name).ToString()
    return ($actual -eq [string]$State.entry.Data -and $kind -eq [string]$State.entry.Kind)
}

try {
    $support = Get-SupportState
    Write-ExpLog 'support-detection' ($(if ($support.Supported) { 'pass' } else { 'unsupported' })) @{
        os=$support.OS; build=$support.Build; manufacturer=$support.Manufacturer; model=$support.Model; elevated=$support.Elevated
    }
    if (-not $support.Supported) { throw 'EXP-080 supports HP systems running Windows 11 only.' }

    $management = Test-EnterpriseManaged
    Write-ExpLog 'enterprise-management-detection' ($(if ($management.Managed) { 'refused' } else { 'pass' })) @{ signals=$management.Signals }
    if ($management.Managed) { throw 'Enterprise-management signals are present; mutation is refused.' }

    switch ($Action) {
        'Check' {
            $candidates = Get-RunCandidates
            Write-ExpLog 'candidate-inventory' 'pass' @{ count=$candidates.Count; names=@($candidates.Name); paths=@($candidates.Path) }
            $candidates
        }
        'Capture' {
            $state = Save-State (Get-RunCandidates)
            Write-ExpLog 'state-capture' 'pass' @{ statePath=$StatePath; path=$state.entry.Path; name=$state.entry.Name }
            $state
        }
        'DryRun' {
            $candidates = Get-RunCandidates
            Assert-SingleCandidate $candidates
            Write-ExpLog 'dry-run' 'pass' @{ path=$candidates[0].Path; name=$candidates[0].Name; executable=$candidates[0].Executable }
            [pscustomobject]@{ WouldRemove=$candidates[0]; StatePath=$StatePath }
        }
        'Apply' {
            if (Test-Path -LiteralPath $StatePath) {
                $state = Read-State
                $current = Get-RunCandidates
                if ($current.Count -eq 0 -and (Test-Removed $state)) {
                    Write-ExpLog 'apply' 'idempotent' @{ path=$state.entry.Path; name=$state.entry.Name }
                    [pscustomobject]@{ Applied=$false; Idempotent=$true }
                    break
                }
                Assert-SingleCandidate $current
                if (-not (Test-EntryMatchesState $current[0] $state.entry)) { throw 'Current candidate differs from captured state.' }
            } else {
                $state = Save-State (Get-RunCandidates)
            }
            if ($PSCmdlet.ShouldProcess("$($state.entry.Path)::$($state.entry.Name)",'Remove Logitech Download Assistant startup registration')) {
                Remove-ItemProperty -LiteralPath $state.entry.Path -Name $state.entry.Name
            }
            if (-not (Test-Removed $state)) { throw 'Apply verification failed.' }
            Write-ExpLog 'apply' 'pass' @{ path=$state.entry.Path; name=$state.entry.Name }
            [pscustomobject]@{ Applied=$true; Removed=1 }
        }
        'Verify' {
            $state = Read-State
            $ok = Test-Removed $state
            Write-ExpLog 'verify' ($(if ($ok) { 'pass' } else { 'fail' })) @{ path=$state.entry.Path; name=$state.entry.Name }
            if (-not $ok) { throw 'Removal verification failed.' }
            $true
        }
        'VerifyReboot' {
            $state = Read-State
            $ok = Test-Removed $state
            $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            Write-ExpLog 'verify-reboot' ($(if ($ok) { 'pass' } else { 'fail' })) @{ bootTime=$boot; path=$state.entry.Path; name=$state.entry.Name }
            if (-not $ok) { throw 'Reboot persistence verification failed.' }
            $true
        }
        'Rollback' {
            $state = Read-State
            if (-not (Test-Removed $state)) { throw 'Rollback refused because the registry value already exists.' }
            $publisher = Get-PublisherState ([string]$state.entry.Executable)
            if (-not $publisher -or -not $publisher.ValidLogitech -or $publisher.Subject -ne [string]$state.entry.PublisherSubject) {
                throw 'Rollback refused because executable publisher identity drifted.'
            }
            if ($state.entry.Scope -eq 'LocalMachine' -and -not (Test-IsElevated)) { throw 'Elevation is required for machine-wide rollback.' }
            if ($PSCmdlet.ShouldProcess("$($state.entry.Path)::$($state.entry.Name)",'Restore Logitech Download Assistant startup registration')) {
                if (-not (Test-Path -LiteralPath $state.entry.Path)) { New-Item -Path $state.entry.Path -Force | Out-Null }
                $key = Get-Item -LiteralPath $state.entry.Path
                $kind = [Microsoft.Win32.RegistryValueKind]::$($state.entry.Kind)
                $key.SetValue([string]$state.entry.Name,[string]$state.entry.Data,$kind)
            }
            if (-not (Test-Restored $state)) { throw 'Rollback verification failed.' }
            Write-ExpLog 'rollback' 'pass' @{ path=$state.entry.Path; name=$state.entry.Name }
            [pscustomobject]@{ RolledBack=$true; Restored=1 }
        }
    }
} catch {
    Write-ExpLog 'failure' 'fail' @{ message=$_.Exception.Message; type=$_.Exception.GetType().FullName }
    throw
}

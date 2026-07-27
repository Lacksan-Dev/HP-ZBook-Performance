Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExperimentId = 'EXP-021'
$script:RunPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:StateSchema = 1

function Write-Exp021Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Result,
        [hashtable]$Data = @{}
    )
    $record = [ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        experimentId = $script:ExperimentId
        action = $Action
        result = $Result
        data = $Data
    }
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    ($record | ConvertTo-Json -Depth 8 -Compress) | Add-Content -LiteralPath $Path -Encoding utf8
}

function Test-Exp021Support {
    [CmdletBinding()]
    param()
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $manufacturer = [string]$computer.Manufacturer
    $isWindows11 = ([version]$os.Version).Build -ge 22000
    $isHp = $manufacturer -match '(?i)\bHP\b|Hewlett[- ]Packard'
    [pscustomobject]@{
        Supported = ($isWindows11 -and $isHp)
        WindowsVersion = [string]$os.Version
        WindowsBuild = ([version]$os.Version).Build
        Manufacturer = $manufacturer
        Reason = if (-not $isWindows11) { 'Windows 11 build 22000 or later is required.' } elseif (-not $isHp) { 'An HP system is required.' } else { 'Supported.' }
    }
}

function Get-Exp021Candidate {
    [CmdletBinding()]
    param()
    if (-not (Test-Path -LiteralPath $script:RunPath)) { return $null }
    $key = Get-Item -LiteralPath $script:RunPath
    foreach ($name in $key.GetValueNames()) {
        if ($name -notmatch '(?i)office.*sdx|sdx.*helper|officesdx') { continue }
        $command = [string]$key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ([string]::IsNullOrWhiteSpace($command)) { continue }
        if ($command -notmatch '(?i)(^|[\\/\s\"])(sdxhelper\.exe)([\"\s]|$)') {
            throw "Candidate value '$name' matched by name but command identity was not sdxhelper.exe. Refusing change."
        }
        return [pscustomobject]@{
            RegistryPath = $script:RunPath
            ValueName = $name
            Command = $command
            ValueKind = [string]$key.GetValueKind($name)
        }
    }
    return $null
}

function Save-Exp021State {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    $support = Test-Exp021Support
    if (-not $support.Supported) { throw $support.Reason }
    $candidate = Get-Exp021Candidate
    $state = [ordered]@{
        schemaVersion = $script:StateSchema
        experimentId = $script:ExperimentId
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        computerName = $env:COMPUTERNAME
        userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        candidatePresent = ($null -ne $candidate)
        candidate = $candidate
    }
    $directory = Split-Path -Parent $StatePath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding utf8
    return [pscustomobject]$state
}

function Read-Exp021State {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file '$StatePath' does not exist." }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.schemaVersion -ne $script:StateSchema -or $state.experimentId -ne $script:ExperimentId) {
        throw 'State identity mismatch.'
    }
    if ($state.computerName -ne $env:COMPUTERNAME) { throw 'State was captured on another computer.' }
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.userSid -ne $currentSid) { throw 'State was captured for another user.' }
    return $state
}

function Test-Exp021Applied {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    $state = Read-Exp021State -StatePath $StatePath
    if (-not $state.candidatePresent) {
        return [pscustomobject]@{ Applied = $true; Reason = 'Candidate was absent at capture.' }
    }
    if (-not (Test-Path -LiteralPath $script:RunPath)) {
        return [pscustomobject]@{ Applied = $true; Reason = 'Run key is absent.' }
    }
    $key = Get-Item -LiteralPath $script:RunPath
    $present = $key.GetValueNames() -contains [string]$state.candidate.ValueName
    [pscustomobject]@{ Applied = (-not $present); Reason = if ($present) { 'Candidate value remains.' } else { 'Candidate value is absent.' } }
}

function Invoke-Exp021Apply {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][string]$LogPath
    )
    if (-not (Test-Path -LiteralPath $StatePath)) { Save-Exp021State -StatePath $StatePath | Out-Null }
    $state = Read-Exp021State -StatePath $StatePath
    if (-not $state.candidatePresent) {
        Write-Exp021Log -Path $LogPath -Action 'Apply' -Result 'NoOp' -Data @{ reason = 'Candidate absent at capture.' }
        return Test-Exp021Applied -StatePath $StatePath
    }
    $current = Get-Exp021Candidate
    if ($null -eq $current) {
        Write-Exp021Log -Path $LogPath -Action 'Apply' -Result 'AlreadyApplied' -Data @{ valueName = $state.candidate.ValueName }
        return Test-Exp021Applied -StatePath $StatePath
    }
    if ($current.ValueName -ne $state.candidate.ValueName -or $current.Command -ne $state.candidate.Command -or $current.ValueKind -ne $state.candidate.ValueKind) {
        throw 'Current candidate differs from captured state. Refusing change.'
    }
    if ($PSCmdlet.ShouldProcess("$($current.RegistryPath)\$($current.ValueName)", 'Remove Office SDX Helper startup registration')) {
        Remove-ItemProperty -LiteralPath $current.RegistryPath -Name $current.ValueName
        $verification = Test-Exp021Applied -StatePath $StatePath
        if (-not $verification.Applied) { throw 'Application verification failed.' }
        Write-Exp021Log -Path $LogPath -Action 'Apply' -Result 'Success' -Data @{ valueName = $current.ValueName; command = $current.Command }
        return $verification
    }
    Write-Exp021Log -Path $LogPath -Action 'Apply' -Result 'DryRun' -Data @{ valueName = $current.ValueName; command = $current.Command }
    return [pscustomobject]@{ Applied = $false; Reason = 'Dry run.' }
}

function Test-Exp021Rollback {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    $state = Read-Exp021State -StatePath $StatePath
    if (-not $state.candidatePresent) {
        return [pscustomobject]@{ Restored = ($null -eq (Get-Exp021Candidate)); Reason = 'Candidate was absent at capture.' }
    }
    if (-not (Test-Path -LiteralPath $script:RunPath)) {
        return [pscustomobject]@{ Restored = $false; Reason = 'Run key is absent.' }
    }
    $key = Get-Item -LiteralPath $script:RunPath
    if ($key.GetValueNames() -notcontains [string]$state.candidate.ValueName) {
        return [pscustomobject]@{ Restored = $false; Reason = 'Captured value is absent.' }
    }
    $command = [string]$key.GetValue([string]$state.candidate.ValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    $kind = [string]$key.GetValueKind([string]$state.candidate.ValueName)
    $restored = ($command -eq [string]$state.candidate.Command -and $kind -eq [string]$state.candidate.ValueKind)
    [pscustomobject]@{ Restored = $restored; Reason = if ($restored) { 'Exact captured state restored.' } else { 'Restored value differs from captured state.' } }
}

function Invoke-Exp021Rollback {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][string]$LogPath
    )
    $state = Read-Exp021State -StatePath $StatePath
    if (-not $state.candidatePresent) {
        Write-Exp021Log -Path $LogPath -Action 'Rollback' -Result 'NoOp' -Data @{ reason = 'Candidate absent at capture.' }
        return Test-Exp021Rollback -StatePath $StatePath
    }
    $existing = $null
    if (Test-Path -LiteralPath $script:RunPath) {
        $key = Get-Item -LiteralPath $script:RunPath
        if ($key.GetValueNames() -contains [string]$state.candidate.ValueName) {
            $existing = [string]$key.GetValue([string]$state.candidate.ValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
    }
    if ($null -ne $existing -and $existing -ne [string]$state.candidate.Command) {
        throw 'A different value now occupies the captured name. Refusing rollback overwrite.'
    }
    if ($PSCmdlet.ShouldProcess("$($state.candidate.RegistryPath)\$($state.candidate.ValueName)", 'Restore exact Office SDX Helper startup registration')) {
        if (-not (Test-Path -LiteralPath $script:RunPath)) { New-Item -Path $script:RunPath -Force | Out-Null }
        $kind = [Microsoft.Win32.RegistryValueKind]::$([string]$state.candidate.ValueKind)
        $key = Get-Item -LiteralPath $script:RunPath
        $key.SetValue([string]$state.candidate.ValueName, [string]$state.candidate.Command, $kind)
        $verification = Test-Exp021Rollback -StatePath $StatePath
        if (-not $verification.Restored) { throw 'Rollback verification failed.' }
        Write-Exp021Log -Path $LogPath -Action 'Rollback' -Result 'Success' -Data @{ valueName = $state.candidate.ValueName }
        return $verification
    }
    Write-Exp021Log -Path $LogPath -Action 'Rollback' -Result 'DryRun' -Data @{ valueName = $state.candidate.ValueName }
    return [pscustomobject]@{ Restored = $false; Reason = 'Dry run.' }
}

function Test-Exp021RebootPersistence {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    $state = Read-Exp021State -StatePath $StatePath
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
    $captured = [DateTime]::Parse([string]$state.capturedAtUtc).ToUniversalTime()
    [pscustomobject]@{
        RebootOccurredAfterCapture = ($boot -gt $captured)
        LastBootUpTimeUtc = $boot.ToString('o')
        AppliedState = Test-Exp021Applied -StatePath $StatePath
    }
}

Export-ModuleMember -Function Test-Exp021Support,Get-Exp021Candidate,Save-Exp021State,Test-Exp021Applied,Invoke-Exp021Apply,Test-Exp021Rollback,Invoke-Exp021Rollback,Test-Exp021RebootPersistence

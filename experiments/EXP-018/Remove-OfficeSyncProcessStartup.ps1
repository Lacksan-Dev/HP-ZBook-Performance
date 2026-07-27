[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [ValidateSet('Detect','Capture','Apply','Verify','VerifyReboot','Rollback','VerifyRollback')]
    [string]$Action = 'Detect',
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-018\state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-018\events.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RunPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$CandidatePattern = '^OfficeSyncProcess$'

function Write-ExpLog {
    param([string]$Event,[hashtable]$Data=@{})
    $dir = Split-Path -Parent $LogPath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $record = [ordered]@{ timestamp=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-018'; event=$Event; data=$Data }
    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Compress -Depth 6) -Encoding UTF8
}

function Test-ExpSupport {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett-Packard')
        Windows = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
    }
}

function Get-Candidate {
    if (-not (Test-Path -LiteralPath $RunPath)) { return @() }
    $item = Get-ItemProperty -LiteralPath $RunPath
    foreach ($property in $item.PSObject.Properties) {
        if ($property.Name -match '^PS' -or $property.Name -notmatch $CandidatePattern) { continue }
        $command = [string]$property.Value
        if ($command -notmatch '(?i)(^|[\\/\"\s])OfficeSyncProcess\.exe([\"\s]|$)') {
            throw "Candidate name matched but command identity was unsafe: $($property.Name)"
        }
        [pscustomobject]@{ Name=$property.Name; Command=$command; Kind=(Get-Item -LiteralPath $RunPath).GetValueKind($property.Name).ToString() }
    }
}

function Save-State {
    $support = Test-ExpSupport
    if (-not $support.Supported) { throw 'EXP-018 supports HP systems running Windows 11 only.' }
    $candidates = @(Get-Candidate)
    $state = [ordered]@{ schema=1; experiment='EXP-018'; capturedUtc=(Get-Date).ToUniversalTime().ToString('o'); runPath=$RunPath; candidates=$candidates }
    $dir = Split-Path -Parent $StatePath
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Write-ExpLog 'state-captured' @{ count=$candidates.Count }
    $state
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.schema -ne 1 -or $state.experiment -ne 'EXP-018') { throw 'State file identity rejected.' }
    $state
}

function Apply-Change {
    $state = if (Test-Path -LiteralPath $StatePath) { Read-State } else { Save-State }
    foreach ($candidate in @($state.candidates)) {
        $current = Get-ItemProperty -LiteralPath $RunPath -Name $candidate.Name -ErrorAction SilentlyContinue
        if ($null -eq $current) { continue }
        $value = [string]$current.($candidate.Name)
        if ($value -ne [string]$candidate.Command) { throw "Current value diverged from captured state: $($candidate.Name)" }
        if ($PSCmdlet.ShouldProcess("$RunPath\$($candidate.Name)",'Remove Office Sync Process startup registration')) {
            Remove-ItemProperty -LiteralPath $RunPath -Name $candidate.Name
            Write-ExpLog 'candidate-removed' @{ name=$candidate.Name }
        }
    }
}

function Verify-Change {
    $state = Read-State
    $remaining = @()
    foreach ($candidate in @($state.candidates)) {
        if ($null -ne (Get-ItemProperty -LiteralPath $RunPath -Name $candidate.Name -ErrorAction SilentlyContinue)) { $remaining += $candidate.Name }
    }
    $ok = $remaining.Count -eq 0
    Write-ExpLog 'verify' @{ success=$ok; remaining=$remaining }
    if (-not $ok) { throw "Verification failed: $($remaining -join ', ')" }
    $true
}

function Restore-State {
    $state = Read-State
    foreach ($candidate in @($state.candidates)) {
        if ($PSCmdlet.ShouldProcess("$RunPath\$($candidate.Name)",'Restore Office Sync Process startup registration')) {
            New-Item -Path $RunPath -Force | Out-Null
            New-ItemProperty -LiteralPath $RunPath -Name $candidate.Name -Value ([string]$candidate.Command) -PropertyType ([string]$candidate.Kind) -Force | Out-Null
            Write-ExpLog 'candidate-restored' @{ name=$candidate.Name }
        }
    }
}

function Verify-Rollback {
    $state = Read-State
    foreach ($candidate in @($state.candidates)) {
        $current = Get-ItemProperty -LiteralPath $RunPath -Name $candidate.Name -ErrorAction SilentlyContinue
        if ($null -eq $current -or [string]$current.($candidate.Name) -ne [string]$candidate.Command) { throw "Rollback verification failed: $($candidate.Name)" }
    }
    Write-ExpLog 'rollback-verify' @{ success=$true }
    $true
}

switch ($Action) {
    'Detect' { Test-ExpSupport; Get-Candidate }
    'Capture' { Save-State }
    'Apply' { Apply-Change; Verify-Change }
    'Verify' { Verify-Change }
    'VerifyReboot' { Verify-Change }
    'Rollback' { Restore-State; Verify-Rollback }
    'VerifyRollback' { Verify-Rollback }
}

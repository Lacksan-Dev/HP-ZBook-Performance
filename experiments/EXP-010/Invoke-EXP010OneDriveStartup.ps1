[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Check','DryRun','Apply','Verify','Rollback','VerifyRollback')]
    [string]$Action = 'Check',
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-010\state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-010\activity.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$ValueName = 'OneDrive'

function Write-ExpLog {
    param([string]$Event,[hashtable]$Data)
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-010'; event=$Event; data=$Data } |
        ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $cs.Manufacturer -match 'HP|Hewlett-Packard')
        Manufacturer = $cs.Manufacturer
        Model = $cs.Model
        WindowsCaption = $os.Caption
        WindowsBuild = $os.BuildNumber
    }
}

function Get-CandidateState {
    $exists = Test-Path -LiteralPath $RunKey
    $value = $null
    if ($exists) {
        try { $value = (Get-ItemProperty -LiteralPath $RunKey -Name $ValueName -ErrorAction Stop).$ValueName } catch { }
    }
    $identityOk = $null -ne $value -and [string]$value -match '(?i)(^|[\\/\" ])OneDrive\.exe([\" ]|$)'
    [pscustomobject]@{ Path=$RunKey; Name=$ValueName; Exists=($null -ne $value); Data=$value; IdentityOk=$identityOk }
}

function Save-OriginalState {
    param($Support,$Candidate)
    $dir = Split-Path -Parent $StatePath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $record = [ordered]@{
        schemaVersion=1; experiment='EXP-010'; capturedUtc=(Get-Date).ToUniversalTime().ToString('o')
        support=$Support; candidate=$Candidate
    }
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    return $record
}

function Read-OriginalState {
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
    Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
}

$support = Get-SupportState
$candidate = Get-CandidateState

if ($Action -in @('Apply','Rollback') -and -not $support.Supported) { throw 'Unsupported system. EXP-010 requires an HP system running Windows 11.' }

switch ($Action) {
    'Check' {
        Write-ExpLog 'check' @{ supported=$support.Supported; exists=$candidate.Exists; identityOk=$candidate.IdentityOk }
        [pscustomobject]@{ Support=$support; Candidate=$candidate }
    }
    'DryRun' {
        if ($candidate.Exists -and -not $candidate.IdentityOk) { throw 'Refusing candidate because the Run value does not identify OneDrive.exe.' }
        Write-ExpLog 'dry-run' @{ wouldRemove=$candidate.Exists; path=$RunKey; name=$ValueName }
        [pscustomobject]@{ WouldRemove=$candidate.Exists; Candidate=$candidate; StatePath=$StatePath }
    }
    'Apply' {
        if ($candidate.Exists -and -not $candidate.IdentityOk) { throw 'Refusing candidate because the Run value does not identify OneDrive.exe.' }
        if (-not (Test-Path -LiteralPath $StatePath)) { Save-OriginalState $support $candidate | Out-Null }
        if ($candidate.Exists -and $PSCmdlet.ShouldProcess("$RunKey::$ValueName",'Remove OneDrive startup registration')) {
            Remove-ItemProperty -LiteralPath $RunKey -Name $ValueName -ErrorAction Stop
        }
        $after = Get-CandidateState
        if ($after.Exists) { throw 'Apply verification failed: OneDrive startup registration remains present.' }
        Write-ExpLog 'apply' @{ changed=$candidate.Exists; verified=$true }
        [pscustomobject]@{ Changed=$candidate.Exists; Verified=$true; StatePath=$StatePath }
    }
    'Verify' {
        $after = Get-CandidateState
        $ok = -not $after.Exists
        Write-ExpLog 'verify' @{ compliant=$ok }
        [pscustomobject]@{ Compliant=$ok; Candidate=$after }
    }
    'Rollback' {
        $saved = Read-OriginalState
        if ($saved.experiment -ne 'EXP-010' -or $saved.schemaVersion -ne 1) { throw 'Rollback state identity mismatch.' }
        $original = $saved.candidate
        if ($original.Exists) {
            if (-not ([string]$original.Data -match '(?i)(^|[\\/\" ])OneDrive\.exe([\" ]|$)')) { throw 'Rollback state command identity mismatch.' }
            if (-not (Test-Path -LiteralPath $RunKey)) { New-Item -Path $RunKey -Force | Out-Null }
            if ($PSCmdlet.ShouldProcess("$RunKey::$ValueName",'Restore OneDrive startup registration')) {
                New-ItemProperty -LiteralPath $RunKey -Name $ValueName -Value ([string]$original.Data) -PropertyType String -Force | Out-Null
            }
        } else {
            Remove-ItemProperty -LiteralPath $RunKey -Name $ValueName -ErrorAction SilentlyContinue
        }
        $after = Get-CandidateState
        $ok = ($after.Exists -eq [bool]$original.Exists) -and ((-not $after.Exists) -or ([string]$after.Data -eq [string]$original.Data))
        if (-not $ok) { throw 'Rollback verification failed.' }
        Write-ExpLog 'rollback' @{ restored=$true; originallyPresent=[bool]$original.Exists }
        [pscustomobject]@{ Restored=$true; Candidate=$after }
    }
    'VerifyRollback' {
        $saved = Read-OriginalState
        $original = $saved.candidate
        $after = Get-CandidateState
        $ok = ($after.Exists -eq [bool]$original.Exists) -and ((-not $after.Exists) -or ([string]$after.Data -eq [string]$original.Data))
        Write-ExpLog 'verify-rollback' @{ verified=$ok }
        [pscustomobject]@{ Verified=$ok; Candidate=$after }
    }
}

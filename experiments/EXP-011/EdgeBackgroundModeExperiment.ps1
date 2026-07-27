[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Check','DryRun','Apply','Verify','Rollback','VerifyRollback')]
    [string]$Mode = 'Check',
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-011\state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-011\events.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RecommendedPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$MandatoryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$ValueName = 'BackgroundModeEnabled'

function Write-EventLogJson {
    param([string]$Action,[string]$Result,[hashtable]$Data=@{})
    $dir = Split-Path -Parent $LogPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-011'; action=$Action; result=$Result; data=$Data } |
        ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $edge = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' -ErrorAction SilentlyContinue
    $mandatory = $null
    if (Test-Path $MandatoryPath) { $mandatory = (Get-ItemProperty $MandatoryPath -Name $ValueName -ErrorAction SilentlyContinue).$ValueName }
    [pscustomobject]@{
        IsWindows11 = [version]$os.Version -ge [version]'10.0.22000'
        EdgeInstalled = [bool]$edge
        MandatoryPolicyPresent = $null -ne $mandatory
        MandatoryPolicyValue = $mandatory
        Supported = ([version]$os.Version -ge [version]'10.0.22000') -and [bool]$edge -and ($null -eq $mandatory)
    }
}

function Get-CurrentState {
    $exists = Test-Path $RecommendedPath
    $value = $null
    $valueExists = $false
    if ($exists) {
        $p = Get-ItemProperty $RecommendedPath -Name $ValueName -ErrorAction SilentlyContinue
        if ($null -ne $p) { $value = $p.$ValueName; $valueExists = $null -ne $value }
    }
    [ordered]@{ pathExists=$exists; valueExists=$valueExists; value=$value }
}

function Save-OriginalState {
    if (Test-Path $StatePath) { return Get-Content $StatePath -Raw | ConvertFrom-Json }
    $support = Get-SupportState
    if (-not $support.Supported) { throw "Unsupported or mandatory policy present." }
    $state = [ordered]@{ schemaVersion=1; capturedUtc=(Get-Date).ToUniversalTime().ToString('o'); registry=Get-CurrentState }
    $dir = Split-Path -Parent $StatePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $state | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    return $state
}

function Apply-Experiment {
    $support = Get-SupportState
    if (-not $support.Supported) { throw "Unsupported or mandatory BackgroundModeEnabled policy present." }
    Save-OriginalState | Out-Null
    if (-not (Test-Path $RecommendedPath)) { New-Item -Path $RecommendedPath -Force | Out-Null }
    $current = Get-CurrentState
    if ($current.valueExists -and [int]$current.value -eq 0) { Write-EventLogJson 'Apply' 'AlreadyCompliant'; return }
    if ($PSCmdlet.ShouldProcess("$RecommendedPath\$ValueName",'Set DWORD 0')) {
        New-ItemProperty -Path $RecommendedPath -Name $ValueName -PropertyType DWord -Value 0 -Force | Out-Null
    }
    $verify = Get-CurrentState
    if (-not ($verify.valueExists -and [int]$verify.value -eq 0)) { throw 'Application verification failed.' }
    Write-EventLogJson 'Apply' 'Success' @{ value=0 }
}

function Restore-OriginalState {
    if (-not (Test-Path $StatePath)) { throw 'Original-state file missing.' }
    $state = Get-Content $StatePath -Raw | ConvertFrom-Json
    if ($state.schemaVersion -ne 1) { throw 'Unsupported state schema.' }
    if ($PSCmdlet.ShouldProcess("$RecommendedPath\$ValueName",'Restore captured state')) {
        if ($state.registry.valueExists) {
            if (-not (Test-Path $RecommendedPath)) { New-Item -Path $RecommendedPath -Force | Out-Null }
            New-ItemProperty -Path $RecommendedPath -Name $ValueName -PropertyType DWord -Value ([int]$state.registry.value) -Force | Out-Null
        } else {
            Remove-ItemProperty -Path $RecommendedPath -Name $ValueName -ErrorAction SilentlyContinue
            if (-not $state.registry.pathExists -and (Test-Path $RecommendedPath)) {
                $remaining = Get-ItemProperty $RecommendedPath | Get-Member -MemberType NoteProperty | Where-Object Name -notmatch '^PS'
                if (-not $remaining) { Remove-Item $RecommendedPath -Force }
            }
        }
    }
    Write-EventLogJson 'Rollback' 'Success'
}

switch ($Mode) {
    'Check' { Get-SupportState; Get-CurrentState }
    'DryRun' { Get-SupportState; Get-CurrentState; Write-EventLogJson 'DryRun' 'Success' @{ proposedValue=0 } }
    'Apply' { Apply-Experiment }
    'Verify' { $s=Get-CurrentState; if (-not ($s.valueExists -and [int]$s.value -eq 0)) { throw 'Experiment state verification failed.' }; Write-EventLogJson 'Verify' 'Success' }
    'Rollback' { Restore-OriginalState }
    'VerifyRollback' {
        if (-not (Test-Path $StatePath)) { throw 'Original-state file missing.' }
        $expected=(Get-Content $StatePath -Raw | ConvertFrom-Json).registry
        $actual=Get-CurrentState
        if (($expected.valueExists -ne $actual.valueExists) -or ($expected.valueExists -and [int]$expected.value -ne [int]$actual.value)) { throw 'Rollback verification failed.' }
        Write-EventLogJson 'VerifyRollback' 'Success'
    }
}

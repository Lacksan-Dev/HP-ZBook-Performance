[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Capture','Apply','Verify','Rollback','VerifyReboot')]
    [string]$Action = 'Capture',
    [ValidateSet(0,1)]
    [int]$DesiredValue = 1,
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-022\state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-022\events.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$recommendedPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$mandatoryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$valueName = 'HardwareAccelerationModeEnabled'

function Write-ExperimentLog {
    param([string]$Event,[hashtable]$Data)
    $dir = Split-Path -Parent $LogPath
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-022'; event=$Event; data=$Data } |
        ConvertTo-Json -Compress -Depth 8 | Add-Content -LiteralPath $LogPath -Encoding utf8
}

function Test-Support {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    if ($os.Caption -notmatch 'Windows 11') { throw 'EXP-022 supports Windows 11 only.' }
    if ($computer.Manufacturer -notmatch 'HP|Hewlett') { throw 'EXP-022 supports HP systems only.' }
    $edge = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe' -ErrorAction SilentlyContinue
    if (-not $edge.'(default)' -or -not (Test-Path -LiteralPath $edge.'(default)')) { throw 'Microsoft Edge installation was not detected.' }
    [ordered]@{ os=$os.Caption; build=$os.BuildNumber; manufacturer=$computer.Manufacturer; model=$computer.Model; edgePath=$edge.'(default)' }
}

function Get-PolicyValue {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return [ordered]@{ pathExists=$false; valueExists=$false; value=$null; kind=$null } }
    $key = Get-Item -LiteralPath $Path
    try {
        $value = $key.GetValue($valueName,$null,'DoNotExpandEnvironmentNames')
        $kind = $key.GetValueKind($valueName).ToString()
        [ordered]@{ pathExists=$true; valueExists=$true; value=[int]$value; kind=$kind }
    } catch {
        [ordered]@{ pathExists=$true; valueExists=$false; value=$null; kind=$null }
    }
}

function Assert-MandatoryPolicyAbsent {
    $mandatory = Get-PolicyValue -Path $mandatoryPath
    if ($mandatory.valueExists) { throw 'Mandatory enterprise policy controls HardwareAccelerationModeEnabled. Recommended policy change refused.' }
}

function Save-State {
    $support = Test-Support
    Assert-MandatoryPolicyAbsent
    $state = [ordered]@{
        schemaVersion=1; experiment='EXP-022'; capturedAtUtc=(Get-Date).ToUniversalTime().ToString('o')
        computerName=$env:COMPUTERNAME; recommended=Get-PolicyValue -Path $recommendedPath; support=$support
    }
    $dir = Split-Path -Parent $StatePath
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding utf8
    Write-ExperimentLog 'capture' @{ statePath=$StatePath; original=$state.recommended }
    $state
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.schemaVersion -ne 1 -or $state.experiment -ne 'EXP-022') { throw 'State identity validation failed.' }
    if ($state.computerName -ne $env:COMPUTERNAME) { throw 'State belongs to a different computer.' }
    $state
}

function Set-RecommendedValue {
    param([int]$Value)
    Assert-MandatoryPolicyAbsent
    if (-not (Test-Path $recommendedPath)) { New-Item -Path $recommendedPath -Force | Out-Null }
    New-ItemProperty -Path $recommendedPath -Name $valueName -PropertyType DWord -Value $Value -Force | Out-Null
}

function Verify-Desired {
    param([int]$Value)
    Assert-MandatoryPolicyAbsent
    $current = Get-PolicyValue -Path $recommendedPath
    if (-not $current.valueExists -or $current.value -ne $Value -or $current.kind -ne 'DWord') { throw 'Recommended policy verification failed.' }
    Write-ExperimentLog 'verify' @{ expected=$Value; current=$current }
    $current
}

Test-Support | Out-Null
switch ($Action) {
    'Capture' { Save-State }
    'Apply' {
        if (-not (Test-Path -LiteralPath $StatePath)) { Save-State | Out-Null }
        Assert-MandatoryPolicyAbsent
        $current = Get-PolicyValue -Path $recommendedPath
        if ($current.valueExists -and $current.value -eq $DesiredValue -and $current.kind -eq 'DWord') {
            Write-ExperimentLog 'apply-idempotent' @{ desired=$DesiredValue }
            return $current
        }
        if ($PSCmdlet.ShouldProcess("$recommendedPath\$valueName","Set recommended Edge hardware acceleration policy to $DesiredValue")) {
            Set-RecommendedValue -Value $DesiredValue
            $verified = Verify-Desired -Value $DesiredValue
            Write-ExperimentLog 'apply' @{ desired=$DesiredValue; verified=$verified }
            $verified
        }
    }
    'Verify' { Verify-Desired -Value $DesiredValue }
    'VerifyReboot' {
        $state = Read-State
        $verified = Verify-Desired -Value $DesiredValue
        Write-ExperimentLog 'verify-reboot' @{ capturedAtUtc=$state.capturedAtUtc; verified=$verified }
        $verified
    }
    'Rollback' {
        $state = Read-State
        Assert-MandatoryPolicyAbsent
        if ($PSCmdlet.ShouldProcess("$recommendedPath\$valueName",'Restore captured recommended policy state')) {
            if ($state.recommended.valueExists) {
                if (-not (Test-Path $recommendedPath)) { New-Item -Path $recommendedPath -Force | Out-Null }
                New-ItemProperty -Path $recommendedPath -Name $valueName -PropertyType $state.recommended.kind -Value ([int]$state.recommended.value) -Force | Out-Null
            } elseif (Test-Path $recommendedPath) {
                Remove-ItemProperty -Path $recommendedPath -Name $valueName -ErrorAction SilentlyContinue
            }
            $current = Get-PolicyValue -Path $recommendedPath
            if ([bool]$current.valueExists -ne [bool]$state.recommended.valueExists) { throw 'Rollback existence verification failed.' }
            if ($state.recommended.valueExists -and ($current.value -ne [int]$state.recommended.value -or $current.kind -ne $state.recommended.kind)) { throw 'Rollback value verification failed.' }
            Write-ExperimentLog 'rollback' @{ restored=$current }
            $current
        }
    }
}

#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Mode = 'Check',
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-020\state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-020\events.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$TaskPath = '\Microsoft\Office\'
$TaskName = 'Office Background Task Handler Registration'

function Write-ExpLog {
    param([string]$Event,[hashtable]$Data)
    $dir = Split-Path -Parent $LogPath
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    ([ordered]@{ timestamp=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-020'; event=$Event; data=$Data } | ConvertTo-Json -Compress -Depth 8) | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett')
        Windows = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
    }
}

function Get-TargetTask {
    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
    if ($task.TaskPath -ne $TaskPath -or $task.TaskName -ne $TaskName) { throw 'Task identity mismatch.' }
    $xml = Export-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
    if ($xml -notmatch 'Office Background Task Handler Registration') { throw 'Task XML identity mismatch.' }
    [pscustomobject]@{ Task=$task; Xml=$xml; Enabled=($task.State -ne 'Disabled'); Hash=(Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($xml))) -Algorithm SHA256).Hash }
}

function Save-State {
    param($Target)
    $dir = Split-Path -Parent $StatePath
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [ordered]@{ schema=1; experiment='EXP-020'; taskPath=$TaskPath; taskName=$TaskName; enabled=$Target.Enabled; xml=$Target.Xml; xmlSha256=$Target.Hash; capturedAt=(Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { throw 'Original-state file is missing.' }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.experiment -ne 'EXP-020' -or $state.taskPath -ne $TaskPath -or $state.taskName -ne $TaskName) { throw 'Rollback state identity mismatch.' }
    $hash = (Get-FileHash -InputStream ([IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes([string]$state.xml))) -Algorithm SHA256).Hash
    if ($hash -ne $state.xmlSha256) { throw 'Rollback state integrity check failed.' }
    $state
}

function Test-ExpectedState {
    param([bool]$Enabled)
    $current = Get-TargetTask
    return ($current.Enabled -eq $Enabled)
}

$support = Get-SupportState
if (-not $support.Supported) { throw "Unsupported system: $($support.Manufacturer) $($support.Model), $($support.Windows)" }

switch ($Mode) {
    'Check' {
        $target = Get-TargetTask
        $result = [ordered]@{ support=$support; taskPath=$TaskPath; taskName=$TaskName; enabled=$target.Enabled; xmlSha256=$target.Hash }
        Write-ExpLog 'check' $result
        $result
    }
    'DryRun' {
        $target = Get-TargetTask
        $result = [ordered]@{ action='DisableScheduledTask'; taskPath=$TaskPath; taskName=$TaskName; currentEnabled=$target.Enabled; changesSystem=$false }
        Write-ExpLog 'dry-run' $result
        $result
    }
    'Apply' {
        $target = Get-TargetTask
        if (-not (Test-Path -LiteralPath $StatePath)) { Save-State $target }
        if ($target.Enabled) {
            if ($PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Disable exact Office scheduled task')) { Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Out-Null }
        }
        if (-not (Test-ExpectedState $false)) { throw 'Application verification failed.' }
        Write-ExpLog 'apply' @{ changed=$target.Enabled; verified=$true }
        [pscustomobject]@{ Changed=$target.Enabled; Verified=$true }
    }
    'Verify' {
        $ok = Test-ExpectedState $false
        Write-ExpLog 'verify' @{ expectedEnabled=$false; verified=$ok }
        if (-not $ok) { throw 'Verification failed.' }
        $true
    }
    'VerifyReboot' {
        $ok = Test-ExpectedState $false
        Write-ExpLog 'verify-reboot' @{ expectedEnabled=$false; verified=$ok; bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
        if (-not $ok) { throw 'Reboot-persistence verification failed.' }
        $true
    }
    'Rollback' {
        $state = Read-State
        $current = Get-TargetTask
        if ($state.enabled) {
            if (-not $current.Enabled -and $PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Restore enabled state')) { Enable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Out-Null }
        } else {
            if ($current.Enabled -and $PSCmdlet.ShouldProcess("$TaskPath$TaskName", 'Restore disabled state')) { Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Out-Null }
        }
        $ok = Test-ExpectedState ([bool]$state.enabled)
        Write-ExpLog 'rollback' @{ restoredEnabled=[bool]$state.enabled; verified=$ok }
        if (-not $ok) { throw 'Rollback verification failed.' }
        $true
    }
}

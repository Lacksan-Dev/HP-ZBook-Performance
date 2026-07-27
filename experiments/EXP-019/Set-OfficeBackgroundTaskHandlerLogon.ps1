[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [ValidateSet('Detect','Capture','Apply','Verify','VerifyReboot','Rollback','VerifyRollback')]
    [string]$Action = 'Detect',
    [string]$EvidenceRoot = (Join-Path $PSScriptRoot 'evidence')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExperimentId = 'EXP-019'
$script:TaskPath = '\Microsoft\Office\'
$script:TaskName = 'Office Background Task Handler Logon'
$script:StatePath = Join-Path $EvidenceRoot 'original-state.json'
$script:EventPath = Join-Path $EvidenceRoot 'events.jsonl'

function Write-ExperimentEvent {
    param([string]$Event,[hashtable]$Data=@{})
    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
    $record = [ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        experiment = $script:ExperimentId
        action = $Action
        event = $Event
        data = $Data
    }
    ($record | ConvertTo-Json -Depth 8 -Compress) | Add-Content -LiteralPath $script:EventPath -Encoding utf8
}

function Get-Sha256Text {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}

function Get-PlatformSupport {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $isWindows11 = ([version]$os.Version).Build -ge 22000
    $isHp = $computer.Manufacturer -match '(^|\s)(HP|Hewlett-Packard)(\s|$)'
    [pscustomobject]@{
        Supported = ($isWindows11 -and $isHp)
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        WindowsVersion = $os.Version
        WindowsBuild = $os.BuildNumber
        Reason = if (-not $isWindows11) { 'Windows 11 build required' } elseif (-not $isHp) { 'HP hardware required' } else { 'Supported' }
    }
}

function Get-CandidateTask {
    $task = Get-ScheduledTask -TaskPath $script:TaskPath -TaskName $script:TaskName -ErrorAction Stop
    if ($task.TaskPath -cne $script:TaskPath -or $task.TaskName -cne $script:TaskName) {
        throw 'Scheduled task identity rejected'
    }
    $actionText = (($task.Actions | ForEach-Object { "$( $_.Execute ) $( $_.Arguments )" }) -join ' ').Trim()
    if ($actionText -notmatch '(?i)OfficeBackgroundTaskHandler(?:\.exe)?') {
        throw 'Scheduled task action identity rejected'
    }
    $xml = Export-ScheduledTask -TaskPath $script:TaskPath -TaskName $script:TaskName
    [pscustomobject]@{
        Task = $task
        ActionText = $actionText
        Xml = $xml
        XmlSha256 = Get-Sha256Text -Text $xml
        Enabled = ($task.State -ne 'Disabled')
    }
}

function Assert-Supported {
    $support = Get-PlatformSupport
    if (-not $support.Supported) { throw $support.Reason }
    $support
}

function Read-State {
    if (-not (Test-Path -LiteralPath $script:StatePath)) { throw 'Original state file missing' }
    $state = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json
    if ($state.experiment -ne $script:ExperimentId -or $state.taskPath -cne $script:TaskPath -or $state.taskName -cne $script:TaskName) {
        throw 'State file identity rejected'
    }
    $state
}

function Capture-State {
    $support = Assert-Supported
    $candidate = Get-CandidateTask
    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
    $state = [ordered]@{
        schemaVersion = 1
        experiment = $script:ExperimentId
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        manufacturer = $support.Manufacturer
        model = $support.Model
        windowsVersion = $support.WindowsVersion
        windowsBuild = $support.WindowsBuild
        taskPath = $script:TaskPath
        taskName = $script:TaskName
        enabled = $candidate.Enabled
        actionText = $candidate.ActionText
        xmlSha256 = $candidate.XmlSha256
        xml = $candidate.Xml
    }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:StatePath -Encoding utf8
    Write-ExperimentEvent -Event 'StateCaptured' -Data @{ enabled=$candidate.Enabled; xmlSha256=$candidate.XmlSha256 }
    $state
}

function Assert-CurrentMatchesCapturedIdentity {
    param($State)
    $candidate = Get-CandidateTask
    if ($candidate.XmlSha256 -ne $State.xmlSha256) { throw 'Current task definition diverged from captured state' }
    if ($candidate.ActionText -cne $State.actionText) { throw 'Current task action diverged from captured state' }
    $candidate
}

function Apply-Calibration {
    Assert-Supported | Out-Null
    $state = Read-State
    $candidate = Assert-CurrentMatchesCapturedIdentity -State $state
    if (-not $candidate.Enabled) {
        Write-ExperimentEvent -Event 'AlreadyApplied'
        return $true
    }
    if ($PSCmdlet.ShouldProcess("$($script:TaskPath)$($script:TaskName)", 'Disable scheduled task')) {
        Disable-ScheduledTask -TaskPath $script:TaskPath -TaskName $script:TaskName | Out-Null
        $verified = -not (Get-CandidateTask).Enabled
        if (-not $verified) { throw 'Application verification failed' }
        Write-ExperimentEvent -Event 'Applied' -Data @{ enabled=$false }
        return $true
    }
    Write-ExperimentEvent -Event 'DryRun' -Data @{ proposedEnabled=$false }
    return $false
}

function Verify-Calibration {
    Assert-Supported | Out-Null
    $state = Read-State
    Assert-CurrentMatchesCapturedIdentity -State $state | Out-Null
    $enabled = (Get-CandidateTask).Enabled
    $result = -not $enabled
    Write-ExperimentEvent -Event 'Verified' -Data @{ passed=$result; enabled=$enabled }
    $result
}

function Restore-State {
    Assert-Supported | Out-Null
    $state = Read-State
    $candidate = Assert-CurrentMatchesCapturedIdentity -State $state
    if ($candidate.Enabled -eq [bool]$state.enabled) {
        Write-ExperimentEvent -Event 'AlreadyRolledBack' -Data @{ enabled=$candidate.Enabled }
        return $true
    }
    $verb = if ([bool]$state.enabled) { 'Enable scheduled task' } else { 'Disable scheduled task' }
    if ($PSCmdlet.ShouldProcess("$($script:TaskPath)$($script:TaskName)", $verb)) {
        if ([bool]$state.enabled) { Enable-ScheduledTask -TaskPath $script:TaskPath -TaskName $script:TaskName | Out-Null }
        else { Disable-ScheduledTask -TaskPath $script:TaskPath -TaskName $script:TaskName | Out-Null }
        $restored = ((Get-CandidateTask).Enabled -eq [bool]$state.enabled)
        if (-not $restored) { throw 'Rollback verification failed' }
        Write-ExperimentEvent -Event 'RolledBack' -Data @{ enabled=[bool]$state.enabled }
        return $true
    }
    Write-ExperimentEvent -Event 'RollbackDryRun' -Data @{ proposedEnabled=[bool]$state.enabled }
    return $false
}

switch ($Action) {
    'Detect' { $support = Get-PlatformSupport; $candidate = if ($support.Supported) { Get-CandidateTask } else { $null }; [pscustomobject]@{ Support=$support; Candidate=$candidate } }
    'Capture' { Capture-State }
    'Apply' { Apply-Calibration }
    'Verify' { Verify-Calibration }
    'VerifyReboot' { Verify-Calibration }
    'Rollback' { Restore-State }
    'VerifyRollback' {
        $state = Read-State
        $candidate = Assert-CurrentMatchesCapturedIdentity -State $state
        $result = ($candidate.Enabled -eq [bool]$state.enabled)
        Write-ExperimentEvent -Event 'RollbackVerified' -Data @{ passed=$result; enabled=$candidate.Enabled }
        $result
    }
}
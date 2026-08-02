[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Check','Capture','DryRun','Select')]
    [string]$Action = 'Check',
    [string]$OutputPath,
    [string]$AttributionPath,
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Experiment = 'EXP-136'
$Issue = 309
$SchemaVersion = 1
$ProtectedPattern = '(?i)omnissa|horizon|vmware|windows app|msrdc|remote desktop|mstsc|tailscale|defender|securityhealth|firewall|bitlocker|credential|windows update|wuauserv|usosvc|bits|recovery|intune|sccm|configmgr|mdm|accessibility|driver|firmware|bios|dell|lenovo|hp support|hp insights|workforce|office|microsoft 365|outlook|teams|logi|logitech'
$ServicingPattern = '(?i)update|updater|upgrade|install|installer|setup|repair|servic|maintenance|patch|telemetry|diagnostic|recovery'

function Write-EvidenceLog {
    param([string]$Stage,[string]$Result,[hashtable]$Data)
    if (-not $LogPath) { return }
    $parent = Split-Path -Parent $LogPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $entry = [ordered]@{
        schemaVersion = $SchemaVersion
        experiment = $Experiment
        issue = $Issue
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        stage = $Stage
        result = $Result
        machine = $env:COMPUTERNAME
        userSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    }
    foreach ($key in $Data.Keys) { $entry[$key] = $Data[$key] }
    ($entry | ConvertTo-Json -Depth 12 -Compress) | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-StringSha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $isWindows11 = ($os.Caption -match 'Windows 11')
    [pscustomobject]@{
        supported = $isWindows11
        windowsCaption = $os.Caption
        windowsBuild = $os.BuildNumber
        manufacturer = $cs.Manufacturer
        model = $cs.Model
        reason = if ($isWindows11) { 'Windows 11 detected' } else { 'Windows 11 required' }
    }
}

function Resolve-ExecutablePath {
    param([string]$Execute)
    if ([string]::IsNullOrWhiteSpace($Execute)) { return $null }
    $candidate = [Environment]::ExpandEnvironmentVariables($Execute.Trim('"'))
    if ([IO.Path]::IsPathRooted($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        return (Get-Item -LiteralPath $candidate).FullName
    }
    $cmd = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-ActionIdentity {
    param($ActionObject)
    $execute = [string]$ActionObject.Execute
    $arguments = [string]$ActionObject.Arguments
    $resolved = Resolve-ExecutablePath $execute
    $identity = [ordered]@{
        execute = $execute
        arguments = $arguments
        resolvedPath = $resolved
        fileVersion = $null
        productName = $null
        sha256 = $null
        signatureStatus = $null
        publisher = $null
    }
    if ($resolved) {
        $file = Get-Item -LiteralPath $resolved
        $sig = Get-AuthenticodeSignature -LiteralPath $resolved
        $identity.fileVersion = $file.VersionInfo.FileVersion
        $identity.productName = $file.VersionInfo.ProductName
        $identity.sha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash.ToLowerInvariant()
        $identity.signatureStatus = [string]$sig.Status
        if ($sig.SignerCertificate) { $identity.publisher = $sig.SignerCertificate.Subject }
    }
    [pscustomobject]$identity
}

function Test-ManagementOwnership {
    param([string]$TaskPath,[string]$TaskName,[string]$Author)
    $joined = (Get-CimInstance Win32_ComputerSystem).PartOfDomain
    $policySignal = Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current'
    $mdmSignal = Test-Path 'HKLM:\SOFTWARE\Microsoft\Enrollments'
    $configMgr = [bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
    $identity = "$TaskPath$TaskName $Author"
    [pscustomobject]@{
        domainJoined = [bool]$joined
        policyManagerPresent = [bool]$policySignal
        mdmEnrollmentPresent = [bool]$mdmSignal
        configMgrPresent = $configMgr
        taskLooksManaged = ($identity -match '(?i)policy|mdm|intune|configmgr|sccm|enterprise')
        managed = ([bool]$joined -or $policySignal -or $mdmSignal -or $configMgr -or ($identity -match '(?i)policy|mdm|intune|configmgr|sccm|enterprise'))
    }
}

function Get-Inventory {
    $support = Get-SupportState
    if (-not $support.supported) { throw $support.reason }

    $items = @()
    foreach ($task in Get-ScheduledTask -ErrorAction Stop) {
        $logonTriggers = @($task.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskLogonTrigger' })
        if ($logonTriggers.Count -eq 0) { continue }

        $xml = Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath
        $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
        $actions = @($task.Actions | ForEach-Object { Get-ActionIdentity $_ })
        $resolvedCount = @($actions | Where-Object { $_.resolvedPath }).Count
        $signedCount = @($actions | Where-Object { $_.signatureStatus -eq 'Valid' }).Count
        $combined = "$($task.TaskPath)$($task.TaskName) $($task.Author) " + (($actions | ForEach-Object { "$($_.resolvedPath) $($_.productName) $($_.publisher) $($_.arguments)" }) -join ' ')
        $management = Test-ManagementOwnership -TaskPath $task.TaskPath -TaskName $task.TaskName -Author $task.Author
        $protected = ($combined -match $ProtectedPattern)
        $servicing = ($combined -match $ServicingPattern)
        $singleAction = ($actions.Count -eq 1)
        $signedUserApp = ($singleAction -and $resolvedCount -eq 1 -and $signedCount -eq 1)
        $eligibleForAttribution = ($signedUserApp -and -not $protected -and -not $servicing -and -not $management.managed)

        $items += [pscustomobject]@{
            taskPath = $task.TaskPath
            taskName = $task.TaskName
            taskIdHash = Get-StringSha256 "$($task.TaskPath)$($task.TaskName)"
            enabled = ($task.State -ne 'Disabled')
            state = [string]$task.State
            author = $task.Author
            description = $task.Description
            xml = $xml
            xmlSha256 = Get-StringSha256 $xml
            triggers = @($logonTriggers | ForEach-Object { [pscustomobject]@{ userId=$_.UserId; delay=[string]$_.Delay; enabled=$_.Enabled } })
            actions = $actions
            principal = $task.Principal
            settings = $task.Settings
            lastRunTime = if ($taskInfo) { $taskInfo.LastRunTime } else { $null }
            lastTaskResult = if ($taskInfo) { $taskInfo.LastTaskResult } else { $null }
            nextRunTime = if ($taskInfo) { $taskInfo.NextRunTime } else { $null }
            management = $management
            protected = $protected
            servicing = $servicing
            eligibleForAttribution = $eligibleForAttribution
            selectionState = if ($eligibleForAttribution) { 'needs-physical-attribution' } else { 'excluded' }
            attribution = [pscustomobject]@{ trials=0; cpuMs=$null; readBytes=$null; writeBytes=$null; peakWorkingSetBytes=$null; processStarts=$null; networkBytes=$null }
        }
    }

    [pscustomobject]@{
        schemaVersion = $SchemaVersion
        experiment = $Experiment
        issue = $Issue
        capturedUtc = [DateTime]::UtcNow.ToString('o')
        machine = $env:COMPUTERNAME
        userSid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
        support = $support
        mutationAllowed = $false
        needsEvidence = $true
        selectionRule = 'Select exactly one eligible task only after at least five physical attribution trials establish the highest reproducible first-120-second startup cost.'
        tasks = $items
    }
}

function Select-PhysicalCandidate {
    param($Inventory,[string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { throw 'Physical attribution JSON is required for Select.' }
    $attribution = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $eligible = @($Inventory.tasks | Where-Object { $_.eligibleForAttribution })
    $ranked = @()
    foreach ($item in $eligible) {
        $evidence = @($attribution | Where-Object { $_.taskIdHash -eq $item.taskIdHash })
        if ($evidence.Count -ne 1) { continue }
        if ([int]$evidence[0].trials -lt 5) { continue }
        if ($null -eq $evidence[0].startupCostScore) { continue }
        $ranked += [pscustomobject]@{ task=$item; evidence=$evidence[0] }
    }
    if ($ranked.Count -eq 0) { throw 'No eligible task has at least five qualifying physical attribution trials.' }
    $ordered = @($ranked | Sort-Object { [double]$_.evidence.startupCostScore } -Descending)
    if ($ordered.Count -gt 1 -and [double]$ordered[0].evidence.startupCostScore -eq [double]$ordered[1].evidence.startupCostScore) { throw 'Highest-cost attribution is ambiguous.' }
    [pscustomobject]@{
        selected = $ordered[0].task
        evidence = $ordered[0].evidence
        mutationAllowed = $false
        nextGate = 'Implement a dedicated reversible provider after human review of physical attribution and exact rollback feasibility.'
    }
}

try {
    $inventory = Get-Inventory
    switch ($Action) {
        'Check' {
            Write-EvidenceLog 'Check' 'pass' @{eligibleCount=@($inventory.tasks | Where-Object {$_.eligibleForAttribution}).Count;needsEvidence=$true}
            $inventory | Select-Object schemaVersion,experiment,issue,capturedUtc,support,mutationAllowed,needsEvidence,selectionRule,@{n='taskCount';e={@($_.tasks).Count}},@{n='eligibleCount';e={@($_.tasks | Where-Object {$_.eligibleForAttribution}).Count}}
        }
        'Capture' {
            if (-not $OutputPath) { throw 'OutputPath is required for Capture.' }
            if ($PSCmdlet.ShouldProcess($OutputPath,'Write zero-mutation EXP-136 inventory evidence')) {
                $parent = Split-Path -Parent $OutputPath
                if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                $inventory | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
            }
            Write-EvidenceLog 'Capture' 'pass' @{outputPathHash=Get-StringSha256 $OutputPath;taskCount=@($inventory.tasks).Count;needsEvidence=$true}
            $inventory
        }
        'DryRun' {
            Write-EvidenceLog 'DryRun' 'pass' @{candidateCount=@($inventory.tasks | Where-Object {$_.eligibleForAttribution}).Count;mutationAllowed=$false;needsEvidence=$true}
            [pscustomobject]@{experiment=$Experiment;action='DryRun';wouldMutate=$false;candidateCount=@($inventory.tasks | Where-Object {$_.eligibleForAttribution}).Count;needsEvidence=$true}
        }
        'Select' {
            $selected = Select-PhysicalCandidate -Inventory $inventory -Path $AttributionPath
            Write-EvidenceLog 'Select' 'pass' @{taskIdHash=$selected.selected.taskIdHash;trials=$selected.evidence.trials;mutationAllowed=$false;needsEvidence=$true}
            $selected
        }
    }
}
catch {
    Write-EvidenceLog $Action 'fail' @{refusalReason=$_.Exception.Message;failureDetail=$_.ScriptStackTrace;needsEvidence=$true}
    throw
}

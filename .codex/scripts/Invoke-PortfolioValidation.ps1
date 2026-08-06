#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('Inspect','Auto','Export','Recover')]
    [string]$Action = 'Inspect',

    [string]$QueuePath,

    [string]$DataRoot,

    [string]$EvidenceOutputRoot,

    [string]$RecoveryRequestPath,

    [switch]$AllowAutomaticReboot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
if ([string]::IsNullOrWhiteSpace($QueuePath)) {
    $QueuePath = Join-Path $RepoRoot 'portfolio\validation-queue.json'
}
if ([string]::IsNullOrWhiteSpace($DataRoot)) {
    $programData = [Environment]::GetFolderPath('CommonApplicationData')
    $DataRoot = Join-Path $programData 'Lacksan\PortfolioValidation'
}
if ([string]::IsNullOrWhiteSpace($EvidenceOutputRoot)) {
    # Stage the sanitized publication package outside the Git checkout. The
    # executor requires a clean main branch before it can fast-forward and
    # select the next candidate, so writing completed evidence into that same
    # checkout would deadlock every later scheduled run.
    $EvidenceOutputRoot = Join-Path $DataRoot 'sanitized-evidence'
}
if ([string]::IsNullOrWhiteSpace($RecoveryRequestPath)) {
    $RecoveryRequestPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Lacksan\PortfolioValidation\recovery-request.json'
}

$ActiveCyclePath = Join-Path $DataRoot 'active-cycle.json'
$RequiredProtectedScopes = @(
    'WindowsSecurity','WindowsUpdate','EdgeUpdate','Credentials','Recovery',
    'EnterpriseManagement','DeviceCriticalDrivers','Networking','Omnissa',
    'WindowsApp','RemoteDesktop','Tailscale'
)

function Write-JsonFile {
    param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)]$Value)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporary = "$Path.tmp"
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Read-JsonFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Required JSON file is missing: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-OptionalProperty {
    param($Object,[Parameter(Mandatory=$true)][string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Resolve-RepositoryPath {
    param([Parameter(Mandatory=$true)][string]$RelativePath)
    if ([IO.Path]::IsPathRooted($RelativePath)) { throw 'Validation queue paths must be repository-relative.' }
    $full = [IO.Path]::GetFullPath((Join-Path $RepoRoot ($RelativePath.Replace('/','\'))))
    $prefix = $RepoRoot.TrimEnd('\') + '\'
    if (-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {
        throw "Validation queue path escapes the repository: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Queued harness is missing: $RelativePath" }
    return $full
}

function Get-Queue {
    $queue = Read-JsonFile -Path $QueuePath
    if ([int]$queue.schemaVersion -ne 1) { throw 'Unsupported validation queue schema.' }
    $items = @($queue.items)
    $duplicates = @($items | Group-Object experiment | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) { throw 'The validation queue contains duplicate experiment entries.' }
    foreach ($item in $items) {
        if ([string]$item.experiment -notmatch '^EXP-\d{3}$') { throw 'Every queue item requires an EXP-### identifier.' }
        if ([string]$item.state -notin @('ready','completed')) { throw "$($item.experiment) has an unsupported queue state." }
        if ([string]$item.releaseState -ne 'Experimental') { throw "$($item.experiment) must remain Experimental." }
        if ([string]::IsNullOrWhiteSpace([string]$item.candidate)) { throw "$($item.experiment) has no single candidate." }
        if ([string]::IsNullOrWhiteSpace([string]$item.benchmark)) { throw "$($item.experiment) has no benchmark." }
        if (@($item.verification).Count -eq 0) { throw "$($item.experiment) has no verification contract." }
        if ([string]::IsNullOrWhiteSpace([string]$item.rollback)) { throw "$($item.experiment) has no exact rollback contract." }
        $declared = @($item.protectedScopes | ForEach-Object { [string]$_ })
        $missing = @($RequiredProtectedScopes | Where-Object { $_ -notin $declared })
        if ($missing.Count -gt 0) { throw "$($item.experiment) omits protected scopes: $($missing -join ', ')." }
    }
    return $queue
}

function Get-HarnessContract {
    param([Parameter(Mandatory=$true)][string]$Path)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if (@($errors).Count -gt 0) { throw "PowerShell parser rejected the harness: $($errors[0].Message)" }
    $parameters = @()
    if ($ast.ParamBlock) {
        $parameters = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
    }
    $source = Get-Content -LiteralPath $Path -Raw
    $requiredParameters = @('Action','RunsPerArm','EvidenceRoot','AllowAutomaticReboot')
    $missingParameters = @($requiredParameters | Where-Object { $_ -notin $parameters })
    $requiredTokens = @('Start','Continue','Status','Stop','Capture','DryRun','VerifyReboot','Rollback','Register-ScheduledTask')
    $missingTokens = @($requiredTokens | Where-Object { $source -notmatch [regex]::Escape($_) })
    [pscustomobject][ordered]@{
        valid = ($missingParameters.Count -eq 0 -and $missingTokens.Count -eq 0 -and $source -match 'SupportsShouldProcess')
        parameters = $parameters
        missingParameters = $missingParameters
        missingTokens = $missingTokens
        supportsShouldProcess = ($source -match 'SupportsShouldProcess')
    }
}

function Test-IsElevated {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-NativePowerAndIdleApi {
    if ('Lacksan.PortfolioNative' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Lacksan {
    public static class PortfolioNative {
        [StructLayout(LayoutKind.Sequential)]
        public struct SYSTEM_POWER_STATUS {
            public byte ACLineStatus;
            public byte BatteryFlag;
            public byte BatteryLifePercent;
            public byte Reserved1;
            public uint BatteryLifeTime;
            public uint BatteryFullLifeTime;
        }
        [StructLayout(LayoutKind.Sequential)]
        public struct LASTINPUTINFO {
            public uint cbSize;
            public uint dwTime;
        }
        [DllImport("kernel32.dll")]
        public static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS status);
        [DllImport("user32.dll")]
        public static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
        [DllImport("kernel32.dll")]
        public static extern ulong GetTickCount64();
    }
}
'@
}

function Get-PowerAndIdleState {
    Initialize-NativePowerAndIdleApi
    $power = New-Object Lacksan.PortfolioNative+SYSTEM_POWER_STATUS
    if (-not [Lacksan.PortfolioNative]::GetSystemPowerStatus([ref]$power)) {
        throw 'Windows power status could not be read.'
    }
    $lastInput = New-Object Lacksan.PortfolioNative+LASTINPUTINFO
    $lastInput.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($lastInput)
    if (-not [Lacksan.PortfolioNative]::GetLastInputInfo([ref]$lastInput)) {
        throw 'Windows idle time could not be read.'
    }
    $elapsedMs = [Lacksan.PortfolioNative]::GetTickCount64() - [uint64]$lastInput.dwTime
    [pscustomobject][ordered]@{
        acConnected = ([int]$power.ACLineStatus -eq 1)
        batteryPercent = if ([int]$power.BatteryLifePercent -le 100) { [int]$power.BatteryLifePercent } else { $null }
        idleMinutes = [Math]::Round(([double]$elapsedMs / 60000),2)
    }
}

function Test-PendingReboot {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    if (@($paths | Where-Object { Test-Path -LiteralPath $_ }).Count -gt 0) { return $true }
    $sessionManager = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    return ($null -ne $sessionManager)
}

function Get-MachineGate {
    param([Parameter(Mandatory=$true)]$Item)
    $reasons = @()
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $power = Get-PowerAndIdleState
    if ([string]$os.Caption -notmatch 'Windows 11') { $reasons += 'Windows 11 on the connected lab machine is required.' }
    if ([string]$computer.Manufacturer -notmatch '(?i)^HP$|Hewlett-Packard') { $reasons += 'An HP or Hewlett-Packard system is required.' }
    if (-not (Test-IsElevated)) { $reasons += 'Start the Codex scheduled cycle from an elevated local session.' }
    if (-not $power.acConnected) { $reasons += 'Connect the HP laptop to AC power.' }
    if ([double]$power.idleMinutes -lt [double]$Item.minimumIdleMinutes) {
        $reasons += "Leave the local session idle for at least $($Item.minimumIdleMinutes) minutes."
    }
    if ([string]$env:SESSIONNAME -match '(?i)RDP|ICA') { $reasons += 'End the active remote desktop session before an automatic reboot experiment.' }
    if (Test-PendingReboot) { $reasons += 'Complete the pre-existing Windows reboot before starting an experiment.' }
    $installerProcesses = @(Get-Process -Name msiexec,TiWorker,TrustedInstaller,MoUsoCoreWorker -ErrorAction SilentlyContinue)
    if ($installerProcesses.Count -gt 0) { $reasons += 'Wait for active servicing or installer processes to finish.' }
    [pscustomobject][ordered]@{
        safe = ($reasons.Count -eq 0)
        evidenceStatus = if ($reasons.Count -eq 0) { 'ready' } else { 'needs-evidence' }
        exactEvidenceRequest = $reasons
        environment = [pscustomobject][ordered]@{
            windows = [string]$os.Caption
            build = [string]$os.BuildNumber
            manufacturer = [string]$computer.Manufacturer
            model = [string]$computer.Model
            elevated = [bool](Test-IsElevated)
            acConnected = [bool]$power.acConnected
            batteryPercent = $power.batteryPercent
            idleMinutes = $power.idleMinutes
            pendingReboot = [bool](Test-PendingReboot)
        }
    }
}

function Get-SourceCommit {
    try { (& git -C $RepoRoot rev-parse HEAD 2>$null).Trim() } catch { $null }
}

function Get-ActiveHarnessStatus {
    param([Parameter(Mandatory=$true)]$Active)
    $harness = Resolve-RepositoryPath -RelativePath ([string]$Active.harnessPath)
    $arguments = @{ Action='Status'; EvidenceRoot=[string]$Active.evidenceRoot }
    & $harness @arguments
}

function Convert-ToMetricNode {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [bool] -or $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value
    }
    if ($Value -is [string] -or $Value -is [char] -or $Value -is [datetime] -or $Value -is [guid]) {
        return $null
    }
    if ($Value -is [Array]) {
        $items = @()
        foreach ($entry in $Value) {
            $converted = Convert-ToMetricNode -Value $entry
            if ($null -ne $converted) { $items += $converted }
        }
        return ,$items
    }
    if ($Value -is [Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $Value.Keys) {
            if ([string]$key -notmatch '^[A-Za-z][A-Za-z0-9_-]{0,63}$') { continue }
            $converted = Convert-ToMetricNode -Value $Value[$key]
            if ($null -ne $converted) { $result[[string]$key] = $converted }
        }
        return $result
    }
    if ($Value.PSObject) {
        $result = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            if ([string]$property.Name -notmatch '^[A-Za-z][A-Za-z0-9_-]{0,63}$') { continue }
            $converted = Convert-ToMetricNode -Value $property.Value
            if ($null -ne $converted) { $result[[string]$property.Name] = $converted }
        }
        return $result
    }
    return $null
}

function Get-LifecycleProof {
    param([Parameter(Mandatory=$true)][string]$RunDirectory)
    $proof = [ordered]@{
        capture = $false
        dryRun = $false
        apply = $false
        verify = $false
        verifyReboot = $false
        rollback = $false
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $RunDirectory -Filter '*events.jsonl' -File -ErrorAction SilentlyContinue)) {
        foreach ($line in @(Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue)) {
            try { $row = $line | ConvertFrom-Json } catch { continue }
            $text = "$(Get-OptionalProperty $row 'action') $(Get-OptionalProperty $row 'phase') $(Get-OptionalProperty $row 'event')"
            $outcome = "$(Get-OptionalProperty $row 'result') $(Get-OptionalProperty $row 'status')"
            if ($outcome -match '(?i)fail|error|refus') { continue }
            if ($text -match '(?i)dry[- ]?run') { $proof.dryRun = $true; continue }
            if ($text -match '(?i)verify[- ]?reboot|reboot[- ]?verified') { $proof.verifyReboot = $true; continue }
            if ($text -match '(?i)rollback|rolled[- ]?back') { $proof.rollback = $true; continue }
            if ($text -match '(?i)capture|state[- ]?captured') { $proof.capture = $true; continue }
            if ($text -match '(?i)verify|verified') { $proof.verify = $true; continue }
            if ($text -match '(?i)apply|applied') { $proof.apply = $true }
        }
    }
    return [pscustomobject]$proof
}

function Get-SafeEnvironmentSummary {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    $power = Get-PowerAndIdleState
    [ordered]@{
        manufacturer = [string]$computer.Manufacturer
        model = [string]$computer.Model
        windowsCaption = [string]$os.Caption
        windowsBuild = [string]$os.BuildNumber
        biosVersion = [string]$bios.SMBIOSBIOSVersion
        powerSource = if ($power.acConnected) { 'AC' } else { 'battery' }
        thermalState = 'needs-evidence'
        identifiersExcluded = $true
    }
}

function Export-CompletedEvidence {
    param([Parameter(Mandatory=$true)]$Active)
    $summaries = @(Get-ChildItem -LiteralPath ([string]$Active.evidenceRoot) -Filter 'summary.json' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending)
    if ($summaries.Count -eq 0) {
        return [pscustomobject][ordered]@{
            experiment = [string]$Active.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @('Complete the queued reboot-aware harness so it emits summary.json after exact rollback.')
        }
    }
    $summaryPath = $summaries[0].FullName
    $summary = Read-JsonFile -Path $summaryPath
    if ([string]$summary.experiment -ne [string]$Active.experiment) { throw 'Harness summary experiment identity mismatch.' }
    $runDirectory = Split-Path -Parent $summaryPath
    $proof = Get-LifecycleProof -RunDirectory $runDirectory
    $classification = [string](Get-OptionalProperty $summary 'classification')
    if ($classification -notmatch '^(?i)beneficial|adverse|inconclusive|neutral|unqualified$') { $classification = 'unqualified' }
    $proofComplete = ($proof.capture -and $proof.dryRun -and $proof.apply -and $proof.verify -and $proof.verifyReboot -and $proof.rollback)
    $exactRequest = @()
    if (-not $proof.capture) { $exactRequest += 'Provide a passing physical original-state capture event.' }
    if (-not $proof.dryRun) { $exactRequest += 'Provide a passing physical dry-run event before application.' }
    if (-not $proof.apply) { $exactRequest += 'Provide a passing focused application event.' }
    if (-not $proof.verify) { $exactRequest += 'Provide a passing immediate verification event after application.' }
    if (-not $proof.verifyReboot) { $exactRequest += 'Provide a passing post-reboot verification event.' }
    if (-not $proof.rollback) { $exactRequest += 'Provide a passing exact rollback event.' }
    $rawHashes = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $runDirectory -File | Where-Object Name -match '\.(json|jsonl)$')) {
        $rawHashes += [ordered]@{ role = if ($file.Name -eq 'summary.json') { 'summary' } elseif ($file.Name -match 'events') { 'structured-log' } else { 'raw-run-or-state' }; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $generated = if ($summary.generatedUtc) { [datetime]$summary.generatedUtc } else { $summaries[0].LastWriteTimeUtc }
    $stamp = $generated.ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $relative = "evidence\physical\$($Active.experiment)\$stamp"
    $destination = Join-Path (Join-Path $EvidenceOutputRoot ([string]$Active.experiment)) $stamp
    $report = [ordered]@{
        schemaVersion = 1
        experiment = [string]$Active.experiment
        issue = [int]$Active.issue
        releaseState = 'Experimental'
        evidenceStatus = if ($proofComplete) { 'physical-lifecycle-recorded' } else { 'needs-evidence' }
        performanceClaim = $false
        stableAssignment = $false
        generatedUtc = $generated.ToUniversalTime().ToString('o')
        sourceCommit = [string]$Active.sourceCommit
        candidate = [string]$Active.candidate
        benchmark = [string]$Active.benchmark
        environment = Get-SafeEnvironmentSummary
        metrics = Convert-ToMetricNode -Value $summary.groups
        classification = $classification.ToLowerInvariant()
        lifecycle = $proof
        exactEvidenceRequest = $exactRequest
        protectedScopes = @($Active.protectedScopes)
        rawEvidence = [ordered]@{
            retention = 'machine-local-only'
            identifiersCommitted = $false
            fileDigests = $rawHashes
        }
    }
    if ($PSCmdlet.ShouldProcess($relative,'Write sanitized physical evidence package')) {
        Write-JsonFile -Path (Join-Path $destination 'summary.json') -Value $report
        $markdown = @(
            "# $($Active.experiment) physical validation evidence",
            '',
            'Release state: Experimental',
            "Evidence status: $($report.evidenceStatus)",
            'Performance claim: none',
            '',
            'This package is a bounded, sanitized projection of machine-local raw evidence. It excludes machine and user identifiers, serials, paths, process IDs, credentials, browser/profile data, and customer content. Raw runs, exact original state, logs, and rollback artifacts remain on the operator-controlled lab machine.',
            '',
            'The JSON summary records repeated benchmark aggregates, lifecycle gates, protected scope, and SHA-256 digests for local evidence integrity. It does not assign Stable.'
        )
        $markdown | Set-Content -LiteralPath (Join-Path $destination 'README.md') -Encoding UTF8
        if (Test-Path -LiteralPath $ActiveCyclePath) { Remove-Item -LiteralPath $ActiveCyclePath -Force }
    }
    [pscustomobject][ordered]@{
        experiment = [string]$Active.experiment
        evidenceStatus = [string]$report.evidenceStatus
        exportedPath = $relative.Replace('\','/')
        exactEvidenceRequest = $exactRequest
    }
}

function Start-ReadyValidation {
    param([Parameter(Mandatory=$true)]$Item)
    $harness = Resolve-RepositoryPath -RelativePath ([string]$Item.harnessPath)
    $contract = Get-HarnessContract -Path $harness
    if (-not $contract.valid) {
        return [pscustomobject][ordered]@{
            experiment = [string]$Item.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @("Add the missing reboot-harness contract before execution. Parameters: $($contract.missingParameters -join ', '); lifecycle tokens: $($contract.missingTokens -join ', ').")
        }
    }
    try {
        $gate = Get-MachineGate -Item $Item
    } catch {
        return [pscustomobject][ordered]@{
            experiment = [string]$Item.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @("Restore machine-gate instrumentation and rerun the guarded cycle: $($_.Exception.Message)")
        }
    }
    if (-not $gate.safe) {
        return [pscustomobject][ordered]@{
            experiment = [string]$Item.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @($gate.exactEvidenceRequest)
            environment = $gate.environment
        }
    }
    $evidenceRoot = Join-Path (Join-Path $DataRoot 'runs') ([string]$Item.experiment)
    $active = [ordered]@{
        schemaVersion = 1
        experiment = [string]$Item.experiment
        issue = [int]$Item.issue
        track = [string]$Item.track
        releaseState = 'Experimental'
        harnessPath = [string]$Item.harnessPath
        evidenceRoot = $evidenceRoot
        sourceCommit = Get-SourceCommit
        candidate = [string]$Item.candidate
        benchmark = [string]$Item.benchmark
        protectedScopes = @($Item.protectedScopes)
        startedUtc = [DateTime]::UtcNow.ToString('o')
        status = 'starting'
    }
    if (-not $PSCmdlet.ShouldProcess([string]$Item.experiment,'Start guarded reboot-aware physical validation')) {
        return [pscustomobject][ordered]@{ experiment=[string]$Item.experiment; evidenceStatus='ready'; whatIf=$true }
    }
    Write-JsonFile -Path $ActiveCyclePath -Value $active
    try {
        $arguments = @{
            Action = 'Start'
            RunsPerArm = [int]$Item.runsPerArm
            SampleSeconds = [int]$Item.sampleSeconds
            EvidenceRoot = $evidenceRoot
            Confirm = $false
        }
        if ($AllowAutomaticReboot -and [bool]$Item.automaticReboot) { $arguments.AllowAutomaticReboot = $true }
        $active.status = 'harness-active'
        Write-JsonFile -Path $ActiveCyclePath -Value $active
        & $harness @arguments
        [pscustomobject][ordered]@{
            experiment = [string]$Item.experiment
            evidenceStatus = 'validation-in-progress'
            automaticReboot = [bool]($AllowAutomaticReboot -and [bool]$Item.automaticReboot)
            evidenceRoot = $evidenceRoot
        }
    } catch {
        $startError = $_.Exception.Message
        $rollbackError = $null
        $harnessPointer = Join-Path $evidenceRoot 'active.json'
        if (Test-Path -LiteralPath $harnessPointer) {
            try {
                & $harness -Action Stop -EvidenceRoot $evidenceRoot -Confirm:$false | Out-Null
            } catch {
                $rollbackError = $_.Exception.Message
            }
        }
        $requests = @("Resolve the harness refusal and rerun the guarded cycle: $startError")
        if ($rollbackError) { $requests += "Complete and verify exact rollback from the retained active cycle: $rollbackError" }
        $failure = [ordered]@{
            schemaVersion = 1
            experiment = [string]$Item.experiment
            evidenceStatus = 'needs-evidence'
            failedUtc = [DateTime]::UtcNow.ToString('o')
            exactEvidenceRequest = $requests
        }
        Write-JsonFile -Path (Join-Path $DataRoot ('failure-{0}.json' -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))) -Value $failure
        if ($rollbackError) {
            $active.status = 'rollback-needs-evidence'
            $active.exactEvidenceRequest = $requests
            Write-JsonFile -Path $ActiveCyclePath -Value $active
        } else {
            Remove-Item -LiteralPath $ActiveCyclePath -Force -ErrorAction SilentlyContinue
        }
        [pscustomobject]$failure
    }
}

function Recover-ActiveValidation {
    param([Parameter(Mandatory=$true)]$Active)
    $harness = Resolve-RepositoryPath -RelativePath ([string]$Active.harnessPath)
    $harnessPointer = Join-Path ([string]$Active.evidenceRoot) 'active.json'
    if (-not (Test-Path -LiteralPath $harnessPointer)) {
        return [pscustomobject][ordered]@{
            experiment = [string]$Active.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @('Retain the active record and inspect the missing harness pointer before recovery.')
        }
    }
    if (-not $PSCmdlet.ShouldProcess([string]$Active.experiment,'Run the harness exact rollback and clear the incomplete active cycle')) {
        return [pscustomobject][ordered]@{ experiment=[string]$Active.experiment; evidenceStatus='recovery-ready'; whatIf=$true }
    }
    try {
        & $harness -Action Stop -EvidenceRoot ([string]$Active.evidenceRoot) -Confirm:$false | Out-Null
    } catch {
        return [pscustomobject][ordered]@{
            experiment = [string]$Active.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @("Complete and verify exact rollback from the retained active cycle: $($_.Exception.Message)")
        }
    }
    if (Test-Path -LiteralPath $harnessPointer) {
        return [pscustomobject][ordered]@{
            experiment = [string]$Active.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @('The harness Stop path returned without clearing its active pointer; retain the active cycle for inspection.')
        }
    }
    $recovery = [ordered]@{
        schemaVersion = 1
        experiment = [string]$Active.experiment
        evidenceStatus = 'recovered-needs-rerun'
        recoveredUtc = [DateTime]::UtcNow.ToString('o')
        exactEvidenceRequest = @('Rerun the ready experiment from one clean source commit; the incomplete run is not publishable evidence.')
    }
    Write-JsonFile -Path (Join-Path $DataRoot ('recovery-{0}.json' -f [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))) -Value $recovery
    Remove-Item -LiteralPath $ActiveCyclePath -Force
    return [pscustomobject]$recovery
}

$queue = Get-Queue
$ready = @($queue.items | Where-Object { [string]$_.state -eq 'ready' } | Sort-Object priority,experiment)

if ($Action -eq 'Inspect') {
    $active = if (Test-Path -LiteralPath $ActiveCyclePath) { Read-JsonFile -Path $ActiveCyclePath } else { $null }
    [pscustomobject][ordered]@{
        schemaVersion = 1
        activeExperiment = if ($active) { [string]$active.experiment } else { $null }
        readyExperiments = @($ready | ForEach-Object { [string]$_.experiment })
        queuePath = $QueuePath
        mutationPerformed = $false
    }
    return
}

if ($Action -eq 'Recover') {
    if (-not (Test-Path -LiteralPath $ActiveCyclePath)) {
        [pscustomobject][ordered]@{
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @('No active portfolio validation is registered for recovery.')
        }
        return
    }
    Recover-ActiveValidation -Active (Read-JsonFile -Path $ActiveCyclePath)
    return
}

if ($Action -eq 'Auto' -and (Test-Path -LiteralPath $RecoveryRequestPath)) {
    try {
        $request = Read-JsonFile -Path $RecoveryRequestPath
        if ([int]$request.schemaVersion -ne 1 -or [string]$request.action -ne 'recover') { throw 'Recovery request schema or action is invalid.' }
        if (-not (Test-Path -LiteralPath $ActiveCyclePath)) { throw 'Recovery request has no matching active portfolio cycle.' }
        $active = Read-JsonFile -Path $ActiveCyclePath
        if ([string]$request.experiment -ne [string]$active.experiment) { throw 'Recovery request experiment does not match the active cycle.' }
        if ([string]$request.activeSourceCommit -ne [string]$active.sourceCommit) { throw 'Recovery request source commit does not match the active cycle.' }
        if ([string]$request.runnerCommit -ne [string](Get-SourceCommit)) { throw 'Recovery request runner commit does not match the current checkout.' }
        $recoveryResult = Recover-ActiveValidation -Active $active
        if ([string]$recoveryResult.evidenceStatus -eq 'recovered-needs-rerun') {
            Remove-Item -LiteralPath $RecoveryRequestPath -Force
        }
        $recoveryResult
    } catch {
        [pscustomobject][ordered]@{
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @("Retain the active cycle and recovery request for inspection: $($_.Exception.Message)")
        }
    }
    return
}

if (Test-Path -LiteralPath $ActiveCyclePath) {
    $active = Read-JsonFile -Path $ActiveCyclePath
    $harnessPointer = Join-Path ([string]$active.evidenceRoot) 'active.json'
    $completedSummaries = @(Get-ChildItem -LiteralPath ([string]$active.evidenceRoot) -Filter 'summary.json' -File -Recurse -ErrorAction SilentlyContinue)
    if (-not (Test-Path -LiteralPath $harnessPointer) -and $completedSummaries.Count -gt 0) {
        Export-CompletedEvidence -Active $active
        return
    }
    try {
        $status = Get-ActiveHarnessStatus -Active $active
    } catch {
        [pscustomobject][ordered]@{
            experiment = [string]$active.experiment
            evidenceStatus = 'needs-evidence'
            exactEvidenceRequest = @("Run the portfolio cycle from an elevated local session to inspect or recover the retained harness: $($_.Exception.Message)")
        }
        return
    }
    $isActive = $true
    if ($status.PSObject.Properties.Name -contains 'active') { $isActive = [bool]$status.active }
    if ($Action -eq 'Export' -or -not $isActive) {
        Export-CompletedEvidence -Active $active
    } else {
        [pscustomobject][ordered]@{
            experiment = [string]$active.experiment
            evidenceStatus = 'validation-in-progress'
            harnessStatus = $status
            exactEvidenceRequest = @('Allow the registered reboot continuation task to complete the remaining baseline/treatment boots and exact rollback.')
        }
    }
    return
}

if ($Action -eq 'Export') {
    [pscustomobject][ordered]@{
        evidenceStatus = 'needs-evidence'
        exactEvidenceRequest = @('No completed or active portfolio validation is registered for export.')
    }
    return
}

if ($ready.Count -eq 0) {
    [pscustomobject][ordered]@{
        evidenceStatus = 'needs-evidence'
        exactEvidenceRequest = @('Add one reviewed Experimental reboot-aware harness to portfolio/validation-queue.json with state ready.')
    }
    return
}

Start-ReadyValidation -Item $ready[0]

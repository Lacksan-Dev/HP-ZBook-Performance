#requires -Version 5.1
<#
.SYNOPSIS
  Inventories Windows latency surfaces and captures a bounded WPR trace.

.DESCRIPTION
  EXP-023 is observation-only. Audit records common File Explorer context-menu
  handlers, loaded file-system minifilters, the configured Windows shell, and
  Windows Performance Recorder availability. Trace records one bounded ETW
  session with a Microsoft-supplied WPR profile.

  The script never disables a handler, unloads a filter, replaces Explorer, or
  changes a Windows setting. An inventory item is a measurement candidate, not
  evidence that the component is unnecessary or slow.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Audit', 'Trace', 'Status')]
    [string]$Action = 'Audit',

    [ValidateSet('GeneralProfile', 'FileIO', 'Minifilter')]
    [string]$Profile = 'GeneralProfile',

    [ValidateRange(5, 300)]
    [int]$Seconds = 30,

    [string]$OutputRoot = (Join-Path $env:LOCALAPPDATA 'Lacksan\EXP-023'),

    [switch]$SkipSignatureValidation
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:ExperimentId = 'EXP-023'
$script:SchemaVersion = 1
$script:FileMetadataCache = @{}
$script:HandlerTargets = @(
    '*',
    'AllFileSystemObjects',
    'Directory',
    'Directory\Background',
    'Drive',
    'Folder'
)

function Get-UtcTimestamp {
    (Get-Date).ToUniversalTime().ToString('o')
}

function New-EvidenceDirectory {
    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
    }
}

function Write-ExperimentEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Event,
        [Parameter(Mandatory = $true)][ValidateSet('Info', 'Pass', 'Warning', 'Failure')][string]$Status,
        [Parameter(Mandatory = $true)][hashtable]$Data
    )

    New-EvidenceDirectory
    $record = [ordered]@{
        timestampUtc = Get-UtcTimestamp
        experiment = $script:ExperimentId
        event = $Event
        status = $Status
        data = $Data
    }
    $record | ConvertTo-Json -Compress -Depth 12 |
        Add-Content -LiteralPath (Join-Path $OutputRoot 'events.jsonl') -Encoding UTF8
}

function Test-IsWindows {
    if ($env:OS -eq 'Windows_NT') {
        return $true
    }
    return $false
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RegistryDefaultValue {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)

    if (-not (Test-Path -LiteralPath $LiteralPath)) {
        return $null
    }
    $key = Get-Item -LiteralPath $LiteralPath
    return $key.GetValue($null, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
}

function Protect-LocalPath {
    param([AllowNull()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $protected = $Path
    $roots = @(
        [ordered]@{ value = $env:LOCALAPPDATA; token = '%LOCALAPPDATA%' },
        [ordered]@{ value = $env:APPDATA; token = '%APPDATA%' },
        [ordered]@{ value = $env:USERPROFILE; token = '%USERPROFILE%' }
    )
    foreach ($root in $roots) {
        if (-not [string]::IsNullOrWhiteSpace($root.value) -and
            $protected.StartsWith($root.value, [StringComparison]::OrdinalIgnoreCase)) {
            return $root.token + $protected.Substring($root.value.Length)
        }
    }
    return $protected
}

function Get-FileMetadata {
    param([AllowNull()][string]$Path)

    $expanded = $null
    $exists = $false
    $company = $null
    $version = $null
    $signatureStatus = 'NotChecked'
    $signer = $null

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $expanded = [Environment]::ExpandEnvironmentVariables($Path).Trim().Trim('"')
        if ($expanded -match '^\\SystemRoot\\') {
            $expanded = Join-Path $env:SystemRoot $expanded.Substring('\SystemRoot\'.Length)
        }
        elseif ($expanded -match '^System32\\') {
            $expanded = Join-Path $env:SystemRoot $expanded
        }

        $cacheKey = "$([bool]$SkipSignatureValidation)|$($expanded.ToLowerInvariant())"
        if ($script:FileMetadataCache.ContainsKey($cacheKey)) {
            $cached = $script:FileMetadataCache[$cacheKey]
            $exists = $cached.fileExists
            $company = $cached.company
            $version = $cached.fileVersion
            $signatureStatus = $cached.signatureStatus
            $signer = $cached.signer
        }
        else {
            $exists = Test-Path -LiteralPath $expanded -PathType Leaf
            if ($exists) {
                try {
                    $file = Get-Item -LiteralPath $expanded
                    $company = $file.VersionInfo.CompanyName
                    $version = $file.VersionInfo.FileVersion
                }
                catch {
                    $company = $null
                    $version = $null
                }

                if (-not $SkipSignatureValidation) {
                    try {
                        $signature = Get-AuthenticodeSignature -LiteralPath $expanded
                        $signatureStatus = $signature.Status.ToString()
                        if ($null -ne $signature.SignerCertificate) {
                            $signer = $signature.SignerCertificate.Subject
                        }
                    }
                    catch {
                        $signatureStatus = 'CheckFailed'
                    }
                }
            }
            else {
                $signatureStatus = 'FileMissing'
            }

            $script:FileMetadataCache[$cacheKey] = [ordered]@{
                fileExists = $exists
                company = $company
                fileVersion = $version
                signatureStatus = $signatureStatus
                signer = $signer
            }
        }
    }

    [ordered]@{
        registeredPath = Protect-LocalPath -Path $Path
        expandedPath = Protect-LocalPath -Path $expanded
        fileExists = $exists
        company = $company
        fileVersion = $version
        signatureStatus = $signatureStatus
        signer = $signer
    }
}

function Get-SystemIdentity {
    if (-not (Test-IsWindows)) {
        throw 'EXP-023 supports Windows only.'
    }

    $osPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if (-not (Test-Path -LiteralPath $osPath)) {
        throw 'Windows version registry data is unavailable.'
    }

    $os = Get-ItemProperty -LiteralPath $osPath
    $computer = $null
    $bios = $null
    try { $computer = Get-CimInstance Win32_ComputerSystem } catch {}
    try { $bios = Get-CimInstance Win32_BIOS } catch {}

    $manufacturer = if ($null -ne $computer) { $computer.Manufacturer } else { $null }
    $model = if ($null -ne $computer) { $computer.Model } else { $null }
    $biosVersion = if ($null -ne $bios) { $bios.SMBIOSBIOSVersion } else { $null }
    $isTargetZBook = ($manufacturer -match 'HP|Hewlett') -and ($model -match 'ZBook')

    [ordered]@{
        productName = $os.ProductName
        editionId = $os.EditionID
        displayVersion = $os.DisplayVersion
        build = $os.CurrentBuildNumber
        ubr = $os.UBR
        architecture = $env:PROCESSOR_ARCHITECTURE
        is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
        is64BitProcess = [Environment]::Is64BitProcess
        manufacturer = $manufacturer
        model = $model
        biosVersion = $biosVersion
        targetZBookDetected = [bool]$isTargetZBook
        elevated = [bool](Test-IsAdministrator)
    }
}

function Get-ShellConfiguration {
    $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $shell = $null
    if (Test-Path -LiteralPath $winlogonPath) {
        $shell = (Get-ItemProperty -LiteralPath $winlogonPath -Name Shell -ErrorAction SilentlyContinue).Shell
    }

    $edition = (Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
    $shellLauncherEditions = @(
        'Enterprise',
        'EnterpriseS',
        'Education',
        'IoTEnterprise',
        'IoTEnterpriseS'
    )
    $shellLauncherEditionSupported = $edition -in $shellLauncherEditions

    [ordered]@{
        configuredShell = $shell
        editionId = $edition
        shellLauncherEditionSupported = [bool]$shellLauncherEditionSupported
        decision = if ($shellLauncherEditionSupported) {
            'Replacement shell remains a dedicated kiosk-style experiment, not a baseline tweak.'
        }
        else {
            'Keep Explorer. Microsoft Shell Launcher is not supported on this Windows edition.'
        }
    }
}

function Resolve-ComServer {
    param([Parameter(Mandatory = $true)][string]$Clsid)

    # HKCR is a merged view. A per-user COM registration takes precedence even
    # when the handler registration itself is machine-wide.
    $candidatePaths = New-Object Collections.Generic.List[string]
    $candidatePaths.Add("HKCU:\SOFTWARE\Classes\CLSID\$Clsid\InprocServer32")
    $candidatePaths.Add("HKLM:\SOFTWARE\Classes\CLSID\$Clsid\InprocServer32")

    foreach ($candidatePath in $candidatePaths) {
        $value = Get-RegistryDefaultValue -LiteralPath $candidatePath
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            return [ordered]@{
                registryPath = $candidatePath
                file = Get-FileMetadata -Path ([string]$value)
            }
        }
    }

    return [ordered]@{
        registryPath = $null
        file = Get-FileMetadata -Path $null
    }
}

function Get-CommonShellContextMenuHandlers {
    $registrations = New-Object Collections.Generic.List[object]
    $roots = @(
        [ordered]@{ scope = 'Machine'; path = 'HKLM:\SOFTWARE\Classes' },
        [ordered]@{ scope = 'User'; path = 'HKCU:\SOFTWARE\Classes' }
    )

    foreach ($root in $roots) {
        foreach ($target in $script:HandlerTargets) {
            $handlerRoot = Join-Path $root.path "$target\shellex\ContextMenuHandlers"
            if (-not (Test-Path -LiteralPath $handlerRoot)) {
                continue
            }

            foreach ($registration in Get-ChildItem -LiteralPath $handlerRoot -ErrorAction SilentlyContinue) {
                $defaultValue = $registration.GetValue(
                    $null,
                    $null,
                    [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                )
                $clsid = [string]$defaultValue
                if ([string]::IsNullOrWhiteSpace($clsid) -and $registration.PSChildName -match '^\{[0-9A-Fa-f-]+\}$') {
                    $clsid = $registration.PSChildName
                }
                $server = if ([string]::IsNullOrWhiteSpace($clsid)) {
                    [ordered]@{ registryPath = $null; file = Get-FileMetadata -Path $null }
                }
                else {
                    Resolve-ComServer -Clsid $clsid
                }

                $registrations.Add([pscustomobject][ordered]@{
                    scope = $root.scope
                    target = $target
                    handlerType = 'ContextMenu'
                    registrationName = $registration.PSChildName
                    clsid = $clsid
                    serverRegistryPath = $server.registryPath
                    server = $server.file
                    candidateOnly = $true
                })
            }
        }
    }

    return @($registrations | Sort-Object scope, target, registrationName)
}

function Resolve-DriverImagePath {
    param([AllowNull()][string]$ImagePath)

    if ([string]::IsNullOrWhiteSpace($ImagePath)) {
        return $null
    }
    $resolved = [Environment]::ExpandEnvironmentVariables($ImagePath).Trim().Trim('"')
    if ($resolved -match '^\\SystemRoot\\') {
        return Join-Path $env:SystemRoot $resolved.Substring('\SystemRoot\'.Length)
    }
    if ($resolved -match '^System32\\') {
        return Join-Path $env:SystemRoot $resolved
    }
    return $resolved
}

function Get-MinifilterServiceMetadata {
    param([Parameter(Mandatory = $true)][string]$FilterName)

    $servicePath = "HKLM:\SYSTEM\CurrentControlSet\Services\$FilterName"
    if (-not (Test-Path -LiteralPath $servicePath)) {
        return [ordered]@{
            serviceRegistryPath = $null
            start = $null
            type = $null
            image = Get-FileMetadata -Path $null
        }
    }

    $service = Get-ItemProperty -LiteralPath $servicePath
    $imagePath = Resolve-DriverImagePath -ImagePath ([string]$service.ImagePath)
    [ordered]@{
        serviceRegistryPath = $servicePath
        start = $service.Start
        type = $service.Type
        image = Get-FileMetadata -Path $imagePath
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    $lines = @(& $FilePath @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    [ordered]@{
        filePath = $FilePath
        arguments = @($Arguments)
        exitCode = $exitCode
        output = $lines
    }
}

function Get-MinifilterInventory {
    $fltmc = Get-Command fltmc.exe -ErrorAction SilentlyContinue
    if ($null -eq $fltmc) {
        return [ordered]@{
            available = $false
            querySucceeded = $false
            error = 'fltmc.exe was not found.'
            filters = @()
            rawOutput = @()
        }
    }

    $result = Invoke-NativeCommand -FilePath $fltmc.Source -Arguments @('filters')
    $filters = New-Object Collections.Generic.List[object]
    if ($result.exitCode -eq 0) {
        foreach ($line in $result.output) {
            if ($line -match '^\s*(\S+)\s+(\d+)\s+([0-9.]+)\s+(\d+)\s*$') {
                $metadata = Get-MinifilterServiceMetadata -FilterName $matches[1]
                $filters.Add([pscustomobject][ordered]@{
                    name = $matches[1]
                    instances = [int]$matches[2]
                    altitude = $matches[3]
                    frame = [int]$matches[4]
                    service = $metadata
                    candidateOnly = $true
                })
            }
        }
    }

    $queryError = $null
    if ($result.exitCode -ne 0) {
        $queryError = $result.output -join [Environment]::NewLine
    }

    [ordered]@{
        available = $true
        querySucceeded = ($result.exitCode -eq 0)
        error = $queryError
        filters = $filters.ToArray()
        rawOutput = @($result.output)
    }
}

function Get-WprCapability {
    $wpr = Get-Command wpr.exe -ErrorAction SilentlyContinue
    if ($null -eq $wpr) {
        return [ordered]@{
            available = $false
            path = $null
            version = $null
            profiles = @()
        }
    }

    $profileResult = Invoke-NativeCommand -FilePath $wpr.Source -Arguments @('-profiles')
    $profiles = New-Object Collections.Generic.List[string]
    if ($profileResult.exitCode -eq 0) {
        foreach ($line in $profileResult.output) {
            if ($line -match '^\s{1,}([A-Za-z][A-Za-z0-9]+)\s{2,}') {
                $profiles.Add($matches[1])
            }
        }
    }

    $fileVersion = (Get-Item -LiteralPath $wpr.Source).VersionInfo.FileVersion
    [ordered]@{
        available = $true
        path = $wpr.Source
        version = $fileVersion
        profiles = $profiles.ToArray()
        selectedProfileAvailable = ($Profile -in $profiles.ToArray())
    }
}

function New-AuditRecord {
    $identity = Get-SystemIdentity
    $record = [ordered]@{
        schemaVersion = $script:SchemaVersion
        experiment = $script:ExperimentId
        evidenceClass = 'ObservationOnly'
        capturedAtUtc = Get-UtcTimestamp
        system = $identity
        shell = Get-ShellConfiguration
        commonContextMenuHandlers = @(Get-CommonShellContextMenuHandlers)
        minifilters = Get-MinifilterInventory
        wpr = Get-WprCapability
        interpretation = [ordered]@{
            documentedFact = 'Shell handlers can run in response to Explorer operations, and minifilters can observe or modify file I/O.'
            labMeasurement = 'This record is an inventory. It does not measure latency or prove that any listed component is slow.'
            hypothesis = 'A handler or minifilter that appears in a slow-path ETW trace may justify one isolated disable or replacement experiment.'
            unresolvedQuestion = 'Which component contributes measurable time to the selected customer workflow?'
        }
        limits = @(
            'Only common Explorer context-menu registration roots are inventoried.',
            'Registry results reflect the bitness of the PowerShell process that ran the audit.',
            'Packaged and file-type-specific shell extensions may require separate tracing.',
            'Loaded minifilters are candidates only; removing or unloading one can break security, encryption, backup, recovery, or storage behavior.',
            'WPR instrumentation overhead is not yet qualified for the EXP-001 formal decision rule.'
        )
        changesApplied = $false
    }
    return $record
}

function Save-AuditRecord {
    param([Parameter(Mandatory = $true)][hashtable]$Record)

    New-EvidenceDirectory
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $path = Join-Path $OutputRoot "latency-surface-audit-$stamp.json"
    $Record | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $path -Encoding UTF8

    $roundTrip = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ($roundTrip.schemaVersion -ne $script:SchemaVersion -or
        $roundTrip.experiment -ne $script:ExperimentId -or
        $roundTrip.changesApplied -ne $false) {
        throw 'Audit evidence verification failed.'
    }

    Write-ExperimentEvent -Event 'AuditCaptured' -Status 'Pass' -Data @{
        path = $path
        handlerCount = @($Record.commonContextMenuHandlers).Count
        minifilterCount = @($Record.minifilters.filters).Count
        changesApplied = $false
    }

    [pscustomobject][ordered]@{
        action = 'Audit'
        evidencePath = $path
        handlerCount = @($Record.commonContextMenuHandlers).Count
        minifilterCount = @($Record.minifilters.filters).Count
        minifilterQuerySucceeded = [bool]$Record.minifilters.querySucceeded
        wprAvailable = [bool]$Record.wpr.available
        changesApplied = $false
    }
}

function Show-WprStatus {
    $wpr = Get-Command wpr.exe -ErrorAction SilentlyContinue
    if ($null -eq $wpr) {
        throw 'wpr.exe was not found. Windows 8.1 or later is required.'
    }
    $result = Invoke-NativeCommand -FilePath $wpr.Source -Arguments @('-status')
    [pscustomobject][ordered]@{
        action = 'Status'
        exitCode = $result.exitCode
        output = @($result.output)
        changesApplied = $false
    }
}

function Invoke-BoundedTrace {
    $wprCapability = Get-WprCapability
    if (-not $wprCapability.available) {
        throw 'wpr.exe was not found. Windows 8.1 or later is required.'
    }
    if (-not $wprCapability.selectedProfileAvailable) {
        throw "The WPR profile '$Profile' is unavailable on this Windows build."
    }
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $tracePath = Join-Path $OutputRoot "latency-$($Profile.ToLowerInvariant())-$stamp.etl"
    $metadataPath = [IO.Path]::ChangeExtension($tracePath, '.json')
    $target = "WPR profile $Profile for $Seconds seconds"

    if (-not $PSCmdlet.ShouldProcess($tracePath, "Capture $target")) {
        return [pscustomobject][ordered]@{
            action = 'Trace'
            profile = $Profile
            seconds = $Seconds
            tracePath = $tracePath
            preview = $true
            changesApplied = $false
        }
    }

    $identity = Get-SystemIdentity
    if (-not $identity.elevated) {
        throw 'Trace requires an administrator PowerShell window. Audit and Trace -WhatIf do not.'
    }

    New-EvidenceDirectory
    $startedAt = Get-UtcTimestamp
    $startResult = Invoke-NativeCommand -FilePath $wprCapability.path -Arguments @(
        '-start',
        $Profile,
        '-filemode'
    )
    if ($startResult.exitCode -ne 0) {
        Write-ExperimentEvent -Event 'TraceStartFailed' -Status 'Failure' -Data @{
            profile = $Profile
            exitCode = $startResult.exitCode
            output = @($startResult.output)
        }
        throw "WPR failed to start profile '$Profile': $($startResult.output -join ' ')"
    }

    $stopResult = $null
    try {
        Write-Host "Recording $Profile for $Seconds seconds. Reproduce the slow action now."
        Start-Sleep -Seconds $Seconds
        $stopResult = Invoke-NativeCommand -FilePath $wprCapability.path -Arguments @('-stop', $tracePath)
        if ($stopResult.exitCode -ne 0) {
            throw "WPR failed to stop and save the trace: $($stopResult.output -join ' ')"
        }
    }
    catch {
        [void](Invoke-NativeCommand -FilePath $wprCapability.path -Arguments @('-cancel'))
        Write-ExperimentEvent -Event 'TraceCaptureFailed' -Status 'Failure' -Data @{
            profile = $Profile
            error = $_.Exception.Message
            tracePath = $tracePath
        }
        throw
    }

    if (-not (Test-Path -LiteralPath $tracePath -PathType Leaf)) {
        throw "WPR reported success but the trace file is missing: $tracePath"
    }

    $traceFile = Get-Item -LiteralPath $tracePath
    $metadata = [ordered]@{
        schemaVersion = $script:SchemaVersion
        experiment = $script:ExperimentId
        evidenceClass = 'ObservationOnlyTrace'
        profile = $Profile
        durationSeconds = $Seconds
        startedAtUtc = $startedAt
        completedAtUtc = Get-UtcTimestamp
        traceFileName = $traceFile.Name
        traceBytes = $traceFile.Length
        system = $identity
        instrumentationOverhead = 'Unqualified'
        changesApplied = $false
        interpretation = 'Open the ETL in Windows Performance Analyzer. A trace is evidence, not proof that a listed component should be removed.'
    }
    $metadata | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

    $verified = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    if ($verified.experiment -ne $script:ExperimentId -or
        $verified.traceFileName -ne $traceFile.Name -or
        $verified.changesApplied -ne $false) {
        throw 'Trace metadata verification failed.'
    }

    Write-ExperimentEvent -Event 'TraceCaptured' -Status 'Pass' -Data @{
        profile = $Profile
        seconds = $Seconds
        tracePath = $tracePath
        metadataPath = $metadataPath
        traceBytes = $traceFile.Length
        changesApplied = $false
    }

    [pscustomobject][ordered]@{
        action = 'Trace'
        profile = $Profile
        seconds = $Seconds
        tracePath = $tracePath
        metadataPath = $metadataPath
        traceBytes = $traceFile.Length
        preview = $false
        changesApplied = $false
    }
}

try {
    switch ($Action) {
        'Audit' {
            $audit = New-AuditRecord
            $result = Save-AuditRecord -Record $audit
            Write-Host "Audit saved: $($result.evidencePath)"
            if ($result.minifilterQuerySucceeded) {
                Write-Host "Candidates recorded: $($result.handlerCount) common shell handlers, $($result.minifilterCount) loaded minifilters."
            }
            else {
                Write-Host "Candidates recorded: $($result.handlerCount) common shell handlers. Minifilter enumeration needs an administrator window."
            }
            Write-Output $result
        }
        'Trace' {
            Write-Output (Invoke-BoundedTrace)
        }
        'Status' {
            Write-Output (Show-WprStatus)
        }
    }
}
catch {
    try {
        Write-ExperimentEvent -Event 'RunFailed' -Status 'Failure' -Data @{
            action = $Action
            error = $_.Exception.Message
            scriptStackTrace = $_.ScriptStackTrace
        }
    }
    catch {}
    Write-Error $_.Exception.Message
    exit 1
}

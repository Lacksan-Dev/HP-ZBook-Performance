[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$DataRoot = 'C:\ProgramData\ZBookPerf',

    [string]$StatusPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    $failure = [pscustomobject][ordered]@{
        schemaVersion = 1
        completedUtc = [DateTime]::UtcNow.ToString('o')
        succeeded = $false
        error = $_.Exception.Message
    } | ConvertTo-Json -Depth 4
    if ($StatusPath) {
        $failure | Set-Content -LiteralPath $StatusPath -Encoding UTF8
    } else {
        Write-Error $_
    }
    exit 1
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ContainedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Parent,
        [Parameter(Mandatory = $true)][string]$Child
    )
    $parentPath = [IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
    $childPath = [IO.Path]::GetFullPath($Child)
    return $childPath.StartsWith($parentPath, [StringComparison]::OrdinalIgnoreCase)
}

if (-not (Test-IsAdministrator)) {
    throw 'Administrator approval is required to remove legacy UX-ROM results from ProgramData.'
}

$root = [IO.Path]::GetFullPath($DataRoot).TrimEnd('\')
if ($root -ne 'C:\ProgramData\ZBookPerf' -and -not (Test-Path -LiteralPath $root -PathType Container)) {
    throw "The requested UX-ROM data root does not exist: $root"
}

$targets = @(
    (Join-Path $root 'traces')
    (Join-Path $root 'measurements')
)
$sessionPath = Join-Path $root 'session.json'
$removedFiles = 0
$removedBytes = [int64]0
$failures = New-Object System.Collections.ArrayList

foreach ($target in $targets) {
    if (-not (Test-ContainedPath -Parent $root -Child $target)) {
        throw "Refusing a cleanup target outside the UX-ROM data root: $target"
    }
    if (-not (Test-Path -LiteralPath $target -PathType Container)) { continue }
    foreach ($file in @(Get-ChildItem -LiteralPath $target -File -Recurse -Force -ErrorAction Stop)) {
        $length = [int64]$file.Length
        if (-not $PSCmdlet.ShouldProcess($file.FullName, 'Permanently remove UX-ROM test result')) { continue }
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $removedFiles++
            $removedBytes += $length
        } catch {
            [void]$failures.Add([pscustomobject]@{ path = $file.FullName; error = $_.Exception.Message })
        }
    }
    Get-ChildItem -LiteralPath $target -Directory -Recurse -Force -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $sessionPath -PathType Leaf) {
    if ($PSCmdlet.ShouldProcess($sessionPath, 'Permanently remove UX-ROM measurement session pointer')) {
        try {
            $sessionBytes = [int64](Get-Item -LiteralPath $sessionPath).Length
            Remove-Item -LiteralPath $sessionPath -Force -ErrorAction Stop
            $removedFiles++
            $removedBytes += $sessionBytes
        } catch {
            [void]$failures.Add([pscustomobject]@{ path = $sessionPath; error = $_.Exception.Message })
        }
    }
}

$traceMeasure = Get-ChildItem -LiteralPath (Join-Path $root 'traces') -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
$measurementMeasure = Get-ChildItem -LiteralPath (Join-Path $root 'measurements') -File -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum
$retainedTraceBytes = if ($null -eq $traceMeasure -or $null -eq $traceMeasure.Sum) { [int64]0 } else { [int64]$traceMeasure.Sum }
$retainedMeasurementBytes = if ($null -eq $measurementMeasure -or $null -eq $measurementMeasure.Sum) { [int64]0 } else { [int64]$measurementMeasure.Sum }

$result = [pscustomobject][ordered]@{
    schemaVersion = 1
    completedUtc = [DateTime]::UtcNow.ToString('o')
    succeeded = ($failures.Count -eq 0)
    dataRoot = $root
    removedFiles = $removedFiles
    removedBytes = $removedBytes
    retainedTraceBytes = $retainedTraceBytes
    retainedMeasurementBytes = $retainedMeasurementBytes
    failureCount = $failures.Count
    failures = @($failures)
    preservedSafetyState = @('changes.json', 'latest-synergy-batch.json', 'layer-workflow.json', 'logs')
} | ConvertTo-Json -Depth 6

if ($StatusPath) {
    $result | Set-Content -LiteralPath $StatusPath -Encoding UTF8
} else {
    $result
}

if ($failures.Count -gt 0) { exit 2 }

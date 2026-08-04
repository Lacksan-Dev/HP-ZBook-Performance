#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RepositoryRoot,
    [switch]$AllowAutomaticReboot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$runner = Join-Path $RepositoryRoot '.codex\scripts\Invoke-PortfolioValidation.ps1'
$logRoot = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Lacksan\LaptopCycle'
$logPath = Join-Path $logRoot 'cycle.log'

if (-not (Test-Path -LiteralPath (Join-Path $RepositoryRoot '.git'))) { throw "Not a Git checkout: $RepositoryRoot" }
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw "Validation runner is missing: $runner" }
if (-not (Test-Path -LiteralPath $logRoot)) { New-Item -ItemType Directory -Path $logRoot -Force | Out-Null }

$mutex = New-Object Threading.Mutex($false, 'Global\LacksanUxRomLaptopCycle')
$hasLock = $false
try {
    $hasLock = $mutex.WaitOne(0)
    if (-not $hasLock) { return }

    Start-Transcript -LiteralPath $logPath -Append | Out-Null
    try {
        $activeCycle = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Lacksan\PortfolioValidation\active-cycle.json'
        if (-not (Test-Path -LiteralPath $activeCycle)) {
            $dirty = @(& git -C $RepositoryRoot status --porcelain)
            if ($LASTEXITCODE -ne 0) { throw 'git status failed.' }
            if ($dirty.Count -gt 0) { throw 'Refusing to update a dirty laptop checkout.' }

            & git -C $RepositoryRoot fetch origin main --prune
            if ($LASTEXITCODE -ne 0) { throw 'git fetch origin main failed.' }
            & git -C $RepositoryRoot merge --ff-only origin/main
            if ($LASTEXITCODE -ne 0) { throw 'The laptop checkout cannot fast-forward to origin/main.' }
        }

        $arguments = @{ Action = 'Auto' }
        if ($AllowAutomaticReboot) { $arguments.AllowAutomaticReboot = $true }
        & $runner @arguments
    } finally {
        Stop-Transcript | Out-Null
    }
} finally {
    if ($hasLock) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}

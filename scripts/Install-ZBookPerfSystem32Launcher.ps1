#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\ZBookPerf.ps1')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-AtomicTextFile {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Content)
    $temporary = "$Path.new"
    Set-Content -LiteralPath $temporary -Value $Content -Encoding ASCII -NoNewline
    Copy-Item -LiteralPath $temporary -Destination $Path -Force
    Remove-Item -LiteralPath $temporary -Force
}

if (-not (Test-IsAdministrator)) { throw 'Run this installer from an elevated PowerShell session.' }
$SourcePath = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
$sourceText = Get-Content -LiteralPath $SourcePath -Raw
if ($sourceText -notmatch "'PerformanceTune'" -or $sourceText -notmatch "'PerformanceTuneRollback'") {
    throw 'The supplied ZBookPerf.ps1 does not include the current performance-tuning entry points.'
}

$systemRoot = [Environment]::GetFolderPath('System')
$targetScript = Join-Path $systemRoot 'ZBookPerf.ps1'
$targetLauncher = Join-Path $systemRoot 'ZBookPerf.cmd'
$backupRoot = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ("Lacksan\ZBookPerf\system32-backups\" + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))
$launcher = "@echo off`r`n`"%`$SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe`" -NoLogo -NoProfile -ExecutionPolicy Bypass -File `"%~dp0ZBookPerf.ps1`" %*`r`nexit /b %errorlevel%`r`n"

if ($PSCmdlet.ShouldProcess($systemRoot,'Back up the existing system launcher and install the current process-bypass launcher')) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    foreach ($target in @($targetScript,$targetLauncher)) {
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            Copy-Item -LiteralPath $target -Destination (Join-Path $backupRoot ([IO.Path]::GetFileName($target))) -Force
        }
    }
    $temporaryScript = "$targetScript.new"
    Copy-Item -LiteralPath $SourcePath -Destination $temporaryScript -Force
    if ((Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $temporaryScript -Algorithm SHA256).Hash) {
        throw 'The staged system script hash does not match the source.'
    }
    Copy-Item -LiteralPath $temporaryScript -Destination $targetScript -Force
    Remove-Item -LiteralPath $temporaryScript -Force
    Write-AtomicTextFile -Path $targetLauncher -Content $launcher
}

if ((Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $targetScript -Algorithm SHA256).Hash) {
    throw 'System script verification failed.'
}
if ((Get-Content -LiteralPath $targetLauncher -Raw) -ne $launcher) { throw 'System launcher verification failed.' }

[pscustomobject][ordered]@{
    Installed = $true
    Script = $targetScript
    Launcher = $targetLauncher
    BackupDirectory = $backupRoot
    Invocation = 'ZBookPerf.cmd -Action PerformanceTune -AllowAutomaticReboot'
    ExecutionPolicyScope = 'Process only'
}

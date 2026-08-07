#requires -Version 5.1

$ErrorActionPreference = 'Stop'
$mainRoot = 'https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/refs/heads/main'
$previewRoot = 'https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/refs/heads/agent/manual-performance-tuning'
$releaseRoot = $mainRoot
try {
    $mainProbe = Invoke-RestMethod -UseBasicParsing -Uri "$mainRoot/controller/maintenance/UxRomPerformanceTuning.ps1"
    if ($mainProbe -notmatch 'resume-captured') { throw 'Main does not contain the resumable runner yet.' }
} catch {
    $releaseRoot = $previewRoot
}
$bootstrapUri = "$releaseRoot/win.ps1"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    $elevatedCommand = "Invoke-RestMethod -UseBasicParsing -Uri '$bootstrapUri' | Invoke-Expression"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($elevatedCommand))
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Normal -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    return
}

$deployRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Lacksan\ZBookPerf'
$maintenanceRoot = Join-Path $deployRoot 'controller\maintenance'
New-Item -ItemType Directory -Path $maintenanceRoot -Force | Out-Null

$downloads = @(
    [pscustomobject]@{ Uri="$releaseRoot/ZBookPerf.ps1"; Path=(Join-Path $deployRoot 'ZBookPerf.ps1') },
    [pscustomobject]@{ Uri="$releaseRoot/controller/maintenance/UxRomPerformanceTuning.ps1"; Path=(Join-Path $maintenanceRoot 'UxRomPerformanceTuning.ps1') }
)

foreach ($download in $downloads) {
    $temporary = "$($download.Path).new"
    Invoke-WebRequest -UseBasicParsing -Uri $download.Uri -OutFile $temporary
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($temporary,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count -gt 0) { throw "Downloaded PowerShell failed parser validation: $($download.Uri)" }
    Copy-Item -LiteralPath $temporary -Destination $download.Path -Force
    Remove-Item -LiteralPath $temporary -Force
}

$entry = Join-Path $deployRoot 'ZBookPerf.ps1'
$arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$entry`" -Action PerformanceTune -AllowAutomaticReboot"
$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "UX-ROM exited with code $($process.ExitCode)." }

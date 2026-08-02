#requires -Version 5.1

[CmdletBinding()]
param(
    [string]$Destination = "$env:USERPROFILE\Desktop\ZBookPerf.ps1",
    [switch]$NoLaunch
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Test-InteractiveConsole {
    if ($Host.Name -ne 'ConsoleHost') { return $false }
    try { return (-not [Console]::IsOutputRedirected) } catch { return $false }
}

function Write-Stage {
    param([string]$Label,[int]$Frames=8,[int]$Delay=35)
    if (-not (Test-InteractiveConsole)) {
        Write-Host "$Label..." -ForegroundColor DarkGray
        return
    }
    $spin = @('|','/','-','\')
    $width = 22
    for ($frame=0; $frame -lt $Frames; $frame++) {
        $filled = [Math]::Max(1,[int][Math]::Ceiling((($frame+1)/[double]$Frames)*$width))
        $bar = ('#' * $filled) + ('.' * ($width-$filled))
        $line = '  {0} {1,-28} [{2}]' -f $spin[$frame % $spin.Count],$Label.ToUpperInvariant(),$bar
        Write-Host ("`r{0,-80}" -f $line) -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Milliseconds $Delay
    }
    Write-Host ("`r{0,-80}" -f ('  + {0,-28} [{1}]' -f $Label.ToUpperInvariant(),('#' * $width))) -ForegroundColor Green
}

function Download-Animated {
    param([string]$Uri,[string]$OutFile)
    $directory = Split-Path $OutFile -Parent
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $temporary = "$OutFile.download"
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue

    if (-not (Test-InteractiveConsole)) {
        Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $temporary
        Move-Item -LiteralPath $temporary -Destination $OutFile -Force
        return
    }

    $client = New-Object Net.WebClient
    $spin = @('|','/','-','\')
    $width = 26
    $tick = 0
    try {
        $task = $client.DownloadFileTaskAsync([Uri]$Uri,$temporary)
        while (-not $task.IsCompleted) {
            $track = New-Object char[] $width
            for ($i=0; $i -lt $width; $i++) { $track[$i]='.' }
            $track[$tick % $width]='>'
            $kb = 0
            if (Test-Path -LiteralPath $temporary) { $kb = [Math]::Round((Get-Item $temporary).Length / 1KB,1) }
            $line = '  {0} FETCHING UX-ROM [{1}] {2,7} KB' -f $spin[$tick % $spin.Count],(-join $track),$kb
            Write-Host ("`r{0,-88}" -f $line) -NoNewline -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 65
            $tick++
        }
        $task.GetAwaiter().GetResult()
        Move-Item -LiteralPath $temporary -Destination $OutFile -Force
        $kb = [Math]::Round((Get-Item $OutFile).Length / 1KB,1)
        Write-Host ("`r{0,-88}" -f ('  + FETCHING UX-ROM [' + ('#' * $width) + "] $kb KB")) -ForegroundColor Green
    } finally {
        $client.Dispose()
        Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host 'LACKSAN UX-ROM DEPLOYMENT' -ForegroundColor Red
Write-Stage -Label 'Authorizing session' -Frames 6 -Delay 30
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Write-Stage -Label 'Preparing destination' -Frames 5 -Delay 28

$uri = 'https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/ZBookPerf.ps1'
Download-Animated -Uri $uri -OutFile $Destination
Write-Stage -Label 'Unsealing package' -Frames 6 -Delay 28
Unblock-File -LiteralPath $Destination
Write-Stage -Label 'Verifying launch path' -Frames 6 -Delay 28

Write-Host "UX-ROM ready: $Destination" -ForegroundColor Green
if (-not $NoLaunch) {
    Write-Stage -Label 'Transferring control' -Frames 7 -Delay 28
    & $Destination
}

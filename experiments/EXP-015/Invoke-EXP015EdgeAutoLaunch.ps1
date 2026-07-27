[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Check','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath = "$env:ProgramData\Lacksan\EXP-015\state.json",
    [string]$LogPath = "$env:ProgramData\Lacksan\EXP-015\events.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RunPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
)
$ProtectedPattern = '(?i)(edgeupdate|microsoftedgeupdate|webview2|msedgewebview2|omnissa|horizon|tailscale|remote\s*desktop|windows\s*app|security|defender)'

function Write-Event {
    param([string]$Event,[string]$Result,[hashtable]$Data=@{})
    $dir = Split-Path -Parent $LogPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-015'; action=$Action; event=$Event; result=$Result; data=$Data } |
        ConvertTo-Json -Compress -Depth 8 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-Support {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $edge = @(
        "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match '(?i)HP|Hewlett' -and [bool]$edge)
        Windows = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        EdgePath = $edge
    }
}

function Test-Candidate {
    param([string]$Name,[string]$Command)
    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Command)) { return $false }
    $identity = "$Name $Command"
    if ($identity -match $ProtectedPattern) { return $false }
    return ($Name -match '(?i)(MicrosoftEdgeAutoLaunch|EdgeAutoLaunch|msedge)' -and
            $Command -match '(?i)(^|[\\\"\s])msedge\.exe([\"\s]|$)' -and
            $Command -match '(?i)(--no-startup-window|--win-session-start|--auto-launch-at-startup|--restore-last-session)')
}

function Get-Candidates {
    $items = @()
    foreach ($path in $RunPaths) {
        if (-not (Test-Path $path)) { continue }
        $key = Get-Item -LiteralPath $path
        foreach ($name in $key.GetValueNames()) {
            $value = $key.GetValue($name,$null,'DoNotExpandEnvironmentNames')
            if (Test-Candidate -Name $name -Command ([string]$value)) {
                $items += [pscustomobject]@{ Path=$path; Name=$name; Value=[string]$value; Kind=$key.GetValueKind($name).ToString() }
            }
        }
    }
    return @($items)
}

function Save-State {
    param([array]$Candidates)
    $dir = Split-Path -Parent $StatePath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [ordered]@{ schemaVersion=1; experiment='EXP-015'; capturedUtc=(Get-Date).ToUniversalTime().ToString('o'); machine=$env:COMPUTERNAME; user=$env:USERNAME; candidates=$Candidates } |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Read-State {
    if (-not (Test-Path $StatePath)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.experiment -ne 'EXP-015' -or $state.schemaVersion -ne 1) { throw 'State identity validation failed.' }
    return $state
}

function Remove-Candidates {
    param([array]$Candidates)
    foreach ($c in $Candidates) {
        if (-not (Test-Candidate -Name $c.Name -Command $c.Value)) { throw "Candidate identity changed: $($c.Path)::$($c.Name)" }
        if ($PSCmdlet.ShouldProcess("$($c.Path)::$($c.Name)",'Remove Edge auto-launch registration')) {
            Remove-ItemProperty -LiteralPath $c.Path -Name $c.Name -ErrorAction Stop
        }
    }
}

function Restore-Candidates {
    param($State)
    foreach ($c in @($State.candidates)) {
        if ($PSCmdlet.ShouldProcess("$($c.Path)::$($c.Name)",'Restore Edge auto-launch registration')) {
            if (-not (Test-Path $c.Path)) { New-Item -Path $c.Path -Force | Out-Null }
            New-ItemProperty -LiteralPath $c.Path -Name $c.Name -Value $c.Value -PropertyType $c.Kind -Force | Out-Null
        }
    }
}

try {
    $support = Get-Support
    if (-not $support.Supported) { Write-Event 'support' 'unsupported' @{ support=$support }; throw 'Supported HP Windows 11 system with Microsoft Edge was not detected.' }
    $current = Get-Candidates
    switch ($Action) {
        'Check' { Write-Event 'inventory' 'ok' @{ count=$current.Count; support=$support }; $current }
        'DryRun' { Write-Event 'dry-run' 'ok' @{ count=$current.Count }; $current }
        'Apply' {
            if (-not (Test-Path $StatePath)) { Save-State -Candidates $current }
            $state = Read-State
            Remove-Candidates -Candidates @($state.candidates)
            $remaining = Get-Candidates
            if ($remaining.Count -ne 0) { throw 'Application verification failed.' }
            Write-Event 'apply' 'ok' @{ removed=@($state.candidates).Count }
        }
        'Verify' {
            $remaining = Get-Candidates
            if ($remaining.Count -ne 0) { throw 'One or more bounded Edge auto-launch registrations remain.' }
            Write-Event 'verify' 'ok' @{ remaining=0 }
        }
        'VerifyReboot' {
            $state = Read-State
            $remaining = Get-Candidates
            if ($remaining.Count -ne 0) { throw 'Reboot persistence verification failed.' }
            Write-Event 'verify-reboot' 'ok' @{ capturedUtc=$state.capturedUtc; remaining=0 }
        }
        'Rollback' {
            $state = Read-State
            Restore-Candidates -State $state
            foreach ($c in @($state.candidates)) {
                $actual = (Get-ItemPropertyValue -LiteralPath $c.Path -Name $c.Name -ErrorAction Stop)
                if ([string]$actual -ne [string]$c.Value) { throw "Rollback verification failed: $($c.Path)::$($c.Name)" }
            }
            Write-Event 'rollback' 'ok' @{ restored=@($state.candidates).Count }
        }
    }
}
catch {
    Write-Event 'failure' 'error' @{ message=$_.Exception.Message }
    throw
}

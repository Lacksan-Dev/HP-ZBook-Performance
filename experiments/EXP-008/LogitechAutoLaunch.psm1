Set-StrictMode -Version Latest

$script:ProtectedPattern = '(?i)(omnissa|vmware|windows\s*app|remote\s*desktop|msrdc|tailscale|securityhealth|windows\s*security|credential|accessibility)'
$script:LogitechPattern = '(?i)(logi(?:tech)?|options\+|optionsplus|logi\s*bolt|logi\s*tune|lghub|g\s*hub)'
$script:UserSpacePattern = '(?i)(tray|agent|assistant|updat|telemetry|launcher|options|bolt|tune|lghub|g\s*hub)'
$script:RegistryPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
)

function Write-Exp008Log {
    param([string]$Path,[string]$Action,[string]$Result,[hashtable]$Data)
    $record = [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-008'; action=$Action; result=$Result; data=$Data }
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    ($record | ConvertTo-Json -Depth 8 -Compress) | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Test-Exp008Support {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match '(?i)HP|Hewlett')
        Windows = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
    }
}

function Test-Exp008Candidate {
    param([string]$Name,[string]$Command)
    $text = "$Name $Command"
    if ($text -match $script:ProtectedPattern) { return $false }
    return ($text -match $script:LogitechPattern -and $text -match $script:UserSpacePattern)
}

function Get-Exp008Inventory {
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($path in $script:RegistryPaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $key = Get-Item -LiteralPath $path
        foreach ($name in $key.GetValueNames()) {
            $command = [string]$key.GetValue($name,$null,'DoNotExpandEnvironmentNames')
            if (Test-Exp008Candidate -Name $name -Command $command) {
                $items.Add([pscustomobject]@{ Kind='Registry'; Path=$path; Name=$name; Value=$command; ValueKind=[string]$key.GetValueKind($name) })
            }
        }
    }
    $startupPaths = @([Environment]::GetFolderPath('Startup'),[Environment]::GetFolderPath('CommonStartup')) | Where-Object { $_ }
    foreach ($folder in $startupPaths) {
        if (-not (Test-Path -LiteralPath $folder)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue) {
            if (Test-Exp008Candidate -Name $file.Name -Command $file.FullName) {
                $items.Add([pscustomobject]@{ Kind='StartupFile'; Path=$file.FullName; Name=$file.Name; Value=$null; ValueKind=$null })
            }
        }
    }
    return @($items)
}

function Save-Exp008State {
    param([Parameter(Mandatory)][string]$StatePath)
    $state = [ordered]@{ schema=1; capturedUtc=(Get-Date).ToUniversalTime().ToString('o'); support=Test-Exp008Support; items=@(Get-Exp008Inventory) }
    $directory = Split-Path -Parent $StatePath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    return $state
}

function Invoke-Exp008Apply {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$StatePath,[Parameter(Mandatory)][string]$LogPath,[switch]$DryRun)
    $support = Test-Exp008Support
    if (-not $support.Supported) { throw "Unsupported system: $($support.Manufacturer) $($support.Model), $($support.Windows)" }
    $state = Save-Exp008State -StatePath $StatePath
    foreach ($item in $state.items) {
        if ($DryRun) { Write-Exp008Log -Path $LogPath -Action 'DryRunRemove' -Result 'Planned' -Data @{kind=$item.Kind;path=$item.Path;name=$item.Name}; continue }
        try {
            if ($item.Kind -eq 'Registry') {
                $current = (Get-Item -LiteralPath $item.Path).GetValue($item.Name,$null,'DoNotExpandEnvironmentNames')
                if (-not (Test-Exp008Candidate -Name $item.Name -Command ([string]$current))) { throw 'Candidate identity changed before apply.' }
                Remove-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction Stop
            } elseif ($item.Kind -eq 'StartupFile') {
                if (Test-Path -LiteralPath $item.Path) {
                    $backup = "$($item.Path).exp008.bak"
                    Copy-Item -LiteralPath $item.Path -Destination $backup -Force
                    Remove-Item -LiteralPath $item.Path -Force
                }
            }
            Write-Exp008Log -Path $LogPath -Action 'Apply' -Result 'Removed' -Data @{kind=$item.Kind;path=$item.Path;name=$item.Name}
        } catch {
            Write-Exp008Log -Path $LogPath -Action 'Apply' -Result 'Failed' -Data @{kind=$item.Kind;path=$item.Path;name=$item.Name;error=$_.Exception.Message}
            throw
        }
    }
    return Test-Exp008Applied -StatePath $StatePath
}

function Test-Exp008Applied {
    param([Parameter(Mandatory)][string]$StatePath)
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $remaining = @()
    foreach ($item in $state.items) {
        if ($item.Kind -eq 'Registry' -and (Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue)) { $remaining += $item }
        if ($item.Kind -eq 'StartupFile' -and (Test-Path -LiteralPath $item.Path)) { $remaining += $item }
    }
    [pscustomobject]@{ Verified=($remaining.Count -eq 0); Remaining=@($remaining) }
}

function Invoke-Exp008Rollback {
    param([Parameter(Mandatory)][string]$StatePath,[Parameter(Mandatory)][string]$LogPath)
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.schema -ne 1) { throw 'Unsupported state schema.' }
    foreach ($item in $state.items) {
        if ($item.Kind -eq 'Registry') {
            if (-not (Test-Path -LiteralPath $item.Path)) { New-Item -Path $item.Path -Force | Out-Null }
            New-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value $item.Value -PropertyType $item.ValueKind -Force | Out-Null
        } elseif ($item.Kind -eq 'StartupFile') {
            $backup = "$($item.Path).exp008.bak"
            if (-not (Test-Path -LiteralPath $backup)) { throw "Missing startup backup: $backup" }
            Move-Item -LiteralPath $backup -Destination $item.Path -Force
        }
        Write-Exp008Log -Path $LogPath -Action 'Rollback' -Result 'Restored' -Data @{kind=$item.Kind;path=$item.Path;name=$item.Name}
    }
    return Test-Exp008Rollback -StatePath $StatePath
}

function Test-Exp008Rollback {
    param([Parameter(Mandatory)][string]$StatePath)
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $missing = @()
    foreach ($item in $state.items) {
        if ($item.Kind -eq 'Registry') {
            $actual = (Get-Item -LiteralPath $item.Path -ErrorAction SilentlyContinue).GetValue($item.Name,$null,'DoNotExpandEnvironmentNames')
            if ([string]$actual -ne [string]$item.Value) { $missing += $item }
        } elseif ($item.Kind -eq 'StartupFile' -and -not (Test-Path -LiteralPath $item.Path)) { $missing += $item }
    }
    [pscustomobject]@{ Verified=($missing.Count -eq 0); Missing=@($missing) }
}

Export-ModuleMember -Function Test-Exp008Support,Test-Exp008Candidate,Get-Exp008Inventory,Save-Exp008State,Invoke-Exp008Apply,Test-Exp008Applied,Invoke-Exp008Rollback,Test-Exp008Rollback

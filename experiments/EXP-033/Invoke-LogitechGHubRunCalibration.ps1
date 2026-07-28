[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath = (Join-Path $PSScriptRoot 'state.json'),
    [string]$LogPath = (Join-Path $PSScriptRoot 'events.jsonl')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RunPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:ProtectedTokens = @('omnissa','vmware horizon','windows app','remote desktop','mstsc','tailscale','windows security','securityhealth','defender','credential','bitlocker')

function Write-ExpLog {
    param([string]$Event,[string]$Result,[hashtable]$Data=@{})
    $record = [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-033'; action=$Action; event=$Event; result=$Result; data=$Data }
    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $supported = ([version]$os.Version).Major -ge 10 -and $os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett-Packard'
    [pscustomobject]@{ Supported=$supported; OS=$os.Caption; Build=$os.BuildNumber; Manufacturer=$computer.Manufacturer; Model=$computer.Model }
}

function Test-ProtectedIdentity([string]$Name,[string]$Command) {
    $identity = ($Name + ' ' + $Command).ToLowerInvariant()
    foreach ($token in $script:ProtectedTokens) { if ($identity.Contains($token)) { return $true } }
    return $false
}

function Test-LogitechGHubIdentity([string]$Name,[string]$Command) {
    if (Test-ProtectedIdentity $Name $Command) { return $false }
    $nameMatch = $Name -match '(?i)^(LGHUB|Logitech G HUB|LogitechGHub)$'
    $exeMatch = $Command -match '(?i)(^|[\\/" ])lghub\.exe(?:[" ]|$)'
    $backgroundMatch = $Command -match '(?i)(--background|--minimized|/background|/minimized)'
    $updaterOnly = $Command -match '(?i)lghub_updater\.exe|updater'
    return ($nameMatch -and $exeMatch -and $backgroundMatch -and -not $updaterOnly)
}

function Get-RunCandidates {
    if (-not (Test-Path $script:RunPath)) { return @() }
    $key = Get-Item -LiteralPath $script:RunPath
    $items = foreach ($name in $key.GetValueNames()) {
        $value = [string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if (Test-LogitechGHubIdentity $name $value) {
            [pscustomobject]@{ Path=$script:RunPath; Name=$name; Data=$value; Kind=$key.GetValueKind($name).ToString() }
        }
    }
    return @($items)
}

function Save-State([object[]]$Candidates) {
    if ($Candidates.Count -gt 1) { throw 'More than one eligible Logitech G Hub Run registration was found; refine the candidate before applying.' }
    $state = [ordered]@{ schemaVersion=1; experiment='EXP-033'; capturedUtc=(Get-Date).ToUniversalTime().ToString('o'); machine=$env:COMPUTERNAME; userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value); entries=@($Candidates) }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    return $state
}

function Read-State {
    if (-not (Test-Path $StatePath)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.schemaVersion -ne 1 -or $state.experiment -ne 'EXP-033' -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $currentSid) { throw 'State identity validation failed.' }
    return $state
}

function Remove-Candidates([object[]]$Candidates) {
    foreach ($entry in $Candidates) {
        if (-not (Test-LogitechGHubIdentity $entry.Name $entry.Data)) { throw "Candidate identity changed: $($entry.Name)" }
        if ($PSCmdlet.ShouldProcess("$($entry.Path)::$($entry.Name)",'Remove Logitech G Hub startup registration')) {
            Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
        }
    }
}

function Restore-State($State) {
    foreach ($entry in @($State.entries)) {
        if (-not (Test-LogitechGHubIdentity $entry.Name $entry.Data)) { throw "Rollback state identity rejected: $($entry.Name)" }
        $existing = Get-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue
        if ($existing) { throw "Rollback refused because the registration already exists: $($entry.Name)" }
        if ($PSCmdlet.ShouldProcess("$($entry.Path)::$($entry.Name)",'Restore Logitech G Hub startup registration')) {
            if (-not (Test-Path $entry.Path)) { New-Item -Path $entry.Path -Force | Out-Null }
            $kind = [Microsoft.Win32.RegistryValueKind]::$($entry.Kind)
            $key = Get-Item -LiteralPath $entry.Path
            $key.SetValue($entry.Name,[string]$entry.Data,$kind)
        }
    }
}

function Test-Removed($State) {
    foreach ($entry in @($State.entries)) {
        if (Get-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue) { return $false }
    }
    return $true
}

function Test-Restored($State) {
    foreach ($entry in @($State.entries)) {
        $key = Get-Item -LiteralPath $entry.Path -ErrorAction SilentlyContinue
        if (-not $key) { return $false }
        $actual = [string]$key.GetValue($entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($actual -ne [string]$entry.Data -or $key.GetValueKind($entry.Name).ToString() -ne [string]$entry.Kind) { return $false }
    }
    return $true
}

try {
    $support = Get-SupportState
    Write-ExpLog 'support-detection' ($(if($support.Supported){'pass'}else{'unsupported'})) @{ os=$support.OS; build=$support.Build; manufacturer=$support.Manufacturer; model=$support.Model }
    if (-not $support.Supported) { throw 'EXP-033 supports HP systems running Windows 11 only.' }

    switch ($Action) {
        'Check' {
            $candidates = Get-RunCandidates
            Write-ExpLog 'candidate-inventory' 'pass' @{ count=$candidates.Count; names=@($candidates.Name) }
            $candidates
        }
        'Capture' {
            $candidates = Get-RunCandidates
            $state = Save-State $candidates
            Write-ExpLog 'state-capture' 'pass' @{ count=$candidates.Count; statePath=$StatePath }
            $state
        }
        'DryRun' {
            $candidates = Get-RunCandidates
            if ($candidates.Count -gt 1) { throw 'Dry run found multiple eligible registrations; no change is permitted.' }
            Write-ExpLog 'dry-run' 'pass' @{ count=$candidates.Count; names=@($candidates.Name) }
            [pscustomobject]@{ WouldRemove=@($candidates); StatePath=$StatePath }
        }
        'Apply' {
            $candidates = Get-RunCandidates
            if (-not (Test-Path $StatePath)) { Save-State $candidates | Out-Null }
            else {
                $saved = Read-State
                foreach ($current in $candidates) {
                    $match = @($saved.entries | Where-Object { $_.Name -eq $current.Name -and $_.Data -eq $current.Data -and $_.Kind -eq $current.Kind })
                    if ($match.Count -ne 1) { throw "Current candidate differs from captured state: $($current.Name)" }
                }
            }
            Remove-Candidates $candidates
            $state = Read-State
            if (-not (Test-Removed $state)) { throw 'Apply verification failed.' }
            Write-ExpLog 'apply' 'pass' @{ removed=$candidates.Count }
            [pscustomobject]@{ Applied=$true; Removed=$candidates.Count }
        }
        'Verify' {
            $state = Read-State
            $ok = Test-Removed $state
            Write-ExpLog 'verify' ($(if($ok){'pass'}else{'fail'})) @{}
            if (-not $ok) { throw 'Removal verification failed.' }
            $true
        }
        'VerifyReboot' {
            $state = Read-State
            $ok = Test-Removed $state
            Write-ExpLog 'verify-reboot' ($(if($ok){'pass'}else{'fail'})) @{ bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime }
            if (-not $ok) { throw 'Reboot persistence verification failed.' }
            $true
        }
        'Rollback' {
            $state = Read-State
            Restore-State $state
            if (-not (Test-Restored $state)) { throw 'Rollback verification failed.' }
            Write-ExpLog 'rollback' 'pass' @{ restored=@($state.entries).Count }
            [pscustomobject]@{ RolledBack=$true; Restored=@($state.entries).Count }
        }
    }
}
catch {
    Write-ExpLog 'failure' 'fail' @{ message=$_.Exception.Message; type=$_.Exception.GetType().FullName }
    throw
}

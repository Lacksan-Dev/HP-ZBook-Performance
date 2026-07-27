Set-StrictMode -Version Latest

$script:RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$script:ValueName = 'Logitech Download Assistant'
$script:ExpectedPayload = 'LogiLDA.dll'

function Write-Exp007Log {
    param([string]$Path,[string]$Action,[string]$Result,[hashtable]$Data)
    $record = [ordered]@{
        timestampUtc = [DateTime]::UtcNow.ToString('o')
        experiment = 'EXP-007'
        action = $Action
        result = $Result
        data = $Data
    }
    $record | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Get-Exp007Support {
    [CmdletBinding()]
    param()
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP')
        WindowsCaption = $os.Caption
        WindowsBuild = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        RegistryPath = $script:RegistryPath
        ValueName = $script:ValueName
    }
}

function Get-Exp007CurrentState {
    [CmdletBinding()]
    param()
    $exists = Test-Path -LiteralPath $script:RegistryPath
    $value = $null
    $kind = $null
    if ($exists) {
        try {
            $key = Get-Item -LiteralPath $script:RegistryPath -ErrorAction Stop
            $value = $key.GetValue($script:ValueName, $null, 'DoNotExpandEnvironmentNames')
            if ($null -ne $value) { $kind = $key.GetValueKind($script:ValueName).ToString() }
        } catch { }
    }
    $identityMatches = ($null -ne $value -and [string]$value -match [regex]::Escape($script:ExpectedPayload))
    [pscustomobject]@{
        Exists = ($null -ne $value)
        Value = $value
        Kind = $kind
        IdentityMatches = $identityMatches
    }
}

function Save-Exp007State {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    $support = Get-Exp007Support
    $state = Get-Exp007CurrentState
    $record = [ordered]@{
        schemaVersion = 1
        capturedAtUtc = [DateTime]::UtcNow.ToString('o')
        support = $support
        registry = [ordered]@{
            path = $script:RegistryPath
            name = $script:ValueName
            exists = $state.Exists
            kind = $state.Kind
            value = $state.Value
        }
    }
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    Get-FileHash -Algorithm SHA256 -LiteralPath $StatePath | Select-Object Path,Hash
}

function Invoke-Exp007DryRun {
    [CmdletBinding()]
    param()
    $support = Get-Exp007Support
    $state = Get-Exp007CurrentState
    [pscustomobject]@{
        WouldChange = ($support.Supported -and $state.Exists -and $state.IdentityMatches)
        Support = $support
        CurrentState = $state
        Reason = if (-not $support.Supported) {'Unsupported system'} elseif (-not $state.Exists) {'Registration absent'} elseif (-not $state.IdentityMatches) {'Command identity mismatch'} else {'Exact stale registration candidate matched'}
    }
}

function Remove-Exp007Registration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][string]$LogPath
    )
    $support = Get-Exp007Support
    if (-not $support.Supported) { throw 'EXP-007 supports HP systems running Windows 11 only.' }
    $state = Get-Exp007CurrentState
    if (-not $state.Exists) {
        Write-Exp007Log -Path $LogPath -Action 'Apply' -Result 'NoChange' -Data @{ reason='Already absent' }
        return Get-Exp007CurrentState
    }
    if (-not $state.IdentityMatches) { throw 'Refusing to modify a registration whose command identity differs from LogiLDA.dll.' }
    if (-not (Test-Path -LiteralPath $StatePath)) { Save-Exp007State -StatePath $StatePath | Out-Null }
    if ($PSCmdlet.ShouldProcess("$script:RegistryPath\$script:ValueName", 'Remove exact startup registration')) {
        Remove-ItemProperty -LiteralPath $script:RegistryPath -Name $script:ValueName -ErrorAction Stop
    }
    $after = Get-Exp007CurrentState
    if ($after.Exists) { throw 'Verification failed: startup registration remains present.' }
    Write-Exp007Log -Path $LogPath -Action 'Apply' -Result 'Success' -Data @{ removed=$script:ValueName }
    $after
}

function Restore-Exp007Registration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][string]$LogPath
    )
    if (-not (Test-Path -LiteralPath $StatePath)) { throw 'Rollback state file is missing.' }
    $saved = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($saved.registry.path -ne $script:RegistryPath -or $saved.registry.name -ne $script:ValueName) { throw 'Rollback state identity mismatch.' }
    if ($saved.registry.exists) {
        if ($PSCmdlet.ShouldProcess("$script:RegistryPath\$script:ValueName", 'Restore exact startup registration')) {
            New-Item -Path $script:RegistryPath -Force | Out-Null
            $kind = [Microsoft.Win32.RegistryValueKind]::$($saved.registry.kind)
            $key = Get-Item -LiteralPath $script:RegistryPath
            $key.SetValue($script:ValueName, [string]$saved.registry.value, $kind)
        }
    } else {
        Remove-ItemProperty -LiteralPath $script:RegistryPath -Name $script:ValueName -ErrorAction SilentlyContinue
    }
    $after = Get-Exp007CurrentState
    if ([bool]$saved.registry.exists -ne [bool]$after.Exists) { throw 'Rollback verification failed.' }
    if ($saved.registry.exists -and [string]$saved.registry.value -ne [string]$after.Value) { throw 'Rollback value verification failed.' }
    Write-Exp007Log -Path $LogPath -Action 'Rollback' -Result 'Success' -Data @{ restored=[bool]$saved.registry.exists }
    $after
}

function Test-Exp007RebootPersistence {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ExpectedStatePath)
    $saved = Get-Content -LiteralPath $ExpectedStatePath -Raw | ConvertFrom-Json
    $current = Get-Exp007CurrentState
    [pscustomobject]@{
        Passed = ([bool]$saved.expectedExists -eq [bool]$current.Exists)
        ExpectedExists = [bool]$saved.expectedExists
        ActualExists = [bool]$current.Exists
    }
}

Export-ModuleMember -Function Get-Exp007Support,Get-Exp007CurrentState,Save-Exp007State,Invoke-Exp007DryRun,Remove-Exp007Registration,Restore-Exp007Registration,Test-Exp007RebootPersistence

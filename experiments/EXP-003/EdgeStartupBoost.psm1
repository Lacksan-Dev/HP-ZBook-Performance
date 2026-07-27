Set-StrictMode -Version Latest

$script:PolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$script:PolicyName = 'StartupBoostEnabled'
$script:LaunchPolicyName = 'LaunchEdgeOnWindowsStartupEnabled'

function Write-Exp003Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Action,
        [Parameter(Mandatory)] [object] $Data
    )
    $directory = Split-Path -Parent $Path
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [pscustomobject]@{
        TimestampUtc = [DateTime]::UtcNow.ToString('o')
        Experiment = 'EXP-003'
        Action = $Action
        Data = $Data
    } | ConvertTo-Json -Depth 10 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Get-Exp003Support {
    [CmdletBinding()]
    param()
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
    $edgePaths = @(
        $(if ($programFilesX86) { Join-Path $programFilesX86 'Microsoft\Edge\Application\msedge.exe' }),
        $(if ($programFiles) { Join-Path $programFiles 'Microsoft\Edge\Application\msedge.exe' })
    ) | Where-Object { $_ }
    $edgePath = $edgePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $version = $null
    if ($edgePath) { $version = (Get-Item -LiteralPath $edgePath).VersionInfo.ProductVersion }
    $major = if ($version) { [int](($version -split '\.')[0]) } else { 0 }
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match '^HP' -and $edgePath -and $major -ge 88)
        WindowsCaption = $os.Caption
        WindowsBuild = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        EdgePath = $edgePath
        EdgeVersion = $version
        Reason = if (-not ($os.Caption -match 'Windows 11')) { 'Windows 11 required' }
                 elseif (-not ($computer.Manufacturer -match '^HP')) { 'HP system required' }
                 elseif (-not $edgePath) { 'Microsoft Edge executable missing' }
                 elseif ($major -lt 88) { 'Microsoft Edge 88 or later required' }
                 else { 'Supported' }
    }
}

function Get-RegistryValueState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Name
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Path=$Path; Name=$Name; KeyExists=$false; Exists=$false; Kind=$null; Value=$null }
    }
    $key = Get-Item -LiteralPath $Path
    try {
        $value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $value) {
            return [pscustomobject]@{ Path=$Path; Name=$Name; KeyExists=$true; Exists=$false; Kind=$null; Value=$null }
        }
        [pscustomobject]@{ Path=$Path; Name=$Name; KeyExists=$true; Exists=$true; Kind=[string]$key.GetValueKind($Name); Value=$value }
    }
    catch {
        [pscustomobject]@{ Path=$Path; Name=$Name; KeyExists=$true; Exists=$false; Kind=$null; Value=$null }
    }
}

function Get-Exp003State {
    [CmdletBinding()]
    param()
    $processes = @(
        Get-Process -Name msedge -ErrorAction SilentlyContinue | ForEach-Object {
            $startTime = $null
            try { $startTime = $_.StartTime.ToUniversalTime().ToString('o') } catch { $startTime = $null }
            [pscustomobject]@{ Id=$_.Id; WorkingSet64=$_.WorkingSet64; StartTime=$startTime }
        }
    )
    [pscustomobject]@{
        StartupBoost = Get-RegistryValueState -Path $script:PolicyPath -Name $script:PolicyName
        VisibleLaunchAtStartup = Get-RegistryValueState -Path $script:PolicyPath -Name $script:LaunchPolicyName
        EdgeProcesses = $processes
    }
}

function Save-Exp003State {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $StatePath)
    $support = Get-Exp003Support
    if (-not $support.Supported) { throw "Unsupported system: $($support.Reason)" }
    $directory = Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $payload = [ordered]@{
        SchemaVersion = 1
        Experiment = 'EXP-003'
        CapturedAtUtc = [DateTime]::UtcNow.ToString('o')
        Support = $support
        State = Get-Exp003State
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    return [pscustomobject]$payload
}

function Invoke-Exp003DryRun {
    [CmdletBinding()]
    param([ValidateSet('Enable','Disable')] [string] $StartupBoost = 'Enable')
    $support = Get-Exp003Support
    $state = Get-Exp003State
    $desired = if ($StartupBoost -eq 'Enable') { 1 } else { 0 }
    [pscustomobject]@{
        Supported = $support.Supported
        Reason = $support.Reason
        DesiredStartupBoost = $desired
        CurrentState = $state
        WouldChange = ($support.Supported -and ((-not $state.StartupBoost.Exists) -or [int]$state.StartupBoost.Value -ne $desired -or (-not $state.VisibleLaunchAtStartup.Exists) -or [int]$state.VisibleLaunchAtStartup.Value -ne 0))
        PreservesStartupFolder = $true
        VisibleLaunchAtWindowsStartupDisabled = $true
    }
}

function Set-Exp003StartupBoost {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Enable','Disable')] [string] $StartupBoost = 'Enable',
        [Parameter(Mandatory)] [string] $StatePath,
        [Parameter(Mandatory)] [string] $LogPath
    )
    $support = Get-Exp003Support
    if (-not $support.Supported) { throw "Unsupported system: $($support.Reason)" }
    if (-not (Test-Path -LiteralPath $StatePath)) { Save-Exp003State -StatePath $StatePath | Out-Null }
    $desired = if ($StartupBoost -eq 'Enable') { 1 } else { 0 }
    $before = Get-Exp003State
    if ($PSCmdlet.ShouldProcess($script:PolicyPath, "Set StartupBoostEnabled=$desired and LaunchEdgeOnWindowsStartupEnabled=0")) {
        New-Item -Path $script:PolicyPath -Force | Out-Null
        New-ItemProperty -LiteralPath $script:PolicyPath -Name $script:PolicyName -Value $desired -PropertyType DWord -Force | Out-Null
        New-ItemProperty -LiteralPath $script:PolicyPath -Name $script:LaunchPolicyName -Value 0 -PropertyType DWord -Force | Out-Null
    }
    $verification = Test-Exp003Configuration -ExpectedStartupBoost $desired
    if (-not $verification.Success) { throw "EXP-003 verification failed: $($verification.Reason)" }
    Write-Exp003Log -Path $LogPath -Action 'Apply' -Data ([pscustomobject]@{ Requested=$StartupBoost; Before=$before; Verification=$verification })
    return $verification
}

function Test-Exp003Configuration {
    [CmdletBinding()]
    param([ValidateSet(0,1)] [int] $ExpectedStartupBoost = 1)
    $state = Get-Exp003State
    $boostOk = ($state.StartupBoost.Exists -and [int]$state.StartupBoost.Value -eq $ExpectedStartupBoost)
    $visibleLaunchOk = ($state.VisibleLaunchAtStartup.Exists -and [int]$state.VisibleLaunchAtStartup.Value -eq 0)
    [pscustomobject]@{
        Success = ($boostOk -and $visibleLaunchOk)
        StartupBoostMatches = $boostOk
        VisibleLaunchAtStartupDisabled = $visibleLaunchOk
        State = $state
        Reason = if (-not $boostOk) { 'StartupBoostEnabled mismatch' } elseif (-not $visibleLaunchOk) { 'Visible Edge startup policy mismatch' } else { 'Verified' }
    }
}

function Restore-Exp003State {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $StatePath,
        [Parameter(Mandatory)] [string] $LogPath
    )
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
    $saved = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($saved.Experiment -ne 'EXP-003' -or [int]$saved.SchemaVersion -ne 1) { throw 'Rollback state identity mismatch' }
    foreach ($item in @($saved.State.StartupBoost, $saved.State.VisibleLaunchAtStartup)) {
        if ($item.Path -ne $script:PolicyPath -or $item.Name -notin @($script:PolicyName,$script:LaunchPolicyName)) { throw 'Rollback registry identity mismatch' }
        if ($PSCmdlet.ShouldProcess("$($item.Path)\$($item.Name)", 'Restore exact prior policy state')) {
            if ($item.Exists) {
                New-Item -Path $item.Path -Force | Out-Null
                $kind = [Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind], [string]$item.Kind, $true)
                $key = Get-Item -LiteralPath $item.Path
                $key.SetValue([string]$item.Name, $item.Value, $kind)
            }
            elseif (Test-Path -LiteralPath $item.Path) {
                Remove-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
            }
        }
    }
    $after = Get-Exp003State
    $restoreOk = $true
    foreach ($savedItem in @($saved.State.StartupBoost, $saved.State.VisibleLaunchAtStartup)) {
        $actual = if ($savedItem.Name -eq $script:PolicyName) { $after.StartupBoost } else { $after.VisibleLaunchAtStartup }
        if ([bool]$savedItem.Exists -ne [bool]$actual.Exists) { $restoreOk = $false }
        if ($savedItem.Exists -and ([string]$savedItem.Value -ne [string]$actual.Value -or [string]$savedItem.Kind -ne [string]$actual.Kind)) { $restoreOk = $false }
    }
    if (-not $restoreOk) { throw 'Rollback verification failed' }
    Write-Exp003Log -Path $LogPath -Action 'Rollback' -Data $after
    return [pscustomobject]@{ Success=$true; State=$after }
}

function Test-Exp003RebootPersistence {
    [CmdletBinding()]
    param([ValidateSet(0,1)] [int] $ExpectedStartupBoost = 1)
    return Test-Exp003Configuration -ExpectedStartupBoost $ExpectedStartupBoost
}

Export-ModuleMember -Function @(
    'Get-Exp003Support','Get-Exp003State','Save-Exp003State','Invoke-Exp003DryRun',
    'Set-Exp003StartupBoost','Test-Exp003Configuration','Restore-Exp003State',
    'Test-Exp003RebootPersistence'
)

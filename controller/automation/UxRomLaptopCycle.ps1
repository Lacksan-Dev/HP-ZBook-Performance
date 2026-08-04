#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Install','Remove','Status')]
    [string]$Action = 'Status',
    [Parameter(Mandatory = $true)]
    [string]$RepositoryRoot,
    [ValidateRange(1,24)]
    [int]$IntervalHours = 2,
    [switch]$AllowAutomaticReboot
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$taskName = 'UX-ROM Laptop Cycle'
$taskPath = '\Lacksan\'
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$cycle = Join-Path $RepositoryRoot '.codex\scripts\Invoke-LaptopCycle.ps1'

function Get-CycleTask {
    Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
}

function Get-LaptopTargetIdentity {
    $computer = Get-CimInstance Win32_ComputerSystem
    $product = Get-CimInstance Win32_ComputerSystemProduct
    $enclosures = @(Get-CimInstance Win32_SystemEnclosure)
    $battery = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    $chassisTypes = @($enclosures | ForEach-Object { @($_.ChassisTypes) } | ForEach-Object { [int]$_ })
    [pscustomobject][ordered]@{
        manufacturer = [string]$computer.Manufacturer
        model = [string]$computer.Model
        uuid = ([string]$product.UUID).Trim().ToUpperInvariant()
        chassisTypes = $chassisTypes
        hasBattery = ($battery.Count -gt 0)
    }
}

function Assert-ZBookLaptopTarget {
    $identity = Get-LaptopTargetIdentity
    $portableChassis = @(8,9,10,14,30,31,32)
    if ($identity.manufacturer -notmatch '(?i)^HP$|Hewlett-Packard') { throw 'Laptop-cycle installation requires an HP system.' }
    if ($identity.model -notmatch '(?i)\bZBook\b') { throw "Laptop-cycle installation requires an HP ZBook laptop. Detected model: $($identity.model)" }
    if (-not $identity.hasBattery) { throw 'Laptop-cycle installation requires a battery-equipped HP ZBook laptop.' }
    if (@($identity.chassisTypes | Where-Object { $_ -in $portableChassis }).Count -eq 0) {
        throw "Laptop-cycle installation requires a portable chassis. Detected chassis types: $($identity.chassisTypes -join ',')"
    }
    if ([string]::IsNullOrWhiteSpace($identity.uuid) -or $identity.uuid -match '^(0+|F+)(-(0+|F+))*$') {
        throw 'Laptop-cycle installation requires a usable hardware UUID.'
    }
    return $identity
}

if ($Action -eq 'Status') {
    $task = Get-CycleTask
    $identity = $null
    try { $identity = Get-LaptopTargetIdentity } catch { }
    [pscustomobject][ordered]@{
        installed = ($null -ne $task)
        taskName = "$taskPath$taskName"
        state = if ($task) { [string]$task.State } else { 'NotInstalled' }
        repositoryRoot = $RepositoryRoot
        intervalHours = $IntervalHours
        currentManufacturer = if ($identity) { $identity.manufacturer } else { $null }
        currentModel = if ($identity) { $identity.model } else { $null }
        currentMachineUuid = if ($identity) { $identity.uuid } else { $null }
    }
    return
}

if ($Action -eq 'Remove') {
    if (Get-CycleTask) {
        if ($PSCmdlet.ShouldProcess("$taskPath$taskName", 'Remove UX-ROM laptop cycle')) {
            Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
        }
    }
    return
}

if (-not (Test-Path -LiteralPath $cycle -PathType Leaf)) { throw "Laptop cycle script is missing: $cycle" }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principalCheck = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principalCheck.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run InstallLaptopCycle from an elevated Windows PowerShell session.'
}

# Installation is intentionally hardware-scoped. Running this action on a desktop,
# another HP system, or another ZBook cannot create a reboot-authorized cycle.
$target = Assert-ZBookLaptopTarget

$quote = [char]34
$argumentList = '-NoProfile -ExecutionPolicy Bypass -File ' + $quote + $cycle + $quote + ' -RepositoryRoot ' + $quote + $RepositoryRoot + $quote + ' -ExpectedMachineUuid ' + $quote + $target.uuid + $quote
if ($AllowAutomaticReboot) { $argumentList += ' -AllowAutomaticReboot' }
$taskAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $argumentList -WorkingDirectory $RepositoryRoot
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)
$logon = New-ScheduledTaskTrigger -AtLogOn -User $identity.Name
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 8)
$principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive -RunLevel Highest

if ($PSCmdlet.ShouldProcess("$taskPath$taskName", "Install recurring $IntervalHours-hour UX-ROM laptop cycle bound to $($target.model) $($target.uuid)")) {
    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $taskAction -Trigger @($repeat,$logon) -Settings $settings -Principal $principal -Description 'Pull approved UX-ROM main, resume reboot-aware validation, and run one guarded experiment on the exact bound HP ZBook laptop.' -Force | Out-Null
    Get-CycleTask
}

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

if ($Action -eq 'Status') {
    $task = Get-CycleTask
    [pscustomobject][ordered]@{
        installed = ($null -ne $task)
        taskName = "$taskPath$taskName"
        state = if ($task) { [string]$task.State } else { 'NotInstalled' }
        repositoryRoot = $RepositoryRoot
        intervalHours = $IntervalHours
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

$quote = [char]34
$argumentList = '-NoProfile -ExecutionPolicy Bypass -File ' + $quote + $cycle + $quote + ' -RepositoryRoot ' + $quote + $RepositoryRoot + $quote
if ($AllowAutomaticReboot) { $argumentList += ' -AllowAutomaticReboot' }
$taskAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $argumentList -WorkingDirectory $RepositoryRoot
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) -RepetitionInterval (New-TimeSpan -Hours $IntervalHours)
$logon = New-ScheduledTaskTrigger -AtLogOn -User $identity.Name
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 8)
$principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType Interactive -RunLevel Highest

if ($PSCmdlet.ShouldProcess("$taskPath$taskName", "Install recurring $IntervalHours-hour UX-ROM laptop cycle")) {
    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $taskAction -Trigger @($repeat,$logon) -Settings $settings -Principal $principal -Description 'Pull approved UX-ROM main, resume reboot-aware validation, and run one guarded experiment.' -Force | Out-Null
    Get-CycleTask
}

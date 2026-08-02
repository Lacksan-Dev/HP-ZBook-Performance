[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'evidence')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Classification {
    param([string]$Text)
    $t = $Text.ToLowerInvariant()
    if ($t -match 'omnissa|windows app|remote desktop|tailscale|defender|securityhealth|credential|bitlocker|recovery|windows update|edgeupdate|driver|hid|bluetooth') {
        return @{ Class='protected'; Reason='protected startup allowlist or platform/device-critical component' }
    }
    if ($t -match 'teams|office|microsoft 365|logi|logitech|lghub|g hub|telemetry|updat') {
        return @{ Class='priority-target'; Reason='EXP-002 priority user-application startup candidate' }
    }
    return @{ Class='review-required'; Reason='non-allowlisted registration requires application-purpose review' }
}

function Add-Record {
    param([System.Collections.Generic.List[object]]$List,[string]$Surface,[string]$Identity,[string]$Command,[object]$State)
    $c = Get-Classification "$Identity $Command"
    $List.Add([pscustomobject]@{
        surface=$Surface; identity=$Identity; command=$Command; originalState=$State
        classification=$c.Class; classificationReason=$c.Reason; evidenceStatus='needs-evidence'
    })
}

$records = [System.Collections.Generic.List[object]]::new()

# Startup folders. Read only; preserve shortcut itself as exact registration identity.
$startupFolders = @(
    [Environment]::GetFolderPath('Startup'),
    [Environment]::GetFolderPath('CommonStartup')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
foreach ($folder in $startupFolders) {
    Get-ChildItem -LiteralPath $folder -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
        Add-Record $records 'StartupFolder' $_.FullName $_.FullName @{ length=$_.Length; lastWriteUtc=$_.LastWriteTimeUtc.ToString('o') }
    }
}

# Approved Run/RunOnce locations, both registry views exposed by the current host.
$runKeys = @(
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
)
foreach ($key in $runKeys) {
    if (!(Test-Path $key)) { continue }
    $item = Get-Item $key
    foreach ($name in $item.GetValueNames()) {
        $data = $item.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        Add-Record $records 'Registry' "$key::$name" ([string]$data) @{ kind=$item.GetValueKind($name).ToString(); data=$data }
    }
}

# Packaged StartupTask state via supported CIM inventory where available.
try {
    Get-CimInstance -Namespace root\cimv2\mdm\dmmap -ClassName MDM_EnterpriseModernAppManagement_AppManagement01 -ErrorAction Stop | ForEach-Object {
        $text = $_ | ConvertTo-Json -Compress -Depth 5
        if ($text -match 'Startup') { Add-Record $records 'StartupTask' ([string]$_.InstanceID) $text @{ cim=$text } }
    }
} catch { }

# Sign-in/logon scheduled tasks. Export XML to retain exact task definition for evidence/restore planning.
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $task = $_
    $hasLogon = @($task.Triggers | Where-Object { $_.CimClass.CimClassName -match 'Logon' }).Count -gt 0
    if (!$hasLogon) { return }
    $xml = $null
    try { $xml = Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath } catch { }
    $actions = ($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)".Trim() }) -join '; '
    Add-Record $records 'ScheduledTask' "$($task.TaskPath)$($task.TaskName)" $actions @{ enabled=($task.State -ne 'Disabled'); xml=$xml }
}

$normalized = @($records | Sort-Object surface,identity,command)
$duplicates = $normalized | Group-Object command | Where-Object { $_.Name -and $_.Count -gt 1 } | ForEach-Object {
    [pscustomobject]@{ command=$_.Name; registrations=@($_.Group | ForEach-Object identity) }
}
$machine = [pscustomobject]@{
    windowsBuild=[Environment]::OSVersion.Version.ToString()
    computerName=$env:COMPUTERNAME
    timestampUtc=(Get-Date).ToUniversalTime().ToString('o')
}
$bundle = [pscustomobject]@{ experiment='EXP-143'; mode='read-only'; machine=$machine; registrations=$normalized; duplicates=@($duplicates) }

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$json = $bundle | ConvertTo-Json -Depth 12
$jsonPath = Join-Path $OutputDirectory 'startup-inventory.json'
$json | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$hash = (Get-FileHash -LiteralPath $jsonPath -Algorithm SHA256).Hash
$event = [pscustomobject]@{ timestampUtc=$machine.timestampUtc; experiment='EXP-143'; action='inventory'; mutation=$false; registrationCount=$normalized.Count; snapshotSha256=$hash }
($event | ConvertTo-Json -Compress) | Add-Content -LiteralPath (Join-Path $OutputDirectory 'startup-inventory.jsonl') -Encoding UTF8

[pscustomobject]@{ Snapshot=$jsonPath; Sha256=$hash; RegistrationCount=$normalized.Count; PriorityCount=@($normalized | Where-Object classification -eq 'priority-target').Count; ProtectedCount=@($normalized | Where-Object classification -eq 'protected').Count }

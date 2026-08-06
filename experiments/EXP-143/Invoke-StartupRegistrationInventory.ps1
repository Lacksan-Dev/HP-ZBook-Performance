[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'evidence')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Classification {
    param([string]$Text)
    $t = $Text.ToLowerInvariant()
    if ($t -match 'omnissa|vmware[- ]?view|horizon|windows app|remote desktop|mstsc|msrdc|tailscale|defender|securityhealth|credential|bitlocker|recovery|windows update|edgeupdate|driver|hid|bluetooth|accessib|narrator|magnify|firmware|management|mdm|intune|configmgr|sccm') {
        return @{ Class='protected'; Reason='protected startup allowlist or platform/device-critical component' }
    }
    if ($t -match 'teams|msteams|office|microsoft 365|microsoft365|officeclicktorun|officehub|logi|logitech|lghub|g hub|telemetry|updat') {
        return @{ Class='priority-target'; Reason='EXP-002 priority user-application startup candidate' }
    }
    return @{ Class='review-required'; Reason='non-allowlisted registration requires application-purpose review' }
}

function Add-Record {
    param([System.Collections.Generic.List[object]]$List,[string]$Surface,[string]$Identity,[string]$Command,[object]$State)
    # Classification uses registration metadata as well as identity/command. Packaged StartupTasks often expose
    # useful product/publisher/display-name evidence only in manifest metadata while executable identity is sparse.
    $stateText = if ($null -eq $State) { '' } else { $State | ConvertTo-Json -Compress -Depth 8 }
    $c = Get-Classification "$Identity $Command $stateText"
    $List.Add([pscustomobject]@{
        surface=$Surface; identity=$Identity; command=$Command; originalState=$State
        classification=$c.Class; classificationReason=$c.Reason; evidenceStatus='needs-evidence'
    })
}

$records = [System.Collections.Generic.List[object]]::new()

# Startup folders. Read only. Resolve shortcut target/arguments/working directory when WScript is available while preserving the shortcut path as registration identity.
$startupFolders = @(
    [Environment]::GetFolderPath('Startup'),
    [Environment]::GetFolderPath('CommonStartup')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
foreach ($folder in $startupFolders) {
    Get-ChildItem -LiteralPath $folder -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
        $command = $_.FullName
        $target = $null
        $arguments = $null
        $workingDirectory = $null
        if ($_.Extension -ieq '.lnk') {
            try {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($_.FullName)
                $target = $shortcut.TargetPath
                $arguments = $shortcut.Arguments
                $workingDirectory = $shortcut.WorkingDirectory
                if ($target) { $command = ('"{0}" {1}' -f $target,$arguments).Trim() }
            } catch { }
        }

        # Capture filesystem security evidence through read-only ACL APIs. An unreadable descriptor is retained
        # explicitly as needs-evidence instead of fabricating an owner or descriptor.
        $owner = $null
        $sddl = $null
        $aclEvidenceStatus = 'captured'
        $aclEvidenceErrorType = $null
        try {
            $acl = Get-Acl -LiteralPath $_.FullName -ErrorAction Stop
            $owner = [string]$acl.Owner
            $sddl = [string]$acl.GetSecurityDescriptorSddlForm([System.Security.AccessControl.AccessControlSections]::All)
            if ([string]::IsNullOrWhiteSpace($owner) -or [string]::IsNullOrWhiteSpace($sddl)) {
                $aclEvidenceStatus = 'needs-evidence'
            }
        } catch {
            $aclEvidenceStatus = 'needs-evidence'
            $aclEvidenceErrorType = $_.Exception.GetType().FullName
        }

        # Capture byte-exact local restore evidence now, while the inventory remains read only.
        $fileBytes = [IO.File]::ReadAllBytes($_.FullName)
        $fileSha = [Security.Cryptography.SHA256]::Create()
        try { $fileHash = ([BitConverter]::ToString($fileSha.ComputeHash($fileBytes))).Replace('-','') } finally { $fileSha.Dispose() }
        Add-Record $records 'StartupFolder' $_.FullName $command @{
            length=$_.Length; sha256=$fileHash; contentBase64=[Convert]::ToBase64String($fileBytes)
            attributes=[string]$_.Attributes; creationTimeUtc=$_.CreationTimeUtc.ToString('o'); lastWriteTimeUtc=$_.LastWriteTimeUtc.ToString('o')
            target=$target; arguments=$arguments; workingDirectory=$workingDirectory
            owner=$owner; sddl=$sddl; aclEvidenceStatus=$aclEvidenceStatus; aclEvidenceErrorType=$aclEvidenceErrorType
        }
    }
}

# Approved Run/RunOnce locations.
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

# Packaged StartupTask registrations. Read package manifests directly so ordinary current-user app registrations are inventoried without requiring MDM enrollment.
Get-AppxPackage -ErrorAction SilentlyContinue | Sort-Object PackageFamilyName,PackageFullName | ForEach-Object {
    $package = $_
    try {
        [xml]$manifest = Get-AppxPackageManifest -Package $package.PackageFullName -ErrorAction Stop
        $extensions = @($manifest.SelectNodes("//*[local-name()='Extension' and @Category='windows.startupTask']"))
        foreach ($extension in $extensions) {
            $startupTasks = @($extension.SelectNodes(".//*[local-name()='StartupTask']"))
            if ($startupTasks.Count -eq 0) { $startupTasks = @($extension) }
            foreach ($startupTask in $startupTasks) {
                $taskId = [string]$startupTask.TaskId
                if ([string]::IsNullOrWhiteSpace($taskId)) { $taskId = [string]$extension.StartupTask.TaskId }
                $executable = [string]$extension.Executable
                $entryPoint = [string]$extension.EntryPoint
                $command = @($executable,$entryPoint) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                $commandText = ($command -join ' ').Trim()
                $identity = "$($package.PackageFamilyName)::$taskId"
                Add-Record $records 'StartupTask' $identity $commandText @{
                    packageName=$package.Name; packageFamilyName=$package.PackageFamilyName; packageFullName=$package.PackageFullName
                    publisher=$package.Publisher; version=[string]$package.Version; taskId=$taskId
                    enabledByDefault=[string]$startupTask.Enabled; displayName=[string]$startupTask.DisplayName
                    executable=$executable; entryPoint=$entryPoint; runtimeState='needs-evidence'; source='AppxManifest'
                }
            }
        }
    } catch { }
}

# Sign-in/logon scheduled tasks. Export XML first because trigger/action CIM metadata differs across Windows PowerShell and PowerShell 7.
# XML is read-only, provides a stable logon-trigger qualifier, and retains the exact task definition for later restore planning.
Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $task = $_
    $xml = $null
    try { $xml = Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath } catch { return }
    if ([string]::IsNullOrWhiteSpace($xml) -or $xml -notmatch '<LogonTrigger(?:\s|>)') { return }

    $actions = ''
    try {
        [xml]$taskDocument = $xml
        $actionParts = @($taskDocument.SelectNodes("//*[local-name()='Actions']/*") | ForEach-Object {
            $commandNode = $_.SelectSingleNode("./*[local-name()='Command']")
            $argumentsNode = $_.SelectSingleNode("./*[local-name()='Arguments']")
            $classNode = $_.SelectSingleNode("./*[local-name()='ClassId']")
            if ($null -ne $commandNode) {
                (([string]$commandNode.InnerText) + ' ' + $(if ($null -ne $argumentsNode) { [string]$argumentsNode.InnerText } else { '' })).Trim()
            } elseif ($null -ne $classNode) {
                'ComHandler ' + [string]$classNode.InnerText
            } else {
                $_.LocalName
            }
        })
        $actions = ($actionParts -join '; ').Trim()
    } catch {
        $actions = 'needs-evidence'
    }

    Add-Record $records 'ScheduledTask' "$($task.TaskPath)$($task.TaskName)" $actions @{ enabled=($task.State -ne 'Disabled'); xml=$xml }
}

$normalized = @($records | Sort-Object surface,identity,command)
$duplicates = @($normalized | Group-Object command | Where-Object { $_.Name -and $_.Count -gt 1 } | ForEach-Object {
    [pscustomobject]@{ command=$_.Name; registrations=@($_.Group | ForEach-Object identity | Sort-Object) }
} | Sort-Object command)

# Hash only stable registration evidence. Runtime metadata is logged separately so repeated unchanged inventories produce the same SHA-256.
$stableBundle = [pscustomobject]@{ experiment='EXP-143'; schemaVersion=6; mode='read-only'; registrations=$normalized; duplicates=$duplicates }
$stableJson = $stableBundle | ConvertTo-Json -Depth 12
$stableBytes = [Text.Encoding]::UTF8.GetBytes($stableJson)
$sha = [Security.Cryptography.SHA256]::Create()
try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stableBytes))).Replace('-','') } finally { $sha.Dispose() }

$run = [pscustomobject]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); windowsBuild=[Environment]::OSVersion.Version.ToString(); computerName=$env:COMPUTERNAME; snapshotSha256=$hash }
$bundle = [pscustomobject]@{ evidence=$stableBundle; run=$run }

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$jsonPath = Join-Path $OutputDirectory 'startup-inventory.json'
($bundle | ConvertTo-Json -Depth 14) | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$event = [pscustomobject]@{ timestampUtc=$run.timestampUtc; experiment='EXP-143'; action='inventory'; mutation=$false; registrationCount=$normalized.Count; snapshotSha256=$hash }
($event | ConvertTo-Json -Compress) | Add-Content -LiteralPath (Join-Path $OutputDirectory 'startup-inventory.jsonl') -Encoding UTF8

[pscustomobject]@{ Snapshot=$jsonPath; Sha256=$hash; RegistrationCount=$normalized.Count; PriorityCount=@($normalized | Where-Object classification -eq 'priority-target').Count; ProtectedCount=@($normalized | Where-Object classification -eq 'protected').Count }

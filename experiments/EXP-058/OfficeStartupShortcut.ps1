[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath = "$PSScriptRoot\state.json",
    [string]$BackupPath = "$PSScriptRoot\shortcut-backup.lnk",
    [string]$LogPath = "$PSScriptRoot\events.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$experiment = 'EXP-058'
$eligibleExecutables = @('OUTLOOK.EXE','WINWORD.EXE','EXCEL.EXE','POWERPNT.EXE','ONENOTE.EXE','MSACCESS.EXE')
$protectedNames = @('omnissa','windows app','remote desktop','tailscale')

function Write-Event {
    param([string]$Event,[string]$Result,[object]$Data)
    $record = [ordered]@{
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        experiment = $experiment
        action = $Action
        event = $Event
        result = $Result
        data = $Data
    }
    $directory = Split-Path -Parent $LogPath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Compress -Depth 12) -Encoding UTF8
}

function Get-StartupFolder {
    [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
}

function Resolve-Shortcut {
    param([Parameter(Mandatory)][string]$Path)
    $shell = New-Object -ComObject WScript.Shell
    try {
        $shortcut = $shell.CreateShortcut($Path)
        [pscustomobject]@{
            Path = $Path
            TargetPath = $shortcut.TargetPath
            Arguments = $shortcut.Arguments
            WorkingDirectory = $shortcut.WorkingDirectory
            IconLocation = $shortcut.IconLocation
            Description = $shortcut.Description
            WindowStyle = $shortcut.WindowStyle
        }
    }
    finally {
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
}

function Get-Candidates {
    $startup = [IO.Path]::GetFullPath((Get-StartupFolder)).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $startup -PathType Container)) { return @() }

    $matches = foreach ($file in Get-ChildItem -LiteralPath $startup -Filter '*.lnk' -File -ErrorAction Stop) {
        $full = [IO.Path]::GetFullPath($file.FullName)
        if (-not $full.StartsWith($startup + '\',[StringComparison]::OrdinalIgnoreCase)) { continue }
        $resolved = Resolve-Shortcut -Path $full
        if (-not $resolved.TargetPath) { continue }
        $targetName = [IO.Path]::GetFileName($resolved.TargetPath).ToUpperInvariant()
        $nameText = ($file.BaseName + ' ' + $resolved.TargetPath).ToLowerInvariant()
        if ($protectedNames | Where-Object { $nameText.Contains($_) }) { continue }
        if ($targetName -notin $eligibleExecutables) { continue }
        if ($resolved.Arguments -and $resolved.Arguments.Trim().Length -gt 0) { continue }
        [pscustomobject]@{ File = $file; Shortcut = $resolved }
    }
    @($matches)
}

function Get-Support {
    $os = Get-CimInstance Win32_OperatingSystem
    $candidates = Get-Candidates
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $candidates.Count -eq 1)
        OS = $os.Caption
        Build = $os.BuildNumber
        StartupFolder = Get-StartupFolder
        CandidateCount = $candidates.Count
        Candidate = if ($candidates.Count -eq 1) { $candidates[0] } else { $null }
    }
}

function Assert-Supported {
    param($Support)
    if (-not ($Support.OS -match 'Windows 11')) { throw 'Windows 11 is required.' }
    if ($Support.CandidateCount -ne 1) { throw 'Exactly one eligible Microsoft 365 Startup-folder shortcut is required.' }
}

function Get-FileSnapshot {
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    $resolved = Resolve-Shortcut -Path $Path
    [ordered]@{
        path = $item.FullName
        length = $item.Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        creationTimeUtc = $item.CreationTimeUtc.ToString('o')
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
        attributes = [int]$item.Attributes
        targetPath = $resolved.TargetPath
        arguments = $resolved.Arguments
        workingDirectory = $resolved.WorkingDirectory
        iconLocation = $resolved.IconLocation
        description = $resolved.Description
        windowStyle = $resolved.WindowStyle
    }
}

function Save-State {
    param($Support)
    $candidate = $Support.Candidate
    Copy-Item -LiteralPath $candidate.File.FullName -Destination $BackupPath -Force
    $state = [ordered]@{
        schemaVersion = 1
        experiment = $experiment
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        os = $Support.OS
        build = $Support.Build
        startupFolder = $Support.StartupFolder
        shortcut = Get-FileSnapshot -Path $candidate.File.FullName
        backup = [ordered]@{
            path = [IO.Path]::GetFullPath($BackupPath)
            sha256 = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
        }
    }
    $directory = Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $state | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.schemaVersion -ne 1 -or $state.experiment -ne $experiment -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid) {
        throw 'State identity validation failed.'
    }
    $state
}

function Test-Removed {
    if (-not (Test-Path -LiteralPath $StatePath)) { return $false }
    $state = Read-State
    -not (Test-Path -LiteralPath $state.shortcut.path)
}

function Test-Restored {
    $state = Read-State
    if (-not (Test-Path -LiteralPath $state.shortcut.path -PathType Leaf)) { return $false }
    $current = Get-FileSnapshot -Path $state.shortcut.path
    $current.sha256 -eq $state.shortcut.sha256 -and
        $current.targetPath -eq $state.shortcut.targetPath -and
        $current.arguments -eq $state.shortcut.arguments -and
        $current.workingDirectory -eq $state.shortcut.workingDirectory -and
        $current.iconLocation -eq $state.shortcut.iconLocation -and
        $current.description -eq $state.shortcut.description -and
        $current.windowStyle -eq $state.shortcut.windowStyle
}

try {
    $support = Get-Support
    Write-Event 'support-detection' 'ok' $support
    switch ($Action) {
        'Check' { $support }
        'Capture' {
            Assert-Supported $support
            $state = Save-State $support
            Write-Event 'capture' 'ok' $state
            $state
        }
        'DryRun' {
            Assert-Supported $support
            $preview = [ordered]@{ delete = $support.Candidate.File.FullName; target = $support.Candidate.Shortcut.TargetPath; preserveOffice = $true; preserveProtectedApps = $true }
            Write-Event 'dry-run' 'ok' $preview
            $preview
        }
        'Apply' {
            if (Test-Path -LiteralPath $StatePath) {
                $state = Read-State
                if (-not (Test-Path -LiteralPath $state.shortcut.path)) { Write-Event 'apply' 'already-applied' $null; break }
            }
            Assert-Supported $support
            $state = if (Test-Path -LiteralPath $StatePath) { Read-State } else { Save-State $support }
            if (-not (Test-Path -LiteralPath $state.backup.path) -or (Get-FileHash -LiteralPath $state.backup.path -Algorithm SHA256).Hash -ne $state.backup.sha256) { throw 'Rollback backup is missing or has drifted.' }
            if ((Get-FileHash -LiteralPath $state.shortcut.path -Algorithm SHA256).Hash -ne $state.shortcut.sha256) { throw 'Shortcut drift detected before application.' }
            if ($PSCmdlet.ShouldProcess($state.shortcut.path,'Delete one captured Microsoft 365 Startup-folder shortcut')) {
                Remove-Item -LiteralPath $state.shortcut.path -Force
                if (Test-Path -LiteralPath $state.shortcut.path) { throw 'Deletion verification failed.' }
                Write-Event 'apply' 'ok' @{ path = $state.shortcut.path; sha256 = $state.shortcut.sha256 }
            }
        }
        'Verify' { $result = Test-Removed; Write-Event 'verify' $(if($result){'ok'}else{'failed'}) @{ removed = $result }; $result }
        'VerifyReboot' { $result = Test-Removed; Write-Event 'verify-reboot' $(if($result){'ok'}else{'failed'}) @{ removed = $result }; $result }
        'Rollback' {
            $state = Read-State
            if (Test-Path -LiteralPath $state.shortcut.path) {
                if (Test-Restored) { Write-Event 'rollback' 'already-restored' $null; break }
                throw 'Rollback refused because the original path contains different content.'
            }
            if (-not (Test-Path -LiteralPath $state.backup.path -PathType Leaf)) { throw 'Captured shortcut backup is missing.' }
            if ((Get-FileHash -LiteralPath $state.backup.path -Algorithm SHA256).Hash -ne $state.backup.sha256) { throw 'Captured shortcut backup hash mismatch.' }
            if ($PSCmdlet.ShouldProcess($state.shortcut.path,'Restore captured Microsoft 365 Startup-folder shortcut')) {
                Copy-Item -LiteralPath $state.backup.path -Destination $state.shortcut.path
                $item = Get-Item -LiteralPath $state.shortcut.path
                $item.CreationTimeUtc = [datetime]$state.shortcut.creationTimeUtc
                $item.LastWriteTimeUtc = [datetime]$state.shortcut.lastWriteTimeUtc
                $item.Attributes = [IO.FileAttributes][int]$state.shortcut.attributes
                if (-not (Test-Restored)) { throw 'Exact rollback verification failed.' }
                Write-Event 'rollback' 'ok' @{ path = $state.shortcut.path; sha256 = $state.shortcut.sha256 }
            }
        }
    }
}
catch {
    Write-Event 'failure' 'error' @{ message = $_.Exception.Message; type = $_.Exception.GetType().FullName }
    throw
}

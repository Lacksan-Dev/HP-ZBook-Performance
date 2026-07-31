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
$allowedPublisherPattern = 'Microsoft Corporation'

function Write-Event {
    param([string]$Event,[string]$Result,[object]$Data)
    $record = [ordered]@{
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        experiment = $experiment
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        action = $Action
        event = $Event
        result = $Result
        data = $Data
    }
    $directory = Split-Path -Parent $LogPath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    Add-Content -LiteralPath $LogPath -Value ($record | ConvertTo-Json -Compress -Depth 16) -Encoding UTF8
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

function Get-ManagementSignals {
    $domainJoined = $false
    try { $domainJoined = [bool](Get-CimInstance Win32_ComputerSystem).PartOfDomain } catch { }
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Enrollments',
        'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device',
        'HKLM:\SOFTWARE\Microsoft\CCM',
        'HKLM:\SOFTWARE\Policies\Microsoft\Office'
    )
    $present = @($paths | Where-Object { Test-Path -LiteralPath $_ })
    [pscustomobject]@{
        DomainJoined = $domainJoined
        Indicators = $present
        Managed = ($domainJoined -or $present.Count -gt 0)
    }
}

function Get-TargetIdentity {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Shortcut target is missing: $Path" }
    $item = Get-Item -LiteralPath $Path -Force
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    [pscustomobject]@{
        Path = $item.FullName
        FileName = $item.Name
        Version = $item.VersionInfo.FileVersion
        ProductName = $item.VersionInfo.ProductName
        Sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        SignatureStatus = [string]$signature.Status
        Publisher = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
        IsMicrosoftOfficePath = ($item.FullName -match '(?i)\\Microsoft Office\\|\\Microsoft 365\\')
        IsValidPublisher = ($signature.Status -eq 'Valid' -and $signature.SignerCertificate -and $signature.SignerCertificate.Subject -match $allowedPublisherPattern)
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
        try { $identity = Get-TargetIdentity -Path $resolved.TargetPath } catch { continue }
        if (-not $identity.IsMicrosoftOfficePath -or -not $identity.IsValidPublisher) { continue }
        [pscustomobject]@{ File = $file; Shortcut = $resolved; TargetIdentity = $identity }
    }
    @($matches)
}

function Get-Support {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    $management = Get-ManagementSignals
    $candidates = Get-Candidates
    $isHp = ($computer.Manufacturer -match '^(HP|Hewlett-Packard)')
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $isHp -and -not $management.Managed -and $candidates.Count -eq 1)
        OS = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        IsHp = $isHp
        Management = $management
        StartupFolder = Get-StartupFolder
        CandidateCount = $candidates.Count
        Candidate = if ($candidates.Count -eq 1) { $candidates[0] } else { $null }
    }
}

function Assert-Supported {
    param($Support)
    if (-not ($Support.OS -match 'Windows 11')) { throw 'Windows 11 is required.' }
    if (-not $Support.IsHp) { throw 'An HP or Hewlett-Packard system is required.' }
    if ($Support.Management.Managed) { throw 'Enterprise-management ownership detected; mutation refused.' }
    if ($Support.CandidateCount -ne 1) { throw 'Exactly one eligible Microsoft 365 Startup-folder shortcut is required.' }
}

function Get-FileSnapshot {
    param([Parameter(Mandatory)][string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    $resolved = Resolve-Shortcut -Path $Path
    $acl = Get-Acl -LiteralPath $Path
    [ordered]@{
        path = $item.FullName
        length = $item.Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        creationTimeUtc = $item.CreationTimeUtc.ToString('o')
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
        attributes = [int]$item.Attributes
        owner = $acl.Owner
        sddl = $acl.Sddl
        targetPath = $resolved.TargetPath
        arguments = $resolved.Arguments
        workingDirectory = $resolved.WorkingDirectory
        iconLocation = $resolved.IconLocation
        description = $resolved.Description
        windowStyle = $resolved.WindowStyle
        targetIdentity = Get-TargetIdentity -Path $resolved.TargetPath
    }
}

function Save-State {
    param($Support)
    if (Test-Path -LiteralPath $StatePath) { throw 'State artifact already exists; capture overwrite refused.' }
    if (Test-Path -LiteralPath $BackupPath) { throw 'Rollback backup already exists; capture overwrite refused.' }
    $candidate = $Support.Candidate
    $snapshot = Get-FileSnapshot -Path $candidate.File.FullName
    Copy-Item -LiteralPath $candidate.File.FullName -Destination $BackupPath
    $state = [ordered]@{
        schemaVersion = 2
        experiment = $experiment
        machine = $env:COMPUTERNAME
        userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        os = $Support.OS
        build = $Support.Build
        manufacturer = $Support.Manufacturer
        model = $Support.Model
        management = $Support.Management
        startupFolder = $Support.StartupFolder
        shortcut = $snapshot
        backup = [ordered]@{
            path = [IO.Path]::GetFullPath($BackupPath)
            sha256 = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash
        }
    }
    $directory = Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $state | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}

function Read-State {
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { throw "State file missing: $StatePath" }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.schemaVersion -ne 2 -or $state.experiment -ne $experiment -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid) {
        throw 'State identity validation failed.'
    }
    $state
}

function Test-TargetIdentity {
    param($Expected)
    $current = Get-TargetIdentity -Path $Expected.Path
    ($current.Sha256 -eq $Expected.Sha256 -and
     $current.SignatureStatus -eq 'Valid' -and
     $current.Publisher -eq $Expected.Publisher -and
     $current.Version -eq $Expected.Version)
}

function Test-Removed {
    if (-not (Test-Path -LiteralPath $StatePath)) { return $false }
    $state = Read-State
    (-not (Test-Path -LiteralPath $state.shortcut.path)) -and (Test-TargetIdentity -Expected $state.shortcut.targetIdentity)
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
        $current.windowStyle -eq $state.shortcut.windowStyle -and
        $current.sddl -eq $state.shortcut.sddl -and
        (Test-TargetIdentity -Expected $state.shortcut.targetIdentity)
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
            $preview = [ordered]@{
                delete = $support.Candidate.File.FullName
                target = $support.Candidate.Shortcut.TargetPath
                targetSha256 = $support.Candidate.TargetIdentity.Sha256
                publisher = $support.Candidate.TargetIdentity.Publisher
                preserveOffice = $true
                preserveProtectedApps = $true
            }
            Write-Event 'dry-run' 'ok' $preview
            $preview
        }
        'Apply' {
            if (Test-Path -LiteralPath $StatePath) {
                $state = Read-State
                if (-not (Test-Path -LiteralPath $state.shortcut.path)) {
                    if (-not (Test-Removed)) { throw 'Applied state verification failed.' }
                    Write-Event 'apply' 'already-applied' $null
                    break
                }
            }
            Assert-Supported $support
            $state = if (Test-Path -LiteralPath $StatePath) { Read-State } else { Save-State $support }
            if ((Get-ManagementSignals).Managed) { throw 'Enterprise-management ownership appeared after capture; mutation refused.' }
            if (-not (Test-Path -LiteralPath $state.backup.path) -or (Get-FileHash -LiteralPath $state.backup.path -Algorithm SHA256).Hash -ne $state.backup.sha256) { throw 'Rollback backup is missing or has drifted.' }
            if ((Get-FileHash -LiteralPath $state.shortcut.path -Algorithm SHA256).Hash -ne $state.shortcut.sha256) { throw 'Shortcut drift detected before application.' }
            if (-not (Test-TargetIdentity -Expected $state.shortcut.targetIdentity)) { throw 'Microsoft 365 executable identity drift detected before application.' }
            if ($PSCmdlet.ShouldProcess($state.shortcut.path,'Delete one captured Microsoft 365 Startup-folder shortcut')) {
                Remove-Item -LiteralPath $state.shortcut.path -Force
                if (-not (Test-Removed)) { throw 'Deletion verification failed.' }
                Write-Event 'apply' 'ok' @{ path = $state.shortcut.path; sha256 = $state.shortcut.sha256 }
            }
        }
        'Verify' {
            $result = Test-Removed
            Write-Event 'verify' $(if($result){'ok'}else{'failed'}) @{ removed = $result }
            if (-not $result) { throw 'Immediate verification failed.' }
            $result
        }
        'VerifyReboot' {
            $result = Test-Removed
            Write-Event 'verify-reboot' $(if($result){'ok'}else{'failed'}) @{ removed = $result }
            if (-not $result) { throw 'Reboot-persistence verification failed.' }
            $result
        }
        'Rollback' {
            $state = Read-State
            if ((Get-ManagementSignals).Managed -ne [bool]$state.management.Managed) { throw 'Management state drift detected; rollback refused.' }
            if (-not (Test-TargetIdentity -Expected $state.shortcut.targetIdentity)) { throw 'Microsoft 365 executable identity drift detected; rollback refused.' }
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
                $acl = New-Object Security.AccessControl.FileSecurity
                $acl.SetSecurityDescriptorSddlForm([string]$state.shortcut.sddl)
                Set-Acl -LiteralPath $state.shortcut.path -AclObject $acl
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

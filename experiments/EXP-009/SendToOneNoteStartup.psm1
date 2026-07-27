Set-StrictMode -Version Latest

$script:ExpectedName = 'Send to OneNote.lnk'

function Write-Exp009Log {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Action,[Parameter(Mandatory)][string]$Result,[Parameter(Mandatory)][object]$Data)
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [pscustomobject]@{ TimestampUtc=[DateTime]::UtcNow.ToString('o'); Experiment='EXP-009'; Action=$Action; Result=$Result; Data=$Data } |
        ConvertTo-Json -Depth 10 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Get-Exp009Support {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $startup = [Environment]::GetFolderPath('Startup')
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match '(?i)^HP|Hewlett' -and -not [string]::IsNullOrWhiteSpace($startup))
        Windows = $os.Caption
        Build = $os.BuildNumber
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        StartupFolder = $startup
    }
}

function Get-Exp009Candidate {
    $support = Get-Exp009Support
    $path = Join-Path $support.StartupFolder $script:ExpectedName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return [pscustomobject]@{ Exists=$false; Path=$path; IdentityMatches=$true; Hash=$null; Length=$null; CreationTimeUtc=$null; LastWriteTimeUtc=$null } }
    $item = Get-Item -LiteralPath $path -Force
    $isReparse = [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
    [pscustomobject]@{
        Exists=$true
        Path=$item.FullName
        IdentityMatches=($item.Name -ceq $script:ExpectedName -and -not $isReparse -and -not $item.PSIsContainer)
        Hash=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
        Length=$item.Length
        CreationTimeUtc=$item.CreationTimeUtc.ToString('o')
        LastWriteTimeUtc=$item.LastWriteTimeUtc.ToString('o')
    }
}

function Invoke-Exp009DryRun {
    $support = Get-Exp009Support
    $candidate = Get-Exp009Candidate
    [pscustomobject]@{ Supported=$support.Supported; Candidate=$candidate; WouldChange=($support.Supported -and $candidate.Exists -and $candidate.IdentityMatches); PreservesOneNote=$true; PreservesProtectedApplications=$true }
}

function Save-Exp009State {
    param([Parameter(Mandatory)][string]$StatePath)
    $support = Get-Exp009Support
    if (-not $support.Supported) { throw 'Unsupported system.' }
    $candidate = Get-Exp009Candidate
    if ($candidate.Exists -and -not $candidate.IdentityMatches) { throw 'Candidate identity mismatch.' }
    $directory = Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $backupPath = Join-Path $directory 'Send to OneNote.lnk.backup'
    if ($candidate.Exists) { Copy-Item -LiteralPath $candidate.Path -Destination $backupPath -Force }
    $payload = [ordered]@{ SchemaVersion=1; Experiment='EXP-009'; CapturedAtUtc=[DateTime]::UtcNow.ToString('o'); Support=$support; Candidate=$candidate; BackupPath=$backupPath }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    [pscustomobject]$payload
}

function Remove-Exp009Shortcut {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$StatePath,[Parameter(Mandatory)][string]$LogPath)
    if (-not (Test-Path -LiteralPath $StatePath)) { Save-Exp009State -StatePath $StatePath | Out-Null }
    $saved = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($saved.Experiment -ne 'EXP-009' -or [int]$saved.SchemaVersion -ne 1) { throw 'State identity mismatch.' }
    $current = Get-Exp009Candidate
    if (-not $current.Exists) { Write-Exp009Log -Path $LogPath -Action 'Apply' -Result 'NoChange' -Data $current; return $current }
    if (-not $current.IdentityMatches -or $current.Hash -ne $saved.Candidate.Hash) { throw 'Candidate identity or hash changed before apply.' }
    if ($PSCmdlet.ShouldProcess($current.Path,'Remove Send to OneNote startup shortcut')) { Remove-Item -LiteralPath $current.Path -Force -ErrorAction Stop }
    $verification = Test-Exp009Applied -StatePath $StatePath
    if (-not $verification.Verified) { throw 'Application verification failed.' }
    Write-Exp009Log -Path $LogPath -Action 'Apply' -Result 'Removed' -Data $verification
    $verification
}

function Test-Exp009Applied {
    param([Parameter(Mandatory)][string]$StatePath)
    $saved = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $current = Get-Exp009Candidate
    [pscustomobject]@{ Verified=(-not $current.Exists); Current=$current; ExpectedPath=$saved.Candidate.Path }
}

function Test-Exp009RebootPersistence {
    param([Parameter(Mandatory)][string]$StatePath)
    Test-Exp009Applied -StatePath $StatePath
}

function Restore-Exp009Shortcut {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$StatePath,[Parameter(Mandatory)][string]$LogPath)
    $saved = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($saved.Experiment -ne 'EXP-009' -or [int]$saved.SchemaVersion -ne 1) { throw 'State identity mismatch.' }
    if (-not $saved.Candidate.Exists) { Write-Exp009Log -Path $LogPath -Action 'Rollback' -Result 'NoOriginalFile' -Data $saved.Candidate; return Test-Exp009Rollback -StatePath $StatePath }
    if (-not (Test-Path -LiteralPath $saved.BackupPath -PathType Leaf)) { throw 'Backup missing.' }
    $backupHash = (Get-FileHash -LiteralPath $saved.BackupPath -Algorithm SHA256).Hash
    if ($backupHash -ne $saved.Candidate.Hash) { throw 'Backup hash mismatch.' }
    if ($PSCmdlet.ShouldProcess($saved.Candidate.Path,'Restore exact Send to OneNote startup shortcut')) { Copy-Item -LiteralPath $saved.BackupPath -Destination $saved.Candidate.Path -Force }
    $verification = Test-Exp009Rollback -StatePath $StatePath
    if (-not $verification.Verified) { throw 'Rollback verification failed.' }
    Write-Exp009Log -Path $LogPath -Action 'Rollback' -Result 'Restored' -Data $verification
    $verification
}

function Test-Exp009Rollback {
    param([Parameter(Mandatory)][string]$StatePath)
    $saved = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $current = Get-Exp009Candidate
    $verified = if ($saved.Candidate.Exists) { $current.Exists -and $current.IdentityMatches -and $current.Hash -eq $saved.Candidate.Hash } else { -not $current.Exists }
    [pscustomobject]@{ Verified=$verified; Current=$current }
}

Export-ModuleMember -Function Get-Exp009Support,Get-Exp009Candidate,Invoke-Exp009DryRun,Save-Exp009State,Remove-Exp009Shortcut,Test-Exp009Applied,Test-Exp009RebootPersistence,Restore-Exp009Shortcut,Test-Exp009Rollback

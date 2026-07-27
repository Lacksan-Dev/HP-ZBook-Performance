Set-StrictMode -Version Latest

$script:ProtectedPatterns = @(
    'omnissa', 'vmware horizon', 'windows app', 'remote desktop', 'mstsc',
    'tailscale', 'securityhealth', 'windows defender', 'credential',
    'accessibility', 'narrator', 'magnify', 'windows update'
)

$script:TargetPatterns = @(
    'teams', 'ms-teams', 'msteams',
    'office', 'microsoft 365', 'officehub', 'officeclicktorun'
)

function Test-StartupTextMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string[]] $Patterns
    )

    $normalized = $Text.ToLowerInvariant()
    foreach ($pattern in $Patterns) {
        if ($normalized.Contains($pattern.ToLowerInvariant())) { return $true }
    }
    return $false
}

function Test-ProtectedStartupRegistration {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Identity)
    return Test-StartupTextMatch -Text $Identity -Patterns $script:ProtectedPatterns
}

function Test-TargetStartupRegistration {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Identity)

    if (Test-ProtectedStartupRegistration -Identity $Identity) { return $false }
    return Test-StartupTextMatch -Text $Identity -Patterns $script:TargetPatterns
}

function Get-StartupRegistrationInventory {
    [CmdletBinding()]
    param()

    $items = [System.Collections.Generic.List[object]]::new()
    $registryPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
    )

    foreach ($path in $registryPaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $properties = Get-ItemProperty -LiteralPath $path
        foreach ($property in $properties.PSObject.Properties) {
            if ($property.Name -like 'PS*') { continue }
            $identity = "$($property.Name) $($property.Value)"
            $items.Add([pscustomobject]@{
                Type = 'Registry'
                Location = $path
                Name = $property.Name
                Value = [string]$property.Value
                Identity = $identity
                Protected = Test-ProtectedStartupRegistration -Identity $identity
                Target = Test-TargetStartupRegistration -Identity $identity
            })
        }
    }

    $startupFolders = @(
        [Environment]::GetFolderPath('Startup'),
        [Environment]::GetFolderPath('CommonStartup')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($folder in $startupFolders) {
        Get-ChildItem -LiteralPath $folder -File -Force | ForEach-Object {
            $identity = "$($_.Name) $($_.FullName)"
            $items.Add([pscustomobject]@{
                Type = 'StartupFile'
                Location = $folder
                Name = $_.Name
                Value = $_.FullName
                Identity = $identity
                Protected = Test-ProtectedStartupRegistration -Identity $identity
                Target = Test-TargetStartupRegistration -Identity $identity
            })
        }
    }

    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        Get-ScheduledTask | Where-Object { $_.Triggers.CimClass.CimClassName -contains 'MSFT_TaskLogonTrigger' } | ForEach-Object {
            $actionText = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' '
            $identity = "$($_.TaskPath)$($_.TaskName) $actionText"
            $items.Add([pscustomobject]@{
                Type = 'ScheduledTask'
                Location = $_.TaskPath
                Name = $_.TaskName
                Value = $actionText
                Identity = $identity
                Protected = Test-ProtectedStartupRegistration -Identity $identity
                Target = Test-TargetStartupRegistration -Identity $identity
                Enabled = $_.State -ne 'Disabled'
            })
        }
    }

    return $items
}

function Write-StartupCleanupLog {
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
        Action = $Action
        Data = $Data
    } | ConvertTo-Json -Depth 8 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Save-StartupRegistrationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]] $Inventory,
        [Parameter(Mandatory)] [string] $StatePath
    )

    $stateDirectory = Split-Path -Parent $StatePath
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
    $backupDirectory = Join-Path $stateDirectory 'files'
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null

    $records = foreach ($item in $Inventory | Where-Object Target) {
        $record = [ordered]@{
            Type = $item.Type
            Location = $item.Location
            Name = $item.Name
            Value = $item.Value
            Enabled = if ($item.PSObject.Properties.Name -contains 'Enabled') { $item.Enabled } else { $null }
            BackupPath = $null
        }
        if ($item.Type -eq 'StartupFile' -and (Test-Path -LiteralPath $item.Value)) {
            $safeName = '{0}-{1}' -f ([guid]::NewGuid().ToString('N')), $item.Name
            $backupPath = Join-Path $backupDirectory $safeName
            Copy-Item -LiteralPath $item.Value -Destination $backupPath -Force
            $record.BackupPath = $backupPath
        }
        [pscustomobject]$record
    }

    $payload = [ordered]@{
        SchemaVersion = 1
        CapturedAtUtc = [DateTime]::UtcNow.ToString('o')
        ComputerName = $env:COMPUTERNAME
        Records = @($records)
    }
    $payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    return $payload
}

function Invoke-StartupRegistrationCleanup {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('DryRun','Apply','Verify','Rollback')]
        [string] $Mode = 'DryRun',
        [Parameter(Mandatory)] [string] $StatePath,
        [Parameter(Mandatory)] [string] $LogPath
    )

    if ($Mode -eq 'Rollback') {
        if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
        $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
        foreach ($record in $state.Records) {
            switch ($record.Type) {
                'Registry' {
                    New-Item -Path $record.Location -Force | Out-Null
                    New-ItemProperty -LiteralPath $record.Location -Name $record.Name -Value $record.Value -PropertyType String -Force | Out-Null
                }
                'StartupFile' {
                    if (-not (Test-Path -LiteralPath $record.BackupPath)) { throw "Backup missing: $($record.BackupPath)" }
                    Copy-Item -LiteralPath $record.BackupPath -Destination $record.Value -Force
                }
                'ScheduledTask' {
                    if ($record.Enabled) { Enable-ScheduledTask -TaskPath $record.Location -TaskName $record.Name | Out-Null }
                    else { Disable-ScheduledTask -TaskPath $record.Location -TaskName $record.Name | Out-Null }
                }
            }
            Write-StartupCleanupLog -Path $LogPath -Action 'Rollback' -Data $record
        }
        return
    }

    $inventory = @(Get-StartupRegistrationInventory)
    $targets = @($inventory | Where-Object { $_.Target -and -not $_.Protected })

    if ($Mode -eq 'DryRun') {
        Write-StartupCleanupLog -Path $LogPath -Action 'DryRun' -Data $targets
        return $targets
    }

    if ($Mode -eq 'Verify') {
        $remaining = @($targets | Where-Object {
            switch ($_.Type) {
                'Registry' { Test-Path -LiteralPath $_.Location -and $null -ne (Get-ItemProperty -LiteralPath $_.Location -Name $_.Name -ErrorAction SilentlyContinue) }
                'StartupFile' { Test-Path -LiteralPath $_.Value }
                'ScheduledTask' { $_.Enabled }
            }
        })
        Write-StartupCleanupLog -Path $LogPath -Action 'Verify' -Data $remaining
        return [pscustomobject]@{ Success = ($remaining.Count -eq 0); Remaining = $remaining }
    }

    Save-StartupRegistrationState -Inventory $inventory -StatePath $StatePath | Out-Null
    foreach ($item in $targets) {
        if (-not $PSCmdlet.ShouldProcess($item.Identity, 'Remove or disable startup registration')) { continue }
        switch ($item.Type) {
            'Registry' { Remove-ItemProperty -LiteralPath $item.Location -Name $item.Name -ErrorAction Stop }
            'StartupFile' { Remove-Item -LiteralPath $item.Value -Force -ErrorAction Stop }
            'ScheduledTask' { Disable-ScheduledTask -TaskPath $item.Location -TaskName $item.Name -ErrorAction Stop | Out-Null }
        }
        Write-StartupCleanupLog -Path $LogPath -Action 'Apply' -Data $item
    }
}

Export-ModuleMember -Function @(
    'Test-ProtectedStartupRegistration',
    'Test-TargetStartupRegistration',
    'Get-StartupRegistrationInventory',
    'Save-StartupRegistrationState',
    'Invoke-StartupRegistrationCleanup'
)

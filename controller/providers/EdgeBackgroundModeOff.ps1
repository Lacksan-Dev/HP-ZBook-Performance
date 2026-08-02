[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$experiment='EXP-071'
$provider='edge-background-mode-off'
$profile='EdgeBackgroundModeOff'
$policyPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$mandatoryPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$valueName='BackgroundModeEnabled'
$related=@('StartupBoostEnabled')
$guidPattern='(?i)^\{?[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\}?$'

function Write-Log {
    param([string]$Event,[string]$Result,[object]$Data)
    if ([string]::IsNullOrWhiteSpace($LogPath)) { return }
    $parent=Split-Path -Parent $LogPath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [ordered]@{
        schemaVersion=2
        timestampUtc=(Get-Date).ToUniversalTime().ToString('o')
        experiment=$experiment
        provider=$provider
        action=$Action
        event=$Event
        result=$Result
        machine=$env:COMPUTERNAME
        userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        data=$Data
    } | ConvertTo-Json -Compress -Depth 20 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Test-Elevated {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Get-RegistryState {
    param([string]$Path,[string]$Name)
    if (!(Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{KeyExists=$false;ValueExists=$false;Kind=$null;Data=$null}
    }
    $key=Get-Item -LiteralPath $Path
    $exists=$key.GetValueNames() -contains $Name
    if (!$exists) { return [pscustomobject]@{KeyExists=$true;ValueExists=$false;Kind=$null;Data=$null} }
    [pscustomobject]@{
        KeyExists=$true
        ValueExists=$true
        Kind=$key.GetValueKind($Name).ToString()
        Data=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
}

function ConvertTo-CanonicalGuid {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch $guidPattern) { return $null }
    $Value.Trim('{}').ToLowerInvariant()
}

function Get-GuidChildren {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return @() }
    @(
        Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue |
            ForEach-Object { ConvertTo-CanonicalGuid $_.PSChildName } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )
}

function Get-EnterpriseMgmtGuids {
    $guids=@()
    foreach ($task in @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*' })) {
        $match=[regex]::Match("$($task.TaskPath)$($task.TaskName)",'(?i)\\Microsoft\\Windows\\EnterpriseMgmt\\(?<g>\{?[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\}?)\\')
        if ($match.Success) {
            $value=ConvertTo-CanonicalGuid $match.Groups['g'].Value
            if ($value) { $guids += $value }
        }
    }
    @($guids | Sort-Object -Unique)
}

function Get-ManagementState {
    $computer=Get-CimInstance Win32_ComputerSystem
    $enrollmentGuids=@(Get-GuidChildren 'HKLM:\SOFTWARE\Microsoft\Enrollments')
    $omadmGuids=@(Get-GuidChildren 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts')
    $taskGuids=@(Get-EnterpriseMgmtGuids)
    $activeMdmGuids=@($enrollmentGuids | Where-Object { $_ -in $omadmGuids -or $_ -in $taskGuids } | Sort-Object -Unique)
    $configMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
    $signals=[ordered]@{
        DomainJoined=[bool]$computer.PartOfDomain
        EnrollmentGuidCount=$enrollmentGuids.Count
        OmadmAccountGuidCount=$omadmGuids.Count
        EnterpriseMgmtGuidCount=$taskGuids.Count
        ActiveCorrelatedMdmGuidCount=$activeMdmGuids.Count
        PolicyManagerPresent=(Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device')
        ConfigMgr=$configMgr
    }
    [pscustomobject]@{
        Managed=($signals.DomainJoined -or $signals.ConfigMgr -or $signals.ActiveCorrelatedMdmGuidCount -gt 0)
        Signals=[pscustomobject]$signals
        ActiveMdmGuids=$activeMdmGuids
    }
}

function Get-EdgeIdentity {
    $roots=@(
        [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
        [Environment]::GetEnvironmentVariable('ProgramFiles')
    ) | Where-Object { $_ } | Select-Object -Unique
    $paths=@($roots | ForEach-Object { Join-Path $_ 'Microsoft\Edge\Application\msedge.exe' } | Where-Object { Test-Path -LiteralPath $_ })
    $items=@($paths | ForEach-Object {
        $item=Get-Item -LiteralPath $_
        $sig=Get-AuthenticodeSignature -LiteralPath $_
        $publisher=if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { $null }
        [pscustomobject]@{
            Path=$item.FullName
            Version=$item.VersionInfo.FileVersion
            Major=[int]($item.VersionInfo.FileVersion.Split('.')[0])
            Sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash
            SignatureStatus=$sig.Status.ToString()
            Publisher=$publisher
            Thumbprint=if ($sig.SignerCertificate) { $sig.SignerCertificate.Thumbprint } else { $null }
            ValidPublisher=($sig.Status -eq 'Valid' -and $publisher -match '(?i)Microsoft Corporation')
        }
    })
    if ($items.Count -ne 1) { return $null }
    $items[0]
}

function Get-StartupFolderState {
    $folders=@(
        [Environment]::GetFolderPath('Startup'),
        [Environment]::GetFolderPath('CommonStartup')
    ) | Where-Object { $_ } | Select-Object -Unique
    $shell=New-Object -ComObject WScript.Shell
    $entries=@()
    foreach ($folder in $folders) {
        if (!(Test-Path -LiteralPath $folder)) { continue }
        foreach ($item in Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue) {
            $target=$null
            if ($item.Extension -eq '.lnk') { try { $target=$shell.CreateShortcut($item.FullName).TargetPath } catch {} }
            $isEdge=[bool]($item.Name -match '(?i)edge|msedge' -or $target -match '(?i)\\msedge\.exe$')
            $entries += [pscustomobject]@{Folder=$folder;Name=$item.Name;FullName=$item.FullName;Target=$target;Edge=$isEdge}
        }
    }
    [pscustomobject]@{
        Entries=@($entries)
        EdgeEntries=@($entries | Where-Object Edge)
        EdgeEntryCount=@($entries | Where-Object Edge).Count
    }
}

function Get-ProtectedSnapshot {
    $rows=@()
    foreach ($name in @('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale','edgeupdate','edgeupdatem')) {
        $service=Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
        if ($service) {
            $rows += [pscustomobject]@{Name=$service.Name;StartMode=$service.StartMode;PathName=$service.PathName}
        }
    }
    [pscustomobject]@{Services=@($rows | Sort-Object Name)}
}

function Get-PolicyBundle {
    $bundle=[ordered]@{
        MandatoryMain=Get-RegistryState $mandatoryPath $valueName
        RecommendedMain=Get-RegistryState $policyPath $valueName
        MandatoryRelated=[ordered]@{}
        RecommendedRelated=[ordered]@{}
    }
    foreach ($name in $related) {
        $bundle.MandatoryRelated[$name]=Get-RegistryState $mandatoryPath $name
        $bundle.RecommendedRelated[$name]=Get-RegistryState $policyPath $name
    }
    [pscustomobject]$bundle
}

function Get-SupportState {
    $os=Get-CimInstance Win32_OperatingSystem
    $computer=Get-CimInstance Win32_ComputerSystem
    $management=Get-ManagementState
    $edge=Get-EdgeIdentity
    $policies=Get-PolicyBundle
    $startup=Get-StartupFolderState
    [pscustomobject]@{
        Supported=(
            $os.Caption -match 'Windows 11' -and
            $computer.Manufacturer -match '(?i)^HP$|Hewlett-Packard' -and
            (Test-Elevated) -and
            $edge -and $edge.Major -ge 77 -and $edge.ValidPublisher -and
            !$management.Managed -and
            !$policies.MandatoryMain.ValueExists -and
            !$policies.RecommendedMain.ValueExists -and
            $startup.EdgeEntryCount -eq 0
        )
        OS=$os.Caption
        Build=$os.BuildNumber
        Manufacturer=$computer.Manufacturer
        Model=$computer.Model
        Elevated=Test-Elevated
        Managed=$management.Managed
        ManagementSignals=$management.Signals
        Edge=$edge
        Policies=$policies
        StartupFolders=$startup
    }
}

function Assert-Supported {
    param($Support)
    if (!$Support.Supported) {
        throw 'Unsupported, externally managed, unsigned, ambiguous, policy-owned, or Startup-folder Edge state.'
    }
}

function Compare-State {
    param([object]$A,[object]$B)
    (($A | ConvertTo-Json -Compress -Depth 20) -eq ($B | ConvertTo-Json -Compress -Depth 20))
}

function Save-State {
    param($Support)
    Assert-Supported $Support
    if ([string]::IsNullOrWhiteSpace($StatePath)) { throw 'StatePath is required.' }
    if (Test-Path -LiteralPath $StatePath) { throw 'State overwrite refused.' }
    $state=[ordered]@{
        schemaVersion=2
        experiment=$experiment
        provider=$provider
        capturedUtc=(Get-Date).ToUniversalTime().ToString('o')
        capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        machine=$env:COMPUTERNAME
        userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        policyPath=$policyPath
        valueName=$valueName
        original=$Support.Policies.RecommendedMain
        policies=$Support.Policies
        edge=$Support.Edge
        management=$Support.ManagementSignals
        startupFolderEdgeEntries=$Support.StartupFolders.EdgeEntryCount
        protectedScope=Get-ProtectedSnapshot
    }
    $parent=Split-Path -Parent $StatePath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    [pscustomobject]$state
}

function Read-State {
    if ([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)) { throw 'State artifact is missing.' }
    $state=Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.schemaVersion -ne 2 -or $state.experiment -ne $experiment -or $state.provider -ne $provider -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid) {
        throw 'State identity validation failed.'
    }
    $state
}

function Assert-DriftFree {
    param($State)
    $edge=Get-EdgeIdentity
    if (!$edge -or $edge.Sha256 -ne [string]$State.edge.Sha256 -or $edge.Thumbprint -ne [string]$State.edge.Thumbprint -or $edge.Version -ne [string]$State.edge.Version) {
        throw 'Edge identity drift detected.'
    }
    $management=Get-ManagementState
    if ($management.Managed) { throw 'External management ownership appeared.' }
    $policies=Get-PolicyBundle
    if (!(Compare-State $policies.MandatoryRelated $State.policies.MandatoryRelated) -or
        !(Compare-State $policies.RecommendedRelated $State.policies.RecommendedRelated) -or
        !(Compare-State $policies.MandatoryMain $State.policies.MandatoryMain)) {
        throw 'Related Edge policy drift detected.'
    }
    if ((Get-StartupFolderState).EdgeEntryCount -ne 0) { throw 'Edge Startup-folder drift detected.' }
    if (!(Compare-State (Get-ProtectedSnapshot) $State.protectedScope)) { throw 'Protected service configuration drift detected.' }
    $edge
}

function Test-Applied {
    $state=Get-RegistryState $policyPath $valueName
    $state.ValueExists -and $state.Kind -eq 'DWord' -and [int]$state.Data -eq 0
}

try {
    $support=Get-SupportState
    Write-Log 'support-detection' $(if ($support.Supported) {'pass'} else {'unsupported'}) $support
    switch ($Action) {
        'Check' {
            [pscustomobject]@{Support=$support;Profile=$profile}
        }
        'Capture' {
            $state=Save-State $support
            Write-Log 'capture' 'pass' @{path=$policyPath;name=$valueName;edge=$state.edge.Version;management=$state.management}
            $state
        }
        'DryRun' {
            Assert-Supported $support
            $result=[pscustomobject]@{
                Profile=$profile
                WouldChange=$true
                MutationCount=1
                Path=$policyPath
                Name=$valueName
                Type='DWord'
                Value=0
                BrowserRestartRequired=$false
                RebootPersistenceCheckRequired=$true
                Rollback='Restore exact captured registry state or remove only the experiment-created value and empty key.'
            }
            Write-Log 'dry-run' 'pass' $result
            $result
        }
        'Apply' {
            $state=if (Test-Path -LiteralPath $StatePath) { Read-State } else { Save-State $support }
            Assert-DriftFree $state | Out-Null
            if (Test-Applied) {
                Write-Log 'apply' 'idempotent' @{mutationCount=0}
                return [pscustomobject]@{Applied=$true;MutationCount=0}
            }
            Assert-Supported $support
            if ($WhatIfPreference) {
                Write-Log 'apply' 'whatif' @{mutationCount=0}
                return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0}
            }
            if ($PSCmdlet.ShouldProcess("$policyPath::$valueName",'Disable recommended Microsoft Edge background mode for demand-launch comparison')) {
                if (!(Test-Path -LiteralPath $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
                New-ItemProperty -LiteralPath $policyPath -Name $valueName -PropertyType DWord -Value 0 -Force | Out-Null
            }
            if (!(Test-Applied)) { throw 'Apply verification failed.' }
            Write-Log 'apply' 'pass' @{mutationCount=1;dynamicPolicyRefresh=$true}
            [pscustomobject]@{Applied=$true;MutationCount=1}
        }
        'Verify' {
            $state=Read-State
            Assert-DriftFree $state | Out-Null
            if (!(Test-Applied)) { throw 'Immediate verification failed.' }
            Write-Log 'verify' 'pass' @{value=0;startupFolderEdgeEntries=0}
            $true
        }
        'VerifyReboot' {
            $state=Read-State
            $boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
            if ($boot -le [datetime]$state.capturedBootTime) { throw 'A later boot is required.' }
            Assert-DriftFree $state | Out-Null
            if (!(Test-Applied)) { throw 'Reboot persistence failed.' }
            Write-Log 'verify-reboot' 'pass' @{bootTime=$boot.ToString('o');value=0;startupFolderEdgeEntries=0}
            $true
        }
        'Rollback' {
            $state=Read-State
            Assert-DriftFree $state | Out-Null
            $current=Get-RegistryState $policyPath $valueName
            if (!$current.ValueExists) {
                Write-Log 'rollback' 'idempotent' @{mutationCount=0}
                return [pscustomobject]@{RolledBack=$true;MutationCount=0}
            }
            if ($current.Kind -ne 'DWord' -or [int]$current.Data -ne 0) { throw 'Policy drift detected; rollback refused.' }
            if ($WhatIfPreference) {
                Write-Log 'rollback' 'whatif' @{mutationCount=0}
                return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0}
            }
            if ($PSCmdlet.ShouldProcess("$policyPath::$valueName",'Restore exact captured Edge background-mode policy state')) {
                if ($state.original.ValueExists) {
                    New-ItemProperty -LiteralPath $policyPath -Name $valueName -PropertyType $state.original.Kind -Value $state.original.Data -Force | Out-Null
                } else {
                    Remove-ItemProperty -LiteralPath $policyPath -Name $valueName
                    if (!$state.original.KeyExists -and (Test-Path -LiteralPath $policyPath)) {
                        if (@((Get-Item -LiteralPath $policyPath).GetValueNames()).Count -eq 0 -and @(Get-ChildItem -LiteralPath $policyPath).Count -eq 0) {
                            Remove-Item -LiteralPath $policyPath
                        }
                    }
                }
            }
            $after=Get-RegistryState $policyPath $valueName
            if (!(Compare-State $after $state.original)) { throw 'Exact rollback verification failed.' }
            Write-Log 'rollback' 'pass' @{mutationCount=1;restoredExactOriginal=$true}
            [pscustomobject]@{RolledBack=$true;MutationCount=1}
        }
    }
} catch {
    Write-Log 'failure' 'fail' @{stage=$Action;message=$_.Exception.Message}
    throw
}

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath,
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$experiment='EXP-121'
$provider='logi-bolt-startup-folder'
$profile='LogiBoltStartupFolder'
$protected='(?i)omnissa|vmware horizon|windows app|remote desktop|mstsc|tailscale|defender|securityhealth|firewall|bitlocker|credential|windows update|recovery|intune|sccm|configmgr|mdm'
$unsafe='(?i)update|updater|servic|repair|install|setup|bootstrap|firmware|driver|dfu|pair|pairing|security|recovery|credential|accessibility|enterprise|manage'
$boltLeaf='(?i)^(LogiBolt|logi-bolt)\.exe$'

function Write-Log([string]$Event,[string]$Result,[object]$Data) {
    if ([string]::IsNullOrWhiteSpace($LogPath)) { return }
    $parent=Split-Path -Parent $LogPath
    if ($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [ordered]@{
        schemaVersion=1
        timestampUtc=(Get-Date).ToUniversalTime().ToString('o')
        experiment=$experiment
        provider=$provider
        action=$Action
        event=$Event
        result=$Result
        machine=$env:COMPUTERNAME
        userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        data=$Data
    } | ConvertTo-Json -Compress -Depth 24 | Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-HashBytes([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ($sha.ComputeHash($Bytes) | ForEach-Object {$_.ToString('x2')}) -join '' }
    finally { $sha.Dispose() }
}
function Get-HashText([string]$Text) { Get-HashBytes ([Text.Encoding]::UTF8.GetBytes([string]$Text)) }
function Test-Elevated {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ManagementState {
    $computer=Get-CimInstance Win32_ComputerSystem
    $signals=[ordered]@{
        DomainJoined=[bool]$computer.PartOfDomain
        MdmEnrollments=@(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Enrollments' -ErrorAction SilentlyContinue).Count
        PolicyManager=Test-Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device'
        ConfigMgr=[bool](Get-Service CcmExec -ErrorAction SilentlyContinue)
    }
    [pscustomobject]@{Managed=($signals.DomainJoined -or $signals.MdmEnrollments -gt 0 -or $signals.PolicyManager -or $signals.ConfigMgr);Signals=$signals}
}

function Get-SupportState {
    $os=Get-CimInstance Win32_OperatingSystem
    $computer=Get-CimInstance Win32_ComputerSystem
    $management=Get-ManagementState
    [pscustomobject]@{
        Supported=($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match '(?i)^HP$|Hewlett-Packard' -and (Test-Elevated))
        Elevated=Test-Elevated
        OS=$os.Caption
        Build=$os.BuildNumber
        Manufacturer=$computer.Manufacturer
        Model=$computer.Model
        Managed=$management.Managed
        ManagementSignals=$management.Signals
    }
}

function Get-ProtectedSnapshot {
    $services=foreach($name in 'WinDefend','mpssvc','wuauserv','UsoSvc','BITS','Tailscale') {
        if ($service=Get-Service $name -ErrorAction SilentlyContinue) {
            [ordered]@{Name=$service.Name;Status=$service.Status.ToString();StartType=$service.StartType.ToString()}
        }
    }
    $json=([ordered]@{Services=@($services)} | ConvertTo-Json -Compress -Depth 8)
    [pscustomobject]@{Hash=Get-HashText $json;Snapshot=$json}
}

function Get-BoltDeviceSnapshot {
    $items=@(Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object {
        "$($_.FriendlyName) $($_.Manufacturer)" -match '(?i)logitech|logi'
    } | Sort-Object Class,FriendlyName,Status | ForEach-Object {
        "$($_.Class)|$($_.FriendlyName)|$($_.Status)"
    })
    $json=$items | ConvertTo-Json -Compress
    [pscustomobject]@{Count=$items.Count;Hash=Get-HashText ([string]$json)}
}

function Resolve-Shortcut([string]$Path) {
    $shell=New-Object -ComObject WScript.Shell
    try {
        $shortcut=$shell.CreateShortcut($Path)
        [pscustomobject]@{
            TargetPath=[string]$shortcut.TargetPath
            Arguments=[string]$shortcut.Arguments
            WorkingDirectory=[string]$shortcut.WorkingDirectory
            IconLocation=[string]$shortcut.IconLocation
            Description=[string]$shortcut.Description
            WindowStyle=$shortcut.WindowStyle
            AppUserModelId=$null
        }
    } finally { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) }
}

function Get-FileIdentity([string]$Path) {
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $file=Get-Item -LiteralPath $Path
    $signature=Get-AuthenticodeSignature -LiteralPath $Path
    $publisher=if($signature.SignerCertificate){$signature.SignerCertificate.Subject}else{$null}
    [pscustomobject]@{
        Path=$file.FullName
        Sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        FileVersion=$file.VersionInfo.FileVersion
        ProductName=$file.VersionInfo.ProductName
        CompanyName=$file.VersionInfo.CompanyName
        SignatureStatus=$signature.Status.ToString()
        Publisher=$publisher
        Thumbprint=if($signature.SignerCertificate){$signature.SignerCertificate.Thumbprint}else{$null}
        ValidPublisher=($signature.Status -eq 'Valid' -and $publisher -match '(?i)Logitech|Logi')
    }
}

function Get-StartupFolders {
    $folders=@([pscustomobject]@{Id='CurrentUser';Path=[Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)})
    $common=[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartup)
    if ($common) { $folders += [pscustomobject]@{Id='AllUsers';Path=$common} }
    @($folders | Where-Object {$_.Path})
}

function Test-BoltIdentity($Resolved,$Identity) {
    $leaf=[IO.Path]::GetFileName([string]$Resolved.TargetPath)
    if ($leaf -notmatch $boltLeaf) { return $false }
    $joined="$leaf $($Identity.ProductName) $($Identity.CompanyName) $($Identity.Publisher) $($Resolved.Arguments) $($Resolved.TargetPath)"
    if ($joined -match $unsafe -or $joined -match $protected) { return $false }
    if ($joined -notmatch '(?i)logi\s*bolt|logibolt|logi-bolt') { return $false }
    if ($Identity.CompanyName -notmatch '(?i)Logitech|Logi') { return $false }
    return $true
}

function Get-RelatedBoltStartupState([string]$ExcludePath) {
    $items=@()
    foreach($key in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce','HKLM:\Software\Microsoft\Windows\CurrentVersion\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce') {
        if(Test-Path $key) {
            $property=Get-ItemProperty $key -ErrorAction SilentlyContinue
            foreach($value in @($property.PSObject.Properties | Where-Object {$_.Name -notmatch '^PS'})) {
                if("$($value.Name) $($value.Value)" -match '(?i)logi\s*bolt|logibolt|logi-bolt') {
                    $items += "registry|$key|$(Get-HashText $value.Name)|$(Get-HashText ([string]$value.Value))"
                }
            }
        }
    }
    foreach($folder in Get-StartupFolders) {
        if(!(Test-Path -LiteralPath $folder.Path)) { continue }
        foreach($file in Get-ChildItem -LiteralPath $folder.Path -File -Filter '*.lnk' -ErrorAction SilentlyContinue) {
            if($ExcludePath -and [IO.Path]::GetFullPath($file.FullName) -eq [IO.Path]::GetFullPath($ExcludePath)) { continue }
            try {
                $resolved=Resolve-Shortcut $file.FullName
                if("$($file.Name) $($resolved.TargetPath) $($resolved.Arguments)" -match '(?i)logi\s*bolt|logibolt|logi-bolt') {
                    $items += "startup|$($folder.Id)|$(Get-HashText $file.Name)|$(Get-HashBytes ([IO.File]::ReadAllBytes($file.FullName)))"
                }
            } catch {}
        }
    }
    foreach($task in Get-ScheduledTask -ErrorAction SilentlyContinue) {
        $actions=@($task.Actions | ForEach-Object {"$($_.Execute) $($_.Arguments)"})
        if(($actions -join ' ') -match '(?i)logi\s*bolt|logibolt|logi-bolt') {
            $items += "task|$(Get-HashText ($task.TaskPath+$task.TaskName))|$(Get-HashText ($actions -join '|'))"
        }
    }
    $normalized=@($items | Sort-Object)
    $json=$normalized | ConvertTo-Json -Compress
    [pscustomobject]@{Count=$normalized.Count;Hash=Get-HashText ([string]$json);Items=$normalized}
}

function Get-Candidates {
    $result=@()
    foreach($folder in Get-StartupFolders) {
        if(!(Test-Path -LiteralPath $folder.Path -PathType Container)) { continue }
        foreach($file in Get-ChildItem -LiteralPath $folder.Path -File -Filter '*.lnk' -ErrorAction SilentlyContinue) {
            $resolved=Resolve-Shortcut $file.FullName
            if(!$resolved.TargetPath) { continue }
            $combined="$($file.Name) $($resolved.TargetPath) $($resolved.Arguments)"
            if($combined -match $protected -or $combined -match $unsafe) { continue }
            $identity=Get-FileIdentity $resolved.TargetPath
            if(!$identity -or !$identity.ValidPublisher -or !(Test-BoltIdentity $resolved $identity)) { continue }
            $bytes=[IO.File]::ReadAllBytes($file.FullName)
            $acl=Get-Acl -LiteralPath $file.FullName
            $result += [pscustomobject]@{
                KnownFolder=$folder.Id
                KnownFolderPath=[IO.Path]::GetFullPath($folder.Path)
                Path=[IO.Path]::GetFullPath($file.FullName)
                Name=$file.Name
                Extension=$file.Extension
                BytesBase64=[Convert]::ToBase64String($bytes)
                Sha256=Get-HashBytes $bytes
                CreationTimeUtc=$file.CreationTimeUtc.ToString('o')
                LastWriteTimeUtc=$file.LastWriteTimeUtc.ToString('o')
                Attributes=[int]$file.Attributes
                Owner=$acl.Owner
                Sddl=$acl.Sddl
                Shortcut=$resolved
                Target=$identity
                Product=[ordered]@{Name=$identity.ProductName;Version=$identity.FileVersion;Company=$identity.CompanyName}
            }
        }
    }
    @($result)
}

function Assert-Eligible($Support,[object[]]$Candidates) {
    if(!$Support.Supported) { throw 'Elevated HP Windows 11 is required.' }
    if($Support.Managed) { throw 'Enterprise-management ownership detected.' }
    if($Candidates.Count -ne 1) { throw "Exactly one eligible Logi Bolt Startup-folder registration is required; found $($Candidates.Count)." }
}

function Save-State($Support,[object[]]$Candidates) {
    Assert-Eligible $Support $Candidates
    if([string]::IsNullOrWhiteSpace($StatePath)) { throw 'StatePath is required.' }
    if(Test-Path -LiteralPath $StatePath) { throw 'State overwrite refused.' }
    $protectedState=Get-ProtectedSnapshot
    $devices=Get-BoltDeviceSnapshot
    $related=Get-RelatedBoltStartupState $Candidates[0].Path
    $state=[ordered]@{
        schemaVersion=1
        experiment=$experiment
        provider=$provider
        capturedUtc=(Get-Date).ToUniversalTime().ToString('o')
        capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        machine=$env:COMPUTERNAME
        userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        support=$Support
        protectedScopeHash=$protectedState.Hash
        relatedBoltStartupHash=$related.Hash
        relatedBoltStartupCount=$related.Count
        boltDeviceHash=$devices.Hash
        boltDeviceCount=$devices.Count
        registration=$Candidates[0]
    }
    $parent=Split-Path -Parent $StatePath
    if($parent -and !(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $state | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}

function Read-State {
    if([string]::IsNullOrWhiteSpace($StatePath) -or !(Test-Path -LiteralPath $StatePath)) { throw 'State artifact is missing.' }
    $state=Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if($state.schemaVersion -ne 1 -or $state.experiment -ne $experiment -or $state.provider -ne $provider -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid) {
        throw 'State identity validation failed.'
    }
    $state
}

function Assert-TargetUnchanged($State) {
    $identity=Get-FileIdentity ([string]$State.registration.Target.Path)
    if(!$identity -or !$identity.ValidPublisher -or $identity.Sha256 -ne [string]$State.registration.Target.Sha256 -or $identity.FileVersion -ne [string]$State.registration.Target.FileVersion -or $identity.Thumbprint -ne [string]$State.registration.Target.Thumbprint) {
        throw 'Logi Bolt target identity drift detected.'
    }
    if(!(Test-BoltIdentity $State.registration.Shortcut $identity)) { throw 'Logi Bolt target eligibility drift detected.' }
}

function Assert-Invariants($State) {
    $support=Get-SupportState
    if($support.Managed) { throw 'Enterprise-management ownership appeared.' }
    if((Get-ProtectedSnapshot).Hash -ne [string]$State.protectedScopeHash) { throw 'Protected-scope drift detected.' }
    $devices=Get-BoltDeviceSnapshot
    if($devices.Hash -ne [string]$State.boltDeviceHash -or $devices.Count -ne [int]$State.boltDeviceCount) { throw 'Logitech device-state drift detected.' }
    $related=Get-RelatedBoltStartupState ([string]$State.registration.Path)
    if($related.Hash -ne [string]$State.relatedBoltStartupHash -or $related.Count -ne [int]$State.relatedBoltStartupCount) { throw 'Related Logi Bolt startup state drift detected.' }
    $folders=Get-StartupFolders
    $folder=@($folders | Where-Object {$_.Id -eq [string]$State.registration.KnownFolder})
    if($folder.Count -ne 1 -or [IO.Path]::GetFullPath($folder[0].Path) -ne [string]$State.registration.KnownFolderPath) { throw 'Known-folder path drift detected.' }
    Assert-TargetUnchanged $State
}

function Test-Removed($State) { !(Test-Path -LiteralPath ([string]$State.registration.Path)) }
function Test-Restored($State) {
    $path=[string]$State.registration.Path
    if(!(Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    $file=Get-Item -LiteralPath $path -Force
    if((Get-HashBytes ([IO.File]::ReadAllBytes($path))) -ne [string]$State.registration.Sha256) { return $false }
    $acl=Get-Acl -LiteralPath $path
    $resolved=Resolve-Shortcut $path
    return ($file.CreationTimeUtc.ToString('o') -eq [string]$State.registration.CreationTimeUtc -and
        $file.LastWriteTimeUtc.ToString('o') -eq [string]$State.registration.LastWriteTimeUtc -and
        [int]$file.Attributes -eq [int]$State.registration.Attributes -and
        $acl.Sddl -eq [string]$State.registration.Sddl -and
        $resolved.TargetPath -eq [string]$State.registration.Shortcut.TargetPath -and
        $resolved.Arguments -eq [string]$State.registration.Shortcut.Arguments -and
        $resolved.WorkingDirectory -eq [string]$State.registration.Shortcut.WorkingDirectory -and
        $resolved.IconLocation -eq [string]$State.registration.Shortcut.IconLocation -and
        $resolved.Description -eq [string]$State.registration.Shortcut.Description -and
        [int]$resolved.WindowStyle -eq [int]$State.registration.Shortcut.WindowStyle)
}

try {
    $support=Get-SupportState
    Write-Log 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) $support
    switch($Action) {
        'Check' {
            $candidates=Get-Candidates
            Write-Log 'startup-folder-inventory' 'pass' @{count=$candidates.Count;registrationHashes=@($candidates.Sha256);targetHashes=@($candidates.Target.Sha256)}
            [pscustomobject]@{Support=$support;Candidates=$candidates;Profile=$profile}
        }
        'Capture' {
            $state=Save-State $support (Get-Candidates)
            Write-Log 'capture' 'pass' @{knownFolder=$state.registration.KnownFolder;sha256=$state.registration.Sha256;targetSha256=$state.registration.Target.Sha256;deviceCount=$state.boltDeviceCount;relatedStartupCount=$state.relatedBoltStartupCount}
            $state
        }
        'DryRun' {
            $candidates=Get-Candidates
            Assert-Eligible $support $candidates
            $result=[pscustomobject]@{Profile=$profile;WouldChange=$true;MutationCount=1;KnownFolder=$candidates[0].KnownFolder;RegistrationSha256=$candidates[0].Sha256;FromPresent=$true;ToPresent=$false;ByteExactRollback=$true;PreserveReceiverPairing=$true;PreserveBluetooth=$true;PreserveFirmware=$true;PreserveDevicesAndDrivers=$true;PreserveServicesAndTasks=$true;PreserveSecurityUpdatesRecoveryManagement=$true;RebootPersistenceCheckRequired=$true}
            Write-Log 'dry-run' 'pass' $result
            $result
        }
        'Apply' {
            $state=if(Test-Path -LiteralPath $StatePath){Read-State}else{Save-State $support (Get-Candidates)}
            Assert-Invariants $state
            if(Test-Removed $state) { Write-Log 'apply' 'idempotent' @{mutationCount=0}; return [pscustomobject]@{Applied=$true;MutationCount=0} }
            $bytes=[IO.File]::ReadAllBytes([string]$state.registration.Path)
            if((Get-HashBytes $bytes) -ne [string]$state.registration.Sha256) { throw 'Startup registration drift detected.' }
            if($WhatIfPreference) { Write-Log 'apply' 'whatif' @{mutationCount=0}; return [pscustomobject]@{Applied=$false;WhatIf=$true;MutationCount=0} }
            if($PSCmdlet.ShouldProcess([string]$state.registration.Path,'Remove exact Logi Bolt Startup-folder registration')) {
                Remove-Item -LiteralPath ([string]$state.registration.Path) -Force
            }
            if(!(Test-Removed $state)) { throw 'Apply verification failed.' }
            Assert-Invariants $state
            Write-Log 'apply' 'pass' @{mutationCount=1;sha256=$state.registration.Sha256}
            [pscustomobject]@{Applied=$true;MutationCount=1}
        }
        'Verify' {
            $state=Read-State
            Assert-Invariants $state
            if(!(Test-Removed $state)) { throw 'Treatment verification failed.' }
            Write-Log 'verify' 'pass' @{removed=$true}
            [pscustomobject]@{Verified=$true;Removed=$true}
        }
        'VerifyReboot' {
            $state=Read-State
            Assert-Invariants $state
            $boot=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
            if($boot -eq [string]$state.capturedBootTime) { throw 'A later boot is required for reboot-persistence verification.' }
            if(!(Test-Removed $state)) { throw 'Treatment did not persist across reboot.' }
            Write-Log 'verify-reboot' 'pass' @{capturedBoot=$state.capturedBootTime;currentBoot=$boot;removed=$true}
            [pscustomobject]@{Verified=$true;LaterBoot=$true;Removed=$true}
        }
        'Rollback' {
            $state=Read-State
            Assert-Invariants $state
            $path=[string]$state.registration.Path
            if(Test-Path -LiteralPath $path) {
                if(Test-Restored $state) { Write-Log 'rollback' 'idempotent' @{mutationCount=0}; return [pscustomobject]@{RolledBack=$true;MutationCount=0} }
                throw 'Rollback destination collision detected.'
            }
            if($WhatIfPreference) { Write-Log 'rollback' 'whatif' @{mutationCount=0}; return [pscustomobject]@{RolledBack=$false;WhatIf=$true;MutationCount=0} }
            if($PSCmdlet.ShouldProcess($path,'Restore exact Logi Bolt Startup-folder registration')) {
                $bytes=[Convert]::FromBase64String([string]$state.registration.BytesBase64)
                [IO.File]::WriteAllBytes($path,$bytes)
                $file=Get-Item -LiteralPath $path -Force
                $file.CreationTimeUtc=[DateTime]::Parse([string]$state.registration.CreationTimeUtc).ToUniversalTime()
                $file.LastWriteTimeUtc=[DateTime]::Parse([string]$state.registration.LastWriteTimeUtc).ToUniversalTime()
                $file.Attributes=[IO.FileAttributes][int]$state.registration.Attributes
                $security=New-Object Security.AccessControl.FileSecurity
                $security.SetSecurityDescriptorSddlForm([string]$state.registration.Sddl)
                Set-Acl -LiteralPath $path -AclObject $security
            }
            if(!(Test-Restored $state)) { throw 'Exact rollback verification failed.' }
            Assert-Invariants $state
            Write-Log 'rollback' 'pass' @{mutationCount=1;sha256=$state.registration.Sha256}
            [pscustomobject]@{RolledBack=$true;MutationCount=1;ExactRestore=$true}
        }
    }
} catch {
    Write-Log 'failure' 'fail' @{exceptionType=$_.Exception.GetType().FullName;message=$_.Exception.Message}
    throw
}

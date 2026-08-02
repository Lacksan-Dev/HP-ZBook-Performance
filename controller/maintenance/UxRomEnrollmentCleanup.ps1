#requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Start','Resume','Check','Rollback')]
    [string]$Action = 'Start',
    [string]$Root = 'C:\ProgramData\ZBookPerf',
    [string]$StatePath,
    [switch]$SelfManagedConfirmed,
    [switch]$LabTier2Confirmed,
    [switch]$NoReboot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Experiment = 'EXP-137'
$script:Issue = 313
$script:SchemaVersion = 2
$script:ResumeTaskName = 'Lacksan-EXP137-EnrollmentCleanup-Resume'
$script:GuidPattern = '(?i)^\{?[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\}?$'
$script:EnrollmentRoots = [ordered]@{
    Enrollments = 'HKLM:\SOFTWARE\Microsoft\Enrollments'
    EnrollmentStatus = 'HKLM:\SOFTWARE\Microsoft\Enrollments\Status'
    OmadmAccounts = 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts'
    OmadmLogger = 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger'
    OmadmSessions = 'HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions'
    WorkplaceJoin = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\JoinInfo'
}
$script:MdmAutoEnrollPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM'
$script:RegistryExportRoots = [ordered]@{
    Enrollments = 'HKLM\SOFTWARE\Microsoft\Enrollments'
    OmadmAccounts = 'HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts'
    OmadmLogger = 'HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Logger'
    OmadmSessions = 'HKLM\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions'
    WorkplaceJoin = 'HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\JoinInfo'
    MdmAutoEnrollPolicy = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM'
}
$script:ProtectedServices = @('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','edgeupdate','edgeupdatem')
$script:RawExp071Url = 'https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/controller/providers/EdgeBackgroundModeOff.ps1'
$script:RunRoot = $null
$script:LogPath = $null

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Native {
    param([string]$FilePath,[string[]]$Arguments=@(),[switch]$AllowFailure)
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $FilePath @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $old }
    $text = @($output | ForEach-Object {
        if ($_ -is [Management.Automation.ErrorRecord] -and $_.Exception) { $_.Exception.Message } else { [string]$_ }
    }) -join [Environment]::NewLine
    if (-not $AllowFailure -and $code -ne 0) { throw "$FilePath exited with code $code. $text" }
    [pscustomobject]@{ FilePath=$FilePath; Arguments=@($Arguments); ExitCode=$code; Output=$text }
}

function Get-Sha256Text {
    param([string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes([string]$Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

function Ensure-SecureDirectory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
    try {
        $sid = ([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
        [void](Invoke-Native -FilePath 'icacls.exe' -Arguments @(
            $Path,'/inheritance:r','/grant:r',
            "*$sid`:(OI)(CI)F",'*S-1-5-18:(OI)(CI)F','*S-1-5-32-544:(OI)(CI)F'
        ) -AllowFailure)
    } catch { }
}

function Write-Evidence {
    param([string]$Stage,[string]$Result,[hashtable]$Data=@{})
    if (-not $script:LogPath) { return }
    $record = [ordered]@{
        schemaVersion=$script:SchemaVersion
        experiment=$script:Experiment
        issue=$script:Issue
        timestampUtc=[DateTime]::UtcNow.ToString('o')
        stage=$Stage
        result=$Result
        machine=$env:COMPUTERNAME
        userSid=([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    }
    foreach ($key in $Data.Keys) { $record[$key] = $Data[$key] }
    ($record | ConvertTo-Json -Depth 16 -Compress) | Add-Content -LiteralPath $script:LogPath -Encoding UTF8
}

function Save-State {
    param([object]$State)
    $State.updatedUtc = [DateTime]::UtcNow.ToString('o')
    $State | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Read-State {
    if (-not $StatePath -or -not (Test-Path -LiteralPath $StatePath)) { throw 'EXP-137 state artifact is missing.' }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.schemaVersion -ne $script:SchemaVersion -or $state.experiment -ne $script:Experiment -or $state.machine -ne $env:COMPUTERNAME) {
        throw 'EXP-137 state identity validation failed.'
    }
    return $state
}

function ConvertTo-CanonicalGuid {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -notmatch $script:GuidPattern) { return $null }
    return $Value.Trim('{}').ToLowerInvariant()
}

function Get-GuidChildren {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    return @(Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue | ForEach-Object {
        ConvertTo-CanonicalGuid -Value $_.PSChildName
    } | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-RegistryValueState {
    param([string]$Path,[string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{keyExists=$false;valueExists=$false;kind=$null;value=$null} }
    $key = Get-Item -LiteralPath $Path
    if ($key.GetValueNames() -notcontains $Name) { return [pscustomobject]@{keyExists=$true;valueExists=$false;kind=$null;value=$null} }
    [pscustomobject]@{
        keyExists=$true
        valueExists=$true
        kind=$key.GetValueKind($Name).ToString()
        value=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
}

function Get-MdmAutoEnrollPolicyState {
    [pscustomobject][ordered]@{
        AutoEnrollMDM = Get-RegistryValueState $script:MdmAutoEnrollPolicyPath 'AutoEnrollMDM'
        UseAADCredentialType = Get-RegistryValueState $script:MdmAutoEnrollPolicyPath 'UseAADCredentialType'
    }
}

function Get-DsRegSnapshot {
    param([string]$Label)
    $result = Invoke-Native -FilePath 'dsregcmd.exe' -Arguments @('/status') -AllowFailure
    $rawPath = Join-Path $script:RunRoot "$Label-dsregcmd.txt"
    $result.Output | Set-Content -LiteralPath $rawPath -Encoding UTF8
    $values = [ordered]@{
        azureAdJoined=$null
        enterpriseJoined=$null
        domainJoined=$null
        workplaceJoined=$null
        mdmUrlPresent=$null
    }
    foreach ($item in @(
        @{Key='azureAdJoined';Name='AzureAdJoined'},
        @{Key='enterpriseJoined';Name='EnterpriseJoined'},
        @{Key='domainJoined';Name='DomainJoined'},
        @{Key='workplaceJoined';Name='WorkplaceJoined'}
    )) {
        $m = [regex]::Match($result.Output,"(?m)^\s*$($item.Name)\s*:\s*(YES|NO)\s*$")
        if ($m.Success) { $values[$item.Key] = ($m.Groups[1].Value -eq 'YES') }
    }
    $mdm = [regex]::Match($result.Output,'(?m)^\s*MdmUrl\s*:\s*(.*?)\s*$')
    if ($mdm.Success) { $values.mdmUrlPresent = -not [string]::IsNullOrWhiteSpace($mdm.Groups[1].Value) }
    [pscustomobject][ordered]@{
        exitCode=$result.ExitCode
        rawPath=$rawPath
        azureAdJoined=$values.azureAdJoined
        enterpriseJoined=$values.enterpriseJoined
        domainJoined=$values.domainJoined
        workplaceJoined=$values.workplaceJoined
        mdmUrlPresent=$values.mdmUrlPresent
    }
}

function Get-EnterpriseMgmtTasks {
    $records = @()
    foreach ($task in @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskPath -like '\Microsoft\Windows\EnterpriseMgmt\*' })) {
        $combined = "$($task.TaskPath)$($task.TaskName)"
        $m = [regex]::Match($combined,'(?i)\\Microsoft\\Windows\\EnterpriseMgmt\\(?<folder>\{?[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\}?)\\')
        $guid = if ($m.Success) { ConvertTo-CanonicalGuid $m.Groups['folder'].Value } else { $null }
        $rootEnrollmentTask = (-not $guid -and $task.TaskPath -eq '\Microsoft\Windows\EnterpriseMgmt\' -and $task.TaskName -match '(?i)enroll|mdm|management')
        $xml = $null
        try { $xml = Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop } catch { }
        $records += [pscustomobject][ordered]@{
            taskPath=[string]$task.TaskPath
            taskName=[string]$task.TaskName
            state=[string]$task.State
            enrollmentGuid=$guid
            folderName=if ($m.Success) { [string]$m.Groups['folder'].Value } else { $null }
            rootEnrollmentTaskCandidate=[bool]$rootEnrollmentTask
            xmlSha256=if ($xml) { Get-Sha256Text $xml } else { $null }
        }
    }
    return @($records)
}

function Get-EnrollmentInventory {
    $sources = [ordered]@{
        Enrollments = @(Get-GuidChildren $script:EnrollmentRoots.Enrollments)
        EnrollmentStatus = @(Get-GuidChildren $script:EnrollmentRoots.EnrollmentStatus)
        OmadmAccounts = @(Get-GuidChildren $script:EnrollmentRoots.OmadmAccounts)
        OmadmLogger = @(Get-GuidChildren $script:EnrollmentRoots.OmadmLogger)
        OmadmSessions = @(Get-GuidChildren $script:EnrollmentRoots.OmadmSessions)
        WorkplaceJoin = @(Get-GuidChildren $script:EnrollmentRoots.WorkplaceJoin)
    }
    $tasks = @(Get-EnterpriseMgmtTasks)
    $taskGuids = @($tasks | ForEach-Object { $_.enrollmentGuid } | Where-Object { $_ } | Sort-Object -Unique)
    $all = @($sources.Values | ForEach-Object { @($_) }) + @($taskGuids) | Sort-Object -Unique
    $records = @()
    foreach ($guid in $all) {
        $present = @()
        foreach ($name in $sources.Keys) { if ($guid -in @($sources[$name])) { $present += $name } }
        if ($guid -in $taskGuids) { $present += 'EnterpriseMgmtTasks' }
        $taskCount = @($tasks | Where-Object enrollmentGuid -eq $guid).Count
        $active = (
            'WorkplaceJoin' -in $present -or
            'OmadmAccounts' -in $present -or
            ('Enrollments' -in $present -and (
                'EnrollmentStatus' -in $present -or
                'OmadmSessions' -in $present -or
                $taskCount -gt 0
            ))
        )
        $classification = if ($active) {
            'active-or-correlated-enrollment'
        } elseif ($taskCount -gt 0 -and $present.Count -eq 1) {
            'residual-enterprisemgmt-task'
        } elseif ($present -contains 'Enrollments' -or $present -contains 'EnrollmentStatus') {
            'residual-enrollment-record'
        } else {
            'residual-enrollment-artifact'
        }
        $records += [pscustomobject][ordered]@{
            guid=$guid
            classification=$classification
            activeOrCorrelated=[bool]$active
            sources=@($present)
            enterpriseMgmtTaskCount=$taskCount
        }
    }
    $rootTasks = @($tasks | Where-Object rootEnrollmentTaskCandidate)
    [pscustomobject][ordered]@{
        capturedUtc=[DateTime]::UtcNow.ToString('o')
        enrollmentContainerChildCount=if (Test-Path $script:EnrollmentRoots.Enrollments) { @(Get-ChildItem $script:EnrollmentRoots.Enrollments -ErrorAction SilentlyContinue).Count } else { 0 }
        sources=[pscustomobject]$sources
        enterpriseMgmtTasks=@($tasks)
        rootEnrollmentTaskCount=$rootTasks.Count
        mdmAutoEnrollPolicy=Get-MdmAutoEnrollPolicyState
        records=@($records)
        activeCount=@($records | Where-Object activeOrCorrelated).Count
        residualCount=@($records | Where-Object { -not $_.activeOrCorrelated }).Count
    }
}

function Get-ProtectedSnapshot {
    $services = @()
    foreach ($name in $script:ProtectedServices) {
        $service = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
        if ($service) {
            $services += [pscustomobject][ordered]@{
                name=$service.Name
                startMode=$service.StartMode
                pathName=$service.PathName
            }
        }
    }
    $edgeTasks = @()
    foreach ($task in @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match '(?i)MicrosoftEdgeUpdate' -or $_.TaskPath -match '(?i)EdgeUpdate' })) {
        try {
            $xml = Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop
            $edgeTasks += [pscustomobject]@{ taskPath=$task.TaskPath; taskName=$task.TaskName; xmlSha256=(Get-Sha256Text $xml) }
        } catch { }
    }
    [pscustomobject][ordered]@{
        services=@($services | Sort-Object name)
        edgeUpdateTasks=@($edgeTasks | Sort-Object taskPath,taskName)
        mutationExclusions=@(
            'Windows Update services, tasks, files, policies and data',
            'Microsoft Defender and Firewall services, policies and data',
            'Microsoft Edge Update services, tasks, files and policy',
            'Microsoft Edge User Data including passwords, profiles, cookies, favorites, history and extensions'
        )
    }
}

function Test-ProtectedEquivalent {
    param([object]$Before,[object]$After)
    $a = $Before | ConvertTo-Json -Depth 12 -Compress
    $b = $After | ConvertTo-Json -Depth 12 -Compress
    return ($a -eq $b)
}

function Export-RegistryBackups {
    param([string]$BackupRoot)
    Ensure-SecureDirectory $BackupRoot
    $rows = @()
    foreach ($name in $script:RegistryExportRoots.Keys) {
        $native = $script:RegistryExportRoots[$name]
        $file = Join-Path $BackupRoot "$name.reg"
        $result = Invoke-Native -FilePath 'reg.exe' -Arguments @('export',$native,$file,'/y') -AllowFailure
        $rows += [pscustomobject]@{ name=$name; nativePath=$native; file=$file; exitCode=$result.ExitCode; exported=($result.ExitCode -eq 0) }
    }
    return @($rows)
}

function Export-TaskBackups {
    param([object[]]$Tasks,[string]$BackupRoot)
    Ensure-SecureDirectory $BackupRoot
    $rows = @()
    $index = 0
    foreach ($task in $Tasks) {
        $index++
        try {
            $xml = Export-ScheduledTask -TaskName $task.taskName -TaskPath $task.taskPath -ErrorAction Stop
            $file = Join-Path $BackupRoot ("task-{0:D3}.xml" -f $index)
            $xml | Set-Content -LiteralPath $file -Encoding Unicode
            $rows += [pscustomobject]@{ taskPath=$task.taskPath; taskName=$task.taskName; enrollmentGuid=$task.enrollmentGuid; rootEnrollmentTaskCandidate=$task.rootEnrollmentTaskCandidate; file=$file; xmlSha256=(Get-Sha256Text $xml) }
        } catch {
            Write-Evidence 'task-backup' 'fail' @{taskPath=$task.taskPath;taskName=$task.taskName;error=$_.Exception.Message}
            throw
        }
    }
    return @($rows)
}

function Confirm-SelfManagedLab {
    if (-not $LabTier2Confirmed) {
        if (-not [Environment]::UserInteractive) { throw 'EXP-137 requires explicit recoverable-lab confirmation.' }
        $answer = Read-Host 'This workflow removes local Workplace/MDM enrollment state and reboots. Is this a dedicated recoverable lab system? [y/N]'
        if ($answer -notin @('y','Y','yes','YES','Yes')) { throw 'Recoverable-lab confirmation was declined.' }
        $script:LabTier2Confirmed = $true
    }
    if (-not $SelfManagedConfirmed) {
        if (-not [Environment]::UserInteractive) { throw 'EXP-137 requires explicit self-managed enrollment confirmation.' }
        $answer = Read-Host 'Do you control the management enrollment on this PC and want UX-ROM to remove it? [y/N]'
        if ($answer -notin @('y','Y','yes','YES','Yes')) { throw 'Self-managed enrollment confirmation was declined.' }
        $script:SelfManagedConfirmed = $true
    }
}

function Remove-EnterpriseMgmtArtifacts {
    param([object[]]$Tasks,[string[]]$TargetGuids)
    $results = @()
    foreach ($task in $Tasks) {
        $selected = ($task.enrollmentGuid -and $task.enrollmentGuid -in $TargetGuids) -or $task.rootEnrollmentTaskCandidate
        if (-not $selected) { continue }
        if ($PSCmdlet.ShouldProcess("$($task.taskPath)$($task.taskName)",'Remove captured EnterpriseMgmt enrollment task')) {
            try {
                Unregister-ScheduledTask -TaskName $task.taskName -TaskPath $task.taskPath -Confirm:$false -ErrorAction Stop
                $results += [pscustomobject]@{taskPath=$task.taskPath;taskName=$task.taskName;status='removed'}
                Write-Evidence 'remove-enterprisemgmt-task' 'pass' @{taskPath=$task.taskPath;taskName=$task.taskName;enrollmentGuid=$task.enrollmentGuid}
            } catch {
                $results += [pscustomobject]@{taskPath=$task.taskPath;taskName=$task.taskName;status='retained';error=$_.Exception.Message}
                Write-Evidence 'remove-enterprisemgmt-task' 'retained' @{taskPath=$task.taskPath;taskName=$task.taskName;error=$_.Exception.Message}
            }
        }
    }
    $folders = @($Tasks | Where-Object { $_.enrollmentGuid -in $TargetGuids -and $_.folderName } | Select-Object -ExpandProperty folderName -Unique)
    if ($folders.Count -gt 0 -and -not $WhatIfPreference) {
        try {
            $scheduler = New-Object -ComObject Schedule.Service
            $scheduler.Connect()
            $parent = $scheduler.GetFolder('\Microsoft\Windows\EnterpriseMgmt')
            foreach ($folder in $folders) {
                try { $parent.DeleteFolder($folder,0); Write-Evidence 'remove-enterprisemgmt-folder' 'pass' @{folder=$folder} }
                catch { Write-Evidence 'remove-enterprisemgmt-folder' 'retained' @{folder=$folder;error=$_.Exception.Message} }
            }
        } catch { Write-Evidence 'remove-enterprisemgmt-folder' 'retained' @{error=$_.Exception.Message} }
    }
    return @($results)
}

function Remove-RegistryArtifacts {
    param([string[]]$TargetGuids)
    $results = @()
    foreach ($guid in $TargetGuids) {
        foreach ($name in $script:EnrollmentRoots.Keys) {
            $path = Join-Path $script:EnrollmentRoots[$name] $guid
            $bracePath = Join-Path $script:EnrollmentRoots[$name] "{$guid}"
            foreach ($candidate in @($path,$bracePath) | Select-Object -Unique) {
                if (-not (Test-Path -LiteralPath $candidate)) { continue }
                if ($PSCmdlet.ShouldProcess($candidate,'Remove captured self-managed enrollment registry artifact')) {
                    try {
                        Remove-Item -LiteralPath $candidate -Recurse -Force -ErrorAction Stop
                        $results += [pscustomobject]@{path=$candidate;status='removed'}
                        Write-Evidence 'remove-enrollment-registry' 'pass' @{path=$candidate;enrollmentGuid=$guid}
                    } catch {
                        $results += [pscustomobject]@{path=$candidate;status='retained';error=$_.Exception.Message}
                        Write-Evidence 'remove-enrollment-registry' 'retained' @{path=$candidate;enrollmentGuid=$guid;error=$_.Exception.Message}
                    }
                }
            }
        }
    }
    return @($results)
}

function Remove-MdmAutoEnrollPolicy {
    $results = @()
    foreach ($name in @('AutoEnrollMDM','UseAADCredentialType')) {
        $state = Get-RegistryValueState $script:MdmAutoEnrollPolicyPath $name
        if (-not $state.valueExists) { continue }
        if ($PSCmdlet.ShouldProcess("$script:MdmAutoEnrollPolicyPath::$name",'Remove captured self-managed MDM auto-enrollment policy value')) {
            try {
                Remove-ItemProperty -LiteralPath $script:MdmAutoEnrollPolicyPath -Name $name -ErrorAction Stop
                $results += [pscustomobject]@{name=$name;status='removed'}
                Write-Evidence 'remove-mdm-autoenroll-policy' 'pass' @{name=$name}
            } catch {
                $results += [pscustomobject]@{name=$name;status='retained';error=$_.Exception.Message}
                Write-Evidence 'remove-mdm-autoenroll-policy' 'retained' @{name=$name;error=$_.Exception.Message}
            }
        }
    }
    return @($results)
}

function Resolve-Exp071Provider {
    $repoCandidate = Join-Path (Split-Path $PSScriptRoot -Parent) 'providers\EdgeBackgroundModeOff.ps1'
    if (Test-Path -LiteralPath $repoCandidate) { return $repoCandidate }
    $destination = Join-Path $script:RunRoot 'EdgeBackgroundModeOff.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri $script:RawExp071Url -OutFile $destination
    return $destination
}

function Invoke-Exp071PreReboot {
    $provider = Resolve-Exp071Provider
    $state = Join-Path $script:RunRoot 'EXP-071-state.json'
    $log = Join-Path $script:RunRoot 'EXP-071-log.jsonl'
    $checkPath = Join-Path $script:RunRoot 'EXP-071-check.json'
    try {
        $check = & $provider -Action Check -StatePath $state -LogPath $log
        $check | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $checkPath -Encoding UTF8
        if (-not $check.Support.Supported) {
            Write-Evidence 'exp-071-rerun' 'needs-evidence' @{reason='EXP-071 support gate still declined after cleanup';checkPath=$checkPath}
            return [pscustomobject]@{status='needs-evidence';applied=$false;provider=$provider;statePath=$state;logPath=$log;checkPath=$checkPath}
        }
        & $provider -Action Capture -StatePath $state -LogPath $log | Out-Null
        & $provider -Action DryRun -StatePath $state -LogPath $log | Out-Null
        & $provider -Action Apply -StatePath $state -LogPath $log -Confirm:$false | Out-Null
        & $provider -Action Verify -StatePath $state -LogPath $log | Out-Null
        Write-Evidence 'exp-071-rerun' 'pass' @{stage='pre-reboot';provider=$provider;statePath=$state;logPath=$log}
        return [pscustomobject]@{status='applied-pre-reboot';applied=$true;provider=$provider;statePath=$state;logPath=$log;checkPath=$checkPath}
    } catch {
        Write-Evidence 'exp-071-rerun' 'fail' @{stage='pre-reboot';error=$_.Exception.Message}
        return [pscustomobject]@{status='failed';applied=$false;provider=$provider;statePath=$state;logPath=$log;checkPath=$checkPath;error=$_.Exception.Message}
    }
}

function Register-ResumeTask {
    param([string]$ResumeScript)
    Unregister-ScheduledTask -TaskName $script:ResumeTaskName -Confirm:$false -ErrorAction SilentlyContinue
    $exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"$ResumeScript`" -Action Resume -Root `"$Root`" -StatePath `"$StatePath`" -SelfManagedConfirmed -LabTier2Confirmed"
    $taskAction = New-ScheduledTaskAction -Execute $exe -Argument $args
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
    $principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
    Register-ScheduledTask -TaskName $script:ResumeTaskName -Action $taskAction -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Evidence 'register-resume-task' 'pass' @{taskName=$script:ResumeTaskName;user=$identity}
}

function Remove-ResumeTask {
    Unregister-ScheduledTask -TaskName $script:ResumeTaskName -Confirm:$false -ErrorAction SilentlyContinue
}

function New-RunContext {
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
    $suffix = [guid]::NewGuid().ToString('N').Substring(0,8)
    $script:RunRoot = Join-Path (Join-Path $Root 'EXP-137') "$stamp-$suffix"
    Ensure-SecureDirectory $script:RunRoot
    $script:LogPath = Join-Path $script:RunRoot 'events.jsonl'
    if (-not $StatePath) { $script:StatePath = Join-Path $script:RunRoot 'state.json' }
}

function Initialize-ExistingContext {
    $state = Read-State
    $script:RunRoot = [string]$state.runRoot
    $script:LogPath = Join-Path $script:RunRoot 'events.jsonl'
    return $state
}

function Invoke-Check {
    if (-not (Test-IsAdministrator)) { throw 'EXP-137 requires an elevated PowerShell session.' }
    New-RunContext
    $dsreg = Get-DsRegSnapshot 'check'
    $inventory = Get-EnrollmentInventory
    [pscustomobject][ordered]@{
        experiment=$script:Experiment
        issue=$script:Issue
        dsregcmd=$dsreg
        inventory=$inventory
        eligibleForSelfManagedCleanup=(-not $dsreg.domainJoined -and -not $dsreg.azureAdJoined -and -not $dsreg.enterpriseJoined)
        mutationAllowed=$false
        evidenceRoot=$script:RunRoot
    }
}

function Invoke-Start {
    if (-not (Test-IsAdministrator)) { throw 'EXP-137 requires an elevated PowerShell session.' }
    New-RunContext
    Write-Evidence 'start' 'pass' @{action='capture'}
    $beforeDsreg = Get-DsRegSnapshot 'before'
    $beforeInventory = Get-EnrollmentInventory
    $protected = Get-ProtectedSnapshot
    if ($beforeDsreg.domainJoined -or $beforeDsreg.azureAdJoined -or $beforeDsreg.enterpriseJoined) {
        Write-Evidence 'support' 'refused' @{reason='Domain, Microsoft Entra joined, or Enterprise joined device identity is outside EXP-137 scope';dsregcmd=$beforeDsreg}
        throw 'EXP-137 only removes self-managed Workplace/MDM state. Domain, Microsoft Entra joined, and Enterprise joined device identities are outside this cleanup scope.'
    }

    $targets = @($beforeInventory.records | Select-Object -ExpandProperty guid -Unique)
    $state = [pscustomobject][ordered]@{
        schemaVersion=$script:SchemaVersion
        experiment=$script:Experiment
        issue=$script:Issue
        machine=$env:COMPUTERNAME
        userSid=([Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
        createdUtc=[DateTime]::UtcNow.ToString('o')
        updatedUtc=[DateTime]::UtcNow.ToString('o')
        phase='captured'
        runRoot=$script:RunRoot
        capturedBootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')
        beforeDsregcmd=$beforeDsreg
        beforeInventory=$beforeInventory
        targetGuids=@($targets)
        protectedBefore=$protected
        registryBackups=@()
        taskBackups=@()
        disconnect=$null
        removedRegistry=@()
        removedTasks=@()
        removedMdmPolicy=@()
        afterMutationDsregcmd=$null
        afterMutationInventory=$null
        exp071=$null
        needsEvidence=$true
        note='Management enrollment cleanup is operator-authorized. Windows Update, Defender, Edge Update, Edge User Data, passwords, profiles, cookies, favorites, history and extensions are outside the mutation allowlist.'
    }
    Save-State $state

    Write-Host ''
    Write-Host 'EXP-137 self-managed enrollment cleanup' -ForegroundColor Cyan
    Write-Host "Active/correlated enrollment records: $($beforeInventory.activeCount)"
    Write-Host "Residual enrollment records: $($beforeInventory.residualCount)"
    Write-Host "EnterpriseMgmt tasks: $(@($beforeInventory.enterpriseMgmtTasks).Count)"
    Write-Host "Root enrollment tasks: $($beforeInventory.rootEnrollmentTaskCount)"
    Write-Host "Workplace joined: $($beforeDsreg.workplaceJoined)"

    if ($WhatIfPreference) {
        $state.phase = 'dry-run-complete'
        Save-State $state
        Write-Evidence 'dry-run' 'pass' @{targetGuidCount=$targets.Count;enterpriseMgmtTaskCount=@($beforeInventory.enterpriseMgmtTasks).Count;rootEnrollmentTaskCount=$beforeInventory.rootEnrollmentTaskCount;wouldReboot=(-not $NoReboot)}
        Write-Host "Dry run evidence: $script:RunRoot" -ForegroundColor DarkYellow
        return $state
    }

    Confirm-SelfManagedLab
    $backupRoot = Join-Path $script:RunRoot 'backup'
    $state.registryBackups = @(Export-RegistryBackups -BackupRoot (Join-Path $backupRoot 'registry'))
    $state.taskBackups = @(Export-TaskBackups -Tasks @($beforeInventory.enterpriseMgmtTasks) -BackupRoot (Join-Path $backupRoot 'tasks'))
    Save-State $state

    if ($beforeDsreg.workplaceJoined) {
        $leave = Invoke-Native -FilePath 'dsregcmd.exe' -Arguments @('/leave') -AllowFailure
        $state.disconnect = [pscustomobject]@{attempted=$true;exitCode=$leave.ExitCode;outputSha256=(Get-Sha256Text $leave.Output)}
        Write-Evidence 'workplace-disconnect' $(if ($leave.ExitCode -eq 0) {'pass'} else {'continued-with-local-cleanup'}) @{exitCode=$leave.ExitCode;outputSha256=$state.disconnect.outputSha256}
    } else {
        $state.disconnect = [pscustomobject]@{attempted=$false;exitCode=$null;outputSha256=$null}
    }

    $state.removedTasks = @(Remove-EnterpriseMgmtArtifacts -Tasks @($beforeInventory.enterpriseMgmtTasks) -TargetGuids $targets)
    $state.removedRegistry = @(Remove-RegistryArtifacts -TargetGuids $targets)
    $state.removedMdmPolicy = @(Remove-MdmAutoEnrollPolicy)
    $state.afterMutationDsregcmd = Get-DsRegSnapshot 'after-mutation'
    $state.afterMutationInventory = Get-EnrollmentInventory
    $state.exp071 = Invoke-Exp071PreReboot
    $state.phase = 'awaiting-reboot'
    Save-State $state

    $resumeScript = Join-Path $script:RunRoot 'UxRomEnrollmentCleanup.Resume.ps1'
    Copy-Item -LiteralPath $PSCommandPath -Destination $resumeScript -Force
    Register-ResumeTask -ResumeScript $resumeScript
    Write-Evidence 'pre-reboot-complete' 'pass' @{removedRegistryCount=@($state.removedRegistry | Where-Object status -eq 'removed').Count;removedTaskCount=@($state.removedTasks | Where-Object status -eq 'removed').Count;removedMdmPolicyCount=@($state.removedMdmPolicy | Where-Object status -eq 'removed').Count;exp071Status=$state.exp071.status}

    Write-Host "Evidence: $script:RunRoot" -ForegroundColor Green
    if ($NoReboot) {
        Write-Host 'Reboot deferred by -NoReboot. The registered resume task will continue after the next sign-in.' -ForegroundColor DarkYellow
        return $state
    }
    Write-Host 'Rebooting to verify enrollment cleanup and EXP-071 persistence.' -ForegroundColor Yellow
    Restart-Computer -Force
}

function Invoke-Resume {
    if (-not (Test-IsAdministrator)) { throw 'EXP-137 resume requires elevation.' }
    $state = Initialize-ExistingContext
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
    if ($boot -le [datetime]$state.capturedBootTime) { throw 'EXP-137 resume requires a later Windows boot.' }
    Remove-ResumeTask
    $afterDsreg = Get-DsRegSnapshot 'after-reboot'
    $afterInventory = Get-EnrollmentInventory
    $protectedAfter = Get-ProtectedSnapshot
    $remainingTargets = @($afterInventory.records | Where-Object { $_.guid -in @($state.targetGuids) })
    $protectedOk = Test-ProtectedEquivalent -Before $state.protectedBefore -After $protectedAfter
    $joinClean = (-not $afterDsreg.domainJoined -and -not $afterDsreg.azureAdJoined -and -not $afterDsreg.enterpriseJoined -and -not $afterDsreg.workplaceJoined)
    $mdmPolicyClean = (-not $afterInventory.mdmAutoEnrollPolicy.AutoEnrollMDM.valueExists -and -not $afterInventory.mdmAutoEnrollPolicy.UseAADCredentialType.valueExists)
    $artifactsClean = ($remainingTargets.Count -eq 0 -and $afterInventory.rootEnrollmentTaskCount -eq 0 -and $mdmPolicyClean)

    $expStatus = [string]$state.exp071.status
    if ($state.exp071.applied) {
        try {
            & $state.exp071.provider -Action VerifyReboot -StatePath $state.exp071.statePath -LogPath $state.exp071.logPath | Out-Null
            $expStatus = 'verified-reboot'
            Write-Evidence 'exp-071-rerun' 'pass' @{stage='verify-reboot'}
        } catch {
            $expStatus = 'verify-reboot-failed'
            Write-Evidence 'exp-071-rerun' 'fail' @{stage='verify-reboot';error=$_.Exception.Message}
        }
    }

    $state | Add-Member -NotePropertyName afterRebootDsregcmd -NotePropertyValue $afterDsreg -Force
    $state | Add-Member -NotePropertyName afterRebootInventory -NotePropertyValue $afterInventory -Force
    $state | Add-Member -NotePropertyName protectedAfter -NotePropertyValue $protectedAfter -Force
    $state | Add-Member -NotePropertyName verification -NotePropertyValue ([pscustomobject]@{
        laterBoot=$true
        joinStateClean=$joinClean
        targetEnrollmentArtifactsClean=$artifactsClean
        mdmAutoEnrollPolicyClean=$mdmPolicyClean
        protectedConfigurationUnchanged=$protectedOk
        remainingTargetCount=$remainingTargets.Count
        remainingRootEnrollmentTaskCount=$afterInventory.rootEnrollmentTaskCount
        exp071Status=$expStatus
    }) -Force
    $state.exp071.status = $expStatus
    $state.needsEvidence = -not ($joinClean -and $artifactsClean -and $protectedOk -and $expStatus -eq 'verified-reboot')
    $state.phase = if ($state.needsEvidence) { 'complete-needs-evidence' } else { 'complete' }
    Save-State $state
    Write-Evidence 'post-reboot-verification' $(if ($state.needsEvidence) {'needs-evidence'} else {'pass'}) @{joinStateClean=$joinClean;artifactsClean=$artifactsClean;mdmAutoEnrollPolicyClean=$mdmPolicyClean;protectedUnchanged=$protectedOk;exp071Status=$expStatus;remainingTargetCount=$remainingTargets.Count;remainingRootEnrollmentTaskCount=$afterInventory.rootEnrollmentTaskCount}

    Write-Host ''
    Write-Host 'EXP-137 post-reboot verification' -ForegroundColor Cyan
    Write-Host "Workplace joined: $($afterDsreg.workplaceJoined)"
    Write-Host "Remaining captured enrollment GUIDs: $($remainingTargets.Count)"
    Write-Host "Remaining root EnterpriseMgmt enrollment tasks: $($afterInventory.rootEnrollmentTaskCount)"
    Write-Host "MDM auto-enrollment policy values cleared: $mdmPolicyClean"
    Write-Host "Windows Update / Defender / Edge Update configuration unchanged: $protectedOk"
    Write-Host "EXP-071: $expStatus"
    Write-Host "Evidence: $script:RunRoot" -ForegroundColor Green
    if ($state.exp071.applied) {
        Write-Host 'EXP-071 treatment remains active for repeated physical demand-launch measurements. Its exact rollback artifact is retained in this evidence folder.' -ForegroundColor DarkYellow
    }
    return $state
}

function Invoke-Rollback {
    if (-not (Test-IsAdministrator)) { throw 'EXP-137 rollback requires elevation.' }
    $state = Initialize-ExistingContext
    if ($state.exp071 -and $state.exp071.applied -and (Test-Path -LiteralPath $state.exp071.statePath)) {
        try { & $state.exp071.provider -Action Rollback -StatePath $state.exp071.statePath -LogPath $state.exp071.logPath -Confirm:$false | Out-Null; Write-Evidence 'exp-071-rollback' 'pass' @{} }
        catch { Write-Evidence 'exp-071-rollback' 'fail' @{error=$_.Exception.Message}; throw }
    }
    foreach ($backup in @($state.registryBackups | Where-Object exported)) {
        if ($PSCmdlet.ShouldProcess($backup.nativePath,'Restore captured local enrollment registry export')) {
            $result = Invoke-Native -FilePath 'reg.exe' -Arguments @('import',[string]$backup.file) -AllowFailure
            if ($result.ExitCode -ne 0) { throw "Registry restore failed for $($backup.nativePath)." }
            Write-Evidence 'local-registry-rollback' 'pass' @{nativePath=$backup.nativePath;file=$backup.file}
        }
    }
    foreach ($task in @($state.taskBackups)) {
        if ($PSCmdlet.ShouldProcess("$($task.taskPath)$($task.taskName)",'Restore captured EnterpriseMgmt task XML')) {
            $xml = Get-Content -LiteralPath $task.file -Raw
            Register-ScheduledTask -TaskName $task.taskName -TaskPath $task.taskPath -Xml $xml -Force | Out-Null
            Write-Evidence 'local-task-rollback' 'pass' @{taskPath=$task.taskPath;taskName=$task.taskName}
        }
    }
    $state.phase = 'local-rollback-complete'
    $state.needsEvidence = $true
    $state | Add-Member -NotePropertyName rollbackQualification -NotePropertyValue 'Local registry/task artifacts restored. Cloud Workplace/MDM registration can require an authenticated re-enrollment and is outside exact local rollback.' -Force
    Save-State $state
    Write-Evidence 'rollback' 'pass-local-only' @{qualification=$state.rollbackQualification}
    return $state
}

try {
    switch ($Action) {
        'Check' { Invoke-Check }
        'Start' { Invoke-Start }
        'Resume' { Invoke-Resume }
        'Rollback' { Invoke-Rollback }
    }
} catch {
    Write-Evidence $Action 'fail' @{error=$_.Exception.Message;type=$_.Exception.GetType().FullName}
    throw
}

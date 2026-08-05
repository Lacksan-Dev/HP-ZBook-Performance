#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action,
    [Parameter(Mandatory=$true)][string]$TaskName,
    [Parameter(Mandatory=$true)][string]$TaskPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedExecutableSha256,
    [Parameter(Mandatory=$true)][string]$StatePath,
    [Parameter(Mandatory=$true)][string]$LogPath,
    [switch]$SelfManagedLab
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ExperimentId = 'EXP-162'
$ProtectedTokens = @('omnissa','horizon','windowsapp','msrdc','mstsc','remote desktop','tailscale','defender','securityhealth','credential','bitlocker','windowsupdate','usoclient','waasmedic','recovery','accessibility','narrator','magnify','driver','firmware')

function Ensure-Parent([string]$Path) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
}
function Write-Log([string]$Operation,[string]$Result,$Detail,$Before=$null,$After=$null) {
    Ensure-Parent $LogPath
    [pscustomobject][ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString('o'); experiment = $ExperimentId
        machine = $env:COMPUTERNAME; userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        action = $Operation; result = $Result; detail = $Detail; before = $Before; after = $After
    } | ConvertTo-Json -Depth 12 -Compress | Add-Content -LiteralPath $LogPath -Encoding UTF8
}
function Get-BootId { (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o') }
function Get-XmlHash([string]$Xml,[switch]$NormalizeEnabled) {
    [xml]$doc = $Xml
    if ($NormalizeEnabled) {
        $nodes = @($doc.SelectNodes("//*[local-name()='Settings']/*[local-name()='Enabled']"))
        foreach ($node in $nodes) { $node.InnerText = '__EXP162_ENABLED__' }
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes($doc.OuterXml)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') } finally { $sha.Dispose() }
}
function Get-TaskIdentity {
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop
    if (@($task).Count -ne 1) { throw 'Task identity is ambiguous.' }
    $xml = Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
    [xml]$doc = $xml
    $triggerNodes = @($doc.SelectNodes("//*[local-name()='Triggers']/*"))
    $hasLogon = @($triggerNodes | Where-Object { $_.LocalName -eq 'LogonTrigger' }).Count -gt 0
    if (-not $hasLogon) { throw 'Selected task does not contain a logon trigger.' }
    $enabledNode = $doc.SelectSingleNode("//*[local-name()='Settings']/*[local-name()='Enabled']")
    if ($null -eq $enabledNode) { throw 'Task enabled state is missing from exported XML.' }
    $enabled = ([string]$enabledNode.InnerText -eq 'true')
    $actions = @($task.Actions)
    if ($actions.Count -ne 1) { throw 'Selected task must contain exactly one executable action.' }
    $execute = [Environment]::ExpandEnvironmentVariables([string]$actions[0].Execute).Trim('"')
    if (-not [IO.Path]::IsPathRooted($execute) -or -not (Test-Path -LiteralPath $execute -PathType Leaf)) { throw 'Task executable could not be resolved to one local file.' }
    $protectedText = (($TaskPath,$TaskName,[string]$actions[0].Execute,[string]$actions[0].Arguments,[string]$task.Author) -join ' ').ToLowerInvariant()
    foreach ($token in $ProtectedTokens) { if ($protectedText.Contains($token)) { throw "Protected identity detected: $token" } }
    if ($TaskPath -like '\Microsoft\Windows\*') { throw 'Windows platform task paths are outside EXP-162 scope.' }
    $sig = Get-AuthenticodeSignature -LiteralPath $execute
    if ($sig.Status -ne 'Valid') { throw 'Task executable requires a valid Authenticode signature.' }
    $hash = (Get-FileHash -LiteralPath $execute -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($hash -ne $ExpectedExecutableSha256.ToUpperInvariant()) { throw 'Executable hash differs from the selected EXP-143 inventory candidate.' }
    $principal = $task.Principal
    [pscustomobject][ordered]@{
        taskName = $TaskName; taskPath = $TaskPath; enabled = $enabled
        xml = $xml; xmlHash = Get-XmlHash $xml; structuralHash = Get-XmlHash $xml -NormalizeEnabled
        execute = $execute; arguments = [string]$actions[0].Arguments; executableSha256 = $hash
        signer = [string]$sig.SignerCertificate.Subject; author = [string]$task.Author
        principalUserId = [string]$principal.UserId; principalLogonType = [string]$principal.LogonType
        bootId = Get-BootId
    }
}
function Get-ProtectedConfiguration {
    $services = @('WinDefend','wuauserv','UsoSvc','WaaSMedicSvc','CryptSvc','BITS')
    $svc = foreach ($name in $services) {
        $s = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
        if ($s) { [pscustomobject]@{Name=$s.Name;StartMode=$s.StartMode;PathName=$s.PathName} }
    }
    [pscustomobject][ordered]@{ services = @($svc) }
}
function Get-ProtectedRuntimeEvidence {
    $apps = @('vmware-view','wswc','msrdc','mstsc','tailscale')
    [pscustomobject][ordered]@{
        protectedProcesses = @($apps | ForEach-Object { [pscustomobject]@{Name=$_;Running=[bool](Get-Process -Name $_ -ErrorAction SilentlyContinue)} })
    }
}
function Save-State($Identity,$ProtectedConfiguration,$ProtectedRuntime) {
    Ensure-Parent $StatePath
    [pscustomobject][ordered]@{
        schemaVersion = 1; experiment = $ExperimentId; capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        machine = $env:COMPUTERNAME; userSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        selfManagedLab = [bool]$SelfManagedLab; original = $Identity
        protectedConfiguration = $ProtectedConfiguration; protectedRuntime = $ProtectedRuntime
    } | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}
function Load-State {
    if (-not (Test-Path -LiteralPath $StatePath)) { throw 'Captured state file is missing.' }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.experiment -ne $ExperimentId -or $state.machine -ne $env:COMPUTERNAME) { throw 'Captured state is bound to a different experiment or machine.' }
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($state.userSid -ne $sid) { throw 'Captured state is bound to a different user.' }
    $state
}
function Assert-SafeContext {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    if ([string]$os.Caption -notmatch 'Windows 11') { throw 'Windows 11 is required.' }
    if ([string]$cs.Manufacturer -notmatch '(?i)^HP$|Hewlett-Packard') { throw 'HP hardware is required.' }
    if (-not $SelfManagedLab) { throw 'EXP-162 requires explicit SelfManagedLab ownership before mutation.' }
}
function Assert-ProtectedConfigurationUnchanged($Captured) {
    $current = Get-ProtectedConfiguration | ConvertTo-Json -Depth 10 -Compress
    $expected = $Captured | ConvertTo-Json -Depth 10 -Compress
    if ($current -ne $expected) { throw 'Protected configuration drift detected.' }
}

try {
    switch ($Action) {
        'Check' {
            Assert-SafeContext
            $id = Get-TaskIdentity
            [pscustomobject]@{experiment=$ExperimentId;supported=$true;candidate=$id;protectedRuntime=Get-ProtectedRuntimeEvidence}
        }
        'Capture' {
            Assert-SafeContext
            $id = Get-TaskIdentity
            if (-not $id.enabled) { throw 'Candidate must be enabled at baseline.' }
            $protectedConfiguration = Get-ProtectedConfiguration
            $protectedRuntime = Get-ProtectedRuntimeEvidence
            Save-State $id $protectedConfiguration $protectedRuntime
            Write-Log Capture success 'Exact task state captured.' $id $null
            $id
        }
        'DryRun' {
            Assert-SafeContext
            $id = Get-TaskIdentity
            [pscustomobject]@{wouldDisable=$true;taskPath=$id.taskPath;taskName=$id.taskName;executable=$id.execute;rollback='Restore captured enabled state after structural drift checks.'}
        }
        'Apply' {
            Assert-SafeContext
            $state = Load-State
            Assert-ProtectedConfigurationUnchanged $state.protectedConfiguration
            $id = Get-TaskIdentity
            if ($id.structuralHash -ne $state.original.structuralHash) { throw 'Task definition drift detected before apply.' }
            if (-not $id.enabled) { Write-Log Apply success 'Already disabled; idempotent no-op.' $id $id; return $id }
            if ($PSCmdlet.ShouldProcess("$TaskPath$TaskName",'Disable one EXP-162 logon task')) { Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath | Out-Null }
            $after = Get-TaskIdentity
            if ($after.enabled) { throw 'Task remained enabled after apply.' }
            Write-Log Apply success 'Selected logon task disabled.' $id $after
            $after
        }
        'Verify' {
            $state = Load-State
            Assert-ProtectedConfigurationUnchanged $state.protectedConfiguration
            $id = Get-TaskIdentity
            if ($id.structuralHash -ne $state.original.structuralHash -or $id.enabled) { throw 'Treatment verification failed.' }
            Write-Log Verify success 'Treatment state verified.' $state.original ([pscustomobject]@{task=$id;runtime=Get-ProtectedRuntimeEvidence})
            $id
        }
        'VerifyReboot' {
            $state = Load-State
            if ((Get-BootId) -eq $state.original.bootId) { throw 'A later boot has not occurred.' }
            Assert-ProtectedConfigurationUnchanged $state.protectedConfiguration
            $id = Get-TaskIdentity
            if ($id.structuralHash -ne $state.original.structuralHash -or $id.enabled) { throw 'Reboot persistence verification failed.' }
            Write-Log VerifyReboot success 'Disabled state persisted across reboot.' $state.original ([pscustomobject]@{task=$id;runtime=Get-ProtectedRuntimeEvidence})
            $id
        }
        'Rollback' {
            Assert-SafeContext
            $state = Load-State
            Assert-ProtectedConfigurationUnchanged $state.protectedConfiguration
            $id = Get-TaskIdentity
            if ($id.structuralHash -ne $state.original.structuralHash) { throw 'Task definition drift detected; rollback refused.' }
            if ([bool]$state.original.enabled) {
                if (-not $id.enabled -and $PSCmdlet.ShouldProcess("$TaskPath$TaskName",'Restore captured enabled state')) { Enable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath | Out-Null }
            } else {
                if ($id.enabled -and $PSCmdlet.ShouldProcess("$TaskPath$TaskName",'Restore captured disabled state')) { Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath | Out-Null }
            }
            $after = Get-TaskIdentity
            if ($after.structuralHash -ne $state.original.structuralHash -or $after.enabled -ne [bool]$state.original.enabled -or $after.xmlHash -ne $state.original.xmlHash) { throw 'Exact rollback verification failed.' }
            Write-Log Rollback success 'Captured task state restored exactly.' $id ([pscustomobject]@{task=$after;runtime=Get-ProtectedRuntimeEvidence})
            $after
        }
    }
} catch {
    Write-Log $Action failure $_.Exception.Message $null $null
    throw
}

[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath=(Join-Path $PSScriptRoot 'state.json'),
    [string]$LogPath=(Join-Path $PSScriptRoot 'events.jsonl')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:RecommendedPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$script:MandatoryPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$script:ValueName='SleepingTabsEnabled'

function Write-ExpLog([string]$Event,[string]$Result,[hashtable]$Data=@{}) {
    $record=[ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-039';action=$Action;event=$Event;result=$Result;data=$Data}
    Add-Content -LiteralPath $LogPath -Value ($record|ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}
function Get-EdgePath {
    $paths=@("$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")
    @($paths|Where-Object{$_ -and (Test-Path -LiteralPath $_)})|Select-Object -First 1
}
function Get-ManagementState {
    $managed=$false;$signals=@()
    try {
        $text=(& dsregcmd.exe /status 2>$null)-join "`n"
        foreach($name in @('AzureAdJoined','DomainJoined','WorkplaceJoined')) {
            if($text -match "(?im)^\s*$name\s*:\s*YES\s*$") {$managed=$true;$signals+=$name}
        }
    } catch {}
    [pscustomobject]@{Managed=$managed;Signals=$signals}
}
function Get-SupportState {
    $os=Get-CimInstance Win32_OperatingSystem
    $cs=Get-CimInstance Win32_ComputerSystem
    $edge=Get-EdgePath
    $version=$null
    if($edge) {
        $raw=(Get-Item -LiteralPath $edge).VersionInfo.ProductVersion
        if($raw) {$version=[version]$raw}
    }
    $management=Get-ManagementState
    $elevated=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    [pscustomobject]@{
        Supported=($os.Caption -match 'Windows 11' -and $cs.Manufacturer -match 'HP|Hewlett-Packard' -and $edge -and $version -and $version.Major -ge 88)
        OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$cs.Manufacturer;Model=$cs.Model
        EdgePath=$edge;EdgeVersion=$(if($version){$version.ToString()}else{$null})
        Managed=$management.Managed;ManagementSignals=$management.Signals;Elevated=$elevated
    }
}
function Get-ValueState([string]$Path) {
    $keyExists=Test-Path -LiteralPath $Path;$valueExists=$false;$data=$null;$kind=$null
    if($keyExists) {
        $item=Get-Item -LiteralPath $Path
        $valueExists=$item.GetValueNames()-contains $script:ValueName
        if($valueExists) {
            $data=$item.GetValue($script:ValueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $kind=$item.GetValueKind($script:ValueName).ToString()
        }
    }
    [pscustomobject]@{Path=$Path;KeyExists=$keyExists;ValueExists=$valueExists;Data=$data;Kind=$kind}
}
function Save-State($support,$recommended,$mandatory) {
    $state=[ordered]@{schemaVersion=1;experiment='EXP-039';capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;recommendedPath=$script:RecommendedPath;mandatoryPath=$script:MandatoryPath;valueName=$script:ValueName;edgePath=$support.EdgePath;edgeVersion=$support.EdgeVersion;recommended=$recommended;mandatory=$mandatory}
    $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding UTF8
    $state
}
function Read-State {
    if(-not(Test-Path -LiteralPath $StatePath)){throw "State file missing: $StatePath"}
    $state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
    if($state.schemaVersion-ne 1 -or $state.experiment-ne 'EXP-039' -or $state.machine-ne $env:COMPUTERNAME -or $state.valueName-ne $script:ValueName){throw 'State identity validation failed.'}
    $state
}
function Assert-Safe($support,$recommended,$mandatory) {
    if(-not $support.Elevated){throw 'Elevation is required.'}
    if($support.Managed){throw ('Enterprise management detected: '+($support.ManagementSignals-join', '))}
    if($mandatory.ValueExists -or $recommended.ValueExists){throw 'Existing mandatory or recommended Edge policy detected; refusing to override.'}
}
function Test-Applied {
    $value=Get-ValueState $script:RecommendedPath
    $value.ValueExists -and $value.Kind-eq 'DWord' -and [int]$value.Data-eq 1
}
function Restore-State($state) {
    $current=Get-ValueState $script:RecommendedPath
    if($state.recommended.ValueExists){throw 'Captured state was ineligible for application.'}
    if($current.ValueExists -and -not($current.Kind-eq 'DWord' -and [int]$current.Data-eq 1)){throw 'Rollback refused because the policy changed after application.'}
    if($current.ValueExists -and $PSCmdlet.ShouldProcess("$($script:RecommendedPath)::$($script:ValueName)",'Remove experiment policy')) {
        Remove-ItemProperty -LiteralPath $script:RecommendedPath -Name $script:ValueName
    }
    if(-not $state.recommended.KeyExists -and (Test-Path -LiteralPath $script:RecommendedPath)) {
        $item=Get-Item $script:RecommendedPath
        if($item.ValueCount-eq 0 -and @(Get-ChildItem $script:RecommendedPath -ErrorAction SilentlyContinue).Count-eq 0) {
            if($PSCmdlet.ShouldProcess($script:RecommendedPath,'Remove empty experiment-created key')) {Remove-Item $script:RecommendedPath -Force}
        }
    }
}

try {
    $support=Get-SupportState
    Write-ExpLog 'support-detection' $(if($support.Supported){'pass'}else{'unsupported'}) @{edgeVersion=$support.EdgeVersion;managed=$support.Managed;elevated=$support.Elevated}
    if(-not $support.Supported){throw 'EXP-039 supports HP Windows 11 systems with Edge 88 or later only.'}
    $recommended=Get-ValueState $script:RecommendedPath
    $mandatory=Get-ValueState $script:MandatoryPath
    switch($Action) {
        'Check' {[pscustomobject]@{Support=$support;Recommended=$recommended;Mandatory=$mandatory}}
        'Capture' {Assert-Safe $support $recommended $mandatory;Save-State $support $recommended $mandatory|Out-Null;Write-ExpLog 'state-capture' 'pass' @{statePath=$StatePath}}
        'DryRun' {
            if((Test-Path $StatePath)-and(Test-Applied)){[void](Read-State);[pscustomobject]@{WouldChange=$false;AlreadyApplied=$true}}
            else {Assert-Safe $support $recommended $mandatory;[pscustomobject]@{WouldSet="$($script:RecommendedPath)::$($script:ValueName)";Data=1;BrowserRestartRequired=$true;RebootPersistenceCheckRequired=$true}}
            Write-ExpLog 'dry-run' 'pass' @{}
        }
        'Apply' {
            if(Test-Path $StatePath){$state=Read-State;if(Test-Applied){Write-ExpLog 'apply' 'pass' @{changed=$false};break}}
            else {Assert-Safe $support $recommended $mandatory;$state=Save-State $support $recommended $mandatory}
            if($PSCmdlet.ShouldProcess("$($script:RecommendedPath)::$($script:ValueName)",'Set REG_DWORD 1')) {
                if(-not(Test-Path $script:RecommendedPath)){New-Item $script:RecommendedPath -Force|Out-Null}
                New-ItemProperty -LiteralPath $script:RecommendedPath -Name $script:ValueName -PropertyType DWord -Value 1 -Force|Out-Null
            }
            if(-not(Test-Applied)){throw 'Apply verification failed.'}
            Write-ExpLog 'apply' 'pass' @{changed=$true;browserRestartRequired=$true}
        }
        'Verify' {$ok=Test-Applied;Write-ExpLog 'verify' $(if($ok){'pass'}else{'fail'}) @{};if(-not$ok){throw 'Policy verification failed.'};$true}
        'VerifyReboot' {$ok=Test-Applied;Write-ExpLog 'verify-reboot' $(if($ok){'pass'}else{'fail'}) @{bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime};if(-not$ok){throw 'Reboot persistence verification failed.'};$true}
        'Rollback' {$state=Read-State;Restore-State $state;$current=Get-ValueState $script:RecommendedPath;$ok=-not$current.ValueExists;Write-ExpLog 'rollback' $(if($ok){'pass'}else{'fail'}) @{};if(-not$ok){throw 'Rollback verification failed.'};$true}
    }
} catch {
    Write-ExpLog 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName}
    throw
}

Set-StrictMode -Version Latest

$script:MandatoryPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$script:RecommendedPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$script:PolicyName = 'StartupBoostEnabled'

function Write-Exp003Log {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Action,[Parameter(Mandatory)][object]$Data)
    $directory = Split-Path -Parent $Path
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    [pscustomobject]@{ TimestampUtc=[DateTime]::UtcNow.ToString('o'); Experiment='EXP-003'; Action=$Action; Data=$Data } |
        ConvertTo-Json -Depth 10 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Get-Exp003Support {
    [CmdletBinding()]
    param()
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    $programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
    $edgePaths = @(
        $(if ($programFilesX86) { Join-Path $programFilesX86 'Microsoft\Edge\Application\msedge.exe' }),
        $(if ($programFiles) { Join-Path $programFiles 'Microsoft\Edge\Application\msedge.exe' })
    ) | Where-Object { $_ }
    $edgePath = $edgePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $version = if ($edgePath) { (Get-Item -LiteralPath $edgePath).VersionInfo.ProductVersion } else { $null }
    $major = if ($version) { [int](($version -split '\.')[0]) } else { 0 }
    $mandatory = Get-RegistryValueState -Path $script:MandatoryPolicyPath -Name $script:PolicyName
    [pscustomobject]@{
        Supported = ($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match '^HP' -and $edgePath -and $major -ge 88 -and -not $mandatory.Exists)
        WindowsCaption=$os.Caption; WindowsBuild=$os.BuildNumber; Manufacturer=$computer.Manufacturer; Model=$computer.Model
        EdgePath=$edgePath; EdgeVersion=$version; MandatoryPolicyPresent=$mandatory.Exists
        Reason = if (-not ($os.Caption -match 'Windows 11')) { 'Windows 11 required' }
                 elseif (-not ($computer.Manufacturer -match '^HP')) { 'HP system required' }
                 elseif (-not $edgePath) { 'Microsoft Edge executable missing' }
                 elseif ($major -lt 88) { 'Microsoft Edge 88 or later required' }
                 elseif ($mandatory.Exists) { 'Mandatory enterprise StartupBoostEnabled policy has precedence' }
                 else { 'Supported' }
    }
}

function Get-RegistryValueState {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{Path=$Path;Name=$Name;KeyExists=$false;Exists=$false;Kind=$null;Value=$null} }
    $key = Get-Item -LiteralPath $Path
    try {
        $value = $key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -eq $value) { return [pscustomobject]@{Path=$Path;Name=$Name;KeyExists=$true;Exists=$false;Kind=$null;Value=$null} }
        [pscustomobject]@{Path=$Path;Name=$Name;KeyExists=$true;Exists=$true;Kind=[string]$key.GetValueKind($Name);Value=$value}
    } catch { [pscustomobject]@{Path=$Path;Name=$Name;KeyExists=$true;Exists=$false;Kind=$null;Value=$null} }
}

function Get-Exp003State {
    [CmdletBinding()]
    param()
    $processes = @(Get-Process -Name msedge -ErrorAction SilentlyContinue | ForEach-Object {
        $startTime=$null; try {$startTime=$_.StartTime.ToUniversalTime().ToString('o')} catch {$startTime=$null}
        [pscustomobject]@{Id=$_.Id;WorkingSet64=$_.WorkingSet64;StartTime=$startTime}
    })
    [pscustomobject]@{
        MandatoryPolicy=Get-RegistryValueState -Path $script:MandatoryPolicyPath -Name $script:PolicyName
        RecommendedPolicy=Get-RegistryValueState -Path $script:RecommendedPolicyPath -Name $script:PolicyName
        EdgeProcesses=$processes
    }
}

function Save-Exp003State {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$StatePath)
    $support=Get-Exp003Support
    if (-not $support.Supported) { throw "Unsupported system: $($support.Reason)" }
    $directory=Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $payload=[ordered]@{SchemaVersion=1;Experiment='EXP-003';CapturedAtUtc=[DateTime]::UtcNow.ToString('o');Support=$support;State=Get-Exp003State}
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $StatePath -Encoding UTF8
    [pscustomobject]$payload
}

function Invoke-Exp003DryRun {
    [CmdletBinding()]
    param([ValidateSet('Enable','Disable')][string]$StartupBoost='Enable')
    $support=Get-Exp003Support; $state=Get-Exp003State; $desired=if($StartupBoost -eq 'Enable'){1}else{0}
    [pscustomobject]@{
        Supported=$support.Supported;Reason=$support.Reason;DesiredStartupBoost=$desired;CurrentState=$state
        WouldChange=($support.Supported -and ((-not $state.RecommendedPolicy.Exists) -or [int]$state.RecommendedPolicy.Value -ne $desired))
        UsesRecommendedPolicy=$true;PreservesMandatoryPolicy=$true;PreservesStartupFolder=$true
    }
}

function Test-Exp003Configuration {
    [CmdletBinding()]
    param([ValidateSet(0,1)][int]$ExpectedStartupBoost=1)
    $state=Get-Exp003State
    $mandatoryClear=-not $state.MandatoryPolicy.Exists
    $recommendedOk=($state.RecommendedPolicy.Exists -and [int]$state.RecommendedPolicy.Value -eq $ExpectedStartupBoost)
    [pscustomobject]@{Success=($mandatoryClear -and $recommendedOk);MandatoryPolicyClear=$mandatoryClear;RecommendedPolicyMatches=$recommendedOk;State=$state;Reason=if(-not $mandatoryClear){'Mandatory policy appeared'}elseif(-not $recommendedOk){'Recommended policy mismatch'}else{'Verified'}}
}

function Set-Exp003StartupBoost {
    [CmdletBinding(SupportsShouldProcess)]
    param([ValidateSet('Enable','Disable')][string]$StartupBoost='Enable',[Parameter(Mandatory)][string]$StatePath,[Parameter(Mandatory)][string]$LogPath)
    $support=Get-Exp003Support
    if (-not $support.Supported) { throw "Unsupported system: $($support.Reason)" }
    if (-not (Test-Path -LiteralPath $StatePath)) { Save-Exp003State -StatePath $StatePath | Out-Null }
    $desired=if($StartupBoost -eq 'Enable'){1}else{0}; $before=Get-Exp003State
    if ($PSCmdlet.ShouldProcess("$script:RecommendedPolicyPath\$script:PolicyName","Set recommended Startup Boost to $desired")) {
        New-Item -Path $script:RecommendedPolicyPath -Force | Out-Null
        New-ItemProperty -LiteralPath $script:RecommendedPolicyPath -Name $script:PolicyName -Value $desired -PropertyType DWord -Force | Out-Null
    }
    $verification=Test-Exp003Configuration -ExpectedStartupBoost $desired
    if (-not $verification.Success) { throw "EXP-003 verification failed: $($verification.Reason)" }
    Write-Exp003Log -Path $LogPath -Action 'Apply' -Data ([pscustomobject]@{Requested=$StartupBoost;Before=$before;Verification=$verification})
    $verification
}

function Restore-Exp003State {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$StatePath,[Parameter(Mandatory)][string]$LogPath)
    if (-not (Test-Path -LiteralPath $StatePath)) { throw "State file missing: $StatePath" }
    $saved=Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($saved.Experiment -ne 'EXP-003' -or [int]$saved.SchemaVersion -ne 1) { throw 'Rollback state identity mismatch' }
    $item=$saved.State.RecommendedPolicy
    if ($item.Path -ne $script:RecommendedPolicyPath -or $item.Name -ne $script:PolicyName) { throw 'Rollback registry identity mismatch' }
    if ($PSCmdlet.ShouldProcess("$($item.Path)\$($item.Name)",'Restore exact prior recommended policy state')) {
        if ($item.Exists) {
            New-Item -Path $item.Path -Force | Out-Null
            $kind=[Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind],[string]$item.Kind,$true)
            (Get-Item -LiteralPath $item.Path).SetValue([string]$item.Name,$item.Value,$kind)
        } elseif (Test-Path -LiteralPath $item.Path) { Remove-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue }
    }
    $after=Get-Exp003State
    $actual=$after.RecommendedPolicy
    $ok=([bool]$item.Exists -eq [bool]$actual.Exists)
    if ($item.Exists) { $ok=$ok -and ([string]$item.Value -eq [string]$actual.Value) -and ([string]$item.Kind -eq [string]$actual.Kind) }
    if (-not $ok) { throw 'Rollback verification failed' }
    Write-Exp003Log -Path $LogPath -Action 'Rollback' -Data $after
    [pscustomobject]@{Success=$true;State=$after}
}

function Test-Exp003RebootPersistence {[CmdletBinding()]param([ValidateSet(0,1)][int]$ExpectedStartupBoost=1) Test-Exp003Configuration -ExpectedStartupBoost $ExpectedStartupBoost}

Export-ModuleMember -Function @('Get-Exp003Support','Get-Exp003State','Save-Exp003State','Invoke-Exp003DryRun','Set-Exp003StartupBoost','Test-Exp003Configuration','Restore-Exp003State','Test-Exp003RebootPersistence')

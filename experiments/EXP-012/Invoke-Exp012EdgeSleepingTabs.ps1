[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Mode = 'Check',
    [string]$StatePath = "$PSScriptRoot\state.json",
    [string]$LogPath = "$PSScriptRoot\exp-012.jsonl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$MandatoryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$RecommendedPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
$ValueName = 'SleepingTabsEnabled'

function Write-ExpLog {
    param([string]$Action,[string]$Result,[hashtable]$Data=@{})
    $entry = [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-012'; action=$Action; result=$Result; data=$Data }
    $entry | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $LogPath -Encoding utf8
}

function Get-RegistryValueState {
    param([string]$Path,[string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{ pathExists=$false; valueExists=$false; value=$null; kind=$null } }
    $key = Get-Item -LiteralPath $Path
    try {
        $value = $key.GetValue($Name,$null,'DoNotExpandEnvironmentNames')
        $kind = $key.GetValueKind($Name).ToString()
        return [ordered]@{ pathExists=$true; valueExists=$true; value=$value; kind=$kind }
    } catch [System.ArgumentException] {
        return [ordered]@{ pathExists=$true; valueExists=$false; value=$null; kind=$null }
    }
}

function Get-SupportState {
    $os = Get-CimInstance Win32_OperatingSystem
    $system = Get-CimInstance Win32_ComputerSystem
    $edgeCandidates = @(
        "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ }
    $edgePath = $edgeCandidates | Select-Object -First 1
    $edgeVersion = if ($edgePath) { [version](Get-Item -LiteralPath $edgePath).VersionInfo.ProductVersion } else { $null }
    [ordered]@{
        manufacturer = [string]$system.Manufacturer
        windowsCaption = [string]$os.Caption
        windowsBuild = [string]$os.BuildNumber
        edgePath = $edgePath
        edgeVersion = if ($edgeVersion) { $edgeVersion.ToString() } else { $null }
        supported = ($system.Manufacturer -match 'HP|Hewlett-Packard') -and ($os.Caption -match 'Windows 11') -and $edgeVersion -and ($edgeVersion.Major -ge 88)
    }
}

function Assert-Supported {
    $support = Get-SupportState
    if (-not $support.supported) { throw 'EXP-012 supports HP systems running Windows 11 with Microsoft Edge 88 or later.' }
    $mandatory = Get-RegistryValueState -Path $MandatoryPath -Name $ValueName
    if ($mandatory.valueExists) { throw 'Mandatory enterprise SleepingTabsEnabled policy controls this setting; application refused.' }
    return $support
}

function Capture-State {
    $support = Assert-Supported
    $state = [ordered]@{
        schemaVersion = 1
        experiment = 'EXP-012'
        capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
        support = $support
        mandatory = Get-RegistryValueState -Path $MandatoryPath -Name $ValueName
        recommended = Get-RegistryValueState -Path $RecommendedPath -Name $ValueName
    }
    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $StatePath -Encoding utf8
    Write-ExpLog -Action 'Capture' -Result 'Success' -Data @{ statePath=$StatePath }
    return $state
}

function Apply-Change {
    $null = Assert-Supported
    if (-not (Test-Path -LiteralPath $StatePath)) { throw 'Original state file is required before Apply.' }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.experiment -ne 'EXP-012' -or $state.schemaVersion -ne 1) { throw 'State identity check failed.' }
    if ($PSCmdlet.ShouldProcess("$RecommendedPath\$ValueName",'Set REG_DWORD 1')) {
        New-Item -Path $RecommendedPath -Force | Out-Null
        New-ItemProperty -Path $RecommendedPath -Name $ValueName -PropertyType DWord -Value 1 -Force | Out-Null
    }
    $verify = Get-RegistryValueState -Path $RecommendedPath -Name $ValueName
    if (-not $verify.valueExists -or [int]$verify.value -ne 1 -or $verify.kind -ne 'DWord') { throw 'Application verification failed.' }
    Write-ExpLog -Action 'Apply' -Result 'Success' -Data @{ value=1 }
}

function Verify-Change {
    $null = Assert-Supported
    $state = Get-RegistryValueState -Path $RecommendedPath -Name $ValueName
    $ok = $state.valueExists -and ([int]$state.value -eq 1) -and ($state.kind -eq 'DWord')
    Write-ExpLog -Action 'Verify' -Result $(if($ok){'Success'}else{'Failed'}) -Data @{ current=$state }
    if (-not $ok) { throw 'Sleeping Tabs recommended policy verification failed.' }
    return $state
}

function Rollback-Change {
    $null = Assert-Supported
    if (-not (Test-Path -LiteralPath $StatePath)) { throw 'Original state file is required before Rollback.' }
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if ($state.experiment -ne 'EXP-012' -or $state.schemaVersion -ne 1) { throw 'State identity check failed.' }
    if ($PSCmdlet.ShouldProcess("$RecommendedPath\$ValueName",'Restore exact original state')) {
        if ($state.recommended.valueExists) {
            New-Item -Path $RecommendedPath -Force | Out-Null
            New-ItemProperty -Path $RecommendedPath -Name $ValueName -PropertyType $state.recommended.kind -Value $state.recommended.value -Force | Out-Null
        } else {
            Remove-ItemProperty -Path $RecommendedPath -Name $ValueName -ErrorAction SilentlyContinue
            if (-not $state.recommended.pathExists -and (Test-Path -LiteralPath $RecommendedPath)) {
                $key = Get-Item -LiteralPath $RecommendedPath
                if ($key.ValueCount -eq 0 -and $key.SubKeyCount -eq 0) { Remove-Item -LiteralPath $RecommendedPath -Force }
            }
        }
    }
    $current = Get-RegistryValueState -Path $RecommendedPath -Name $ValueName
    $restored = ($current.valueExists -eq [bool]$state.recommended.valueExists) -and ((-not $current.valueExists) -or (($current.value -eq $state.recommended.value) -and ($current.kind -eq $state.recommended.kind)))
    Write-ExpLog -Action 'Rollback' -Result $(if($restored){'Success'}else{'Failed'}) -Data @{ current=$current }
    if (-not $restored) { throw 'Exact rollback verification failed.' }
}

try {
    switch ($Mode) {
        'Check' { Get-SupportState }
        'Capture' { Capture-State }
        'DryRun' { $null = Assert-Supported; if (-not (Test-Path $StatePath)) { Capture-State | Out-Null }; Apply-Change -WhatIf }
        'Apply' { Apply-Change }
        'Verify' { Verify-Change }
        'VerifyReboot' { Verify-Change; Write-ExpLog -Action 'VerifyReboot' -Result 'Success' -Data @{ requirement='Run after reboot' } }
        'Rollback' { Rollback-Change }
    }
} catch {
    Write-ExpLog -Action $Mode -Result 'Failed' -Data @{ error=$_.Exception.Message }
    throw
}

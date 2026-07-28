[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath=(Join-Path $PSScriptRoot 'state.json'),
    [string]$LogPath=(Join-Path $PSScriptRoot 'events.jsonl')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:PolicyPath='HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$script:ValueName='HideFirstRunExperience'
function Write-ExpLog { param([string]$Event,[string]$Result,[hashtable]$Data=@{})
    $record=[ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-036';action=$Action;event=$Event;result=$Result;data=$Data}
    Add-Content -LiteralPath $LogPath -Value ($record|ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}
function Get-EdgePath {$paths=@("$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe");return @($paths|Where-Object{$_ -and (Test-Path -LiteralPath $_)})|Select-Object -First 1}
function Get-ManagementState {$joined=$false;$signals=@();try{$text=(& dsregcmd.exe /status 2>$null)-join "`n";foreach($name in @('AzureAdJoined','DomainJoined','WorkplaceJoined')){if($text -match "(?im)^\s*$name\s*:\s*YES\s*$"){$joined=$true;$signals+=$name}}}catch{};[pscustomobject]@{Managed=$joined;Signals=$signals}}
function Get-SupportState {
    $os=Get-CimInstance Win32_OperatingSystem;$computer=Get-CimInstance Win32_ComputerSystem;$edge=Get-EdgePath;$version=$null
    if($edge){$version=[version](Get-Item -LiteralPath $edge).VersionInfo.ProductVersion};$management=Get-ManagementState
    $admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $supported=([version]$os.Version).Major -ge 10 -and $os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett-Packard' -and $null -ne $edge -and $null -ne $version -and $version.Major -ge 80
    [pscustomobject]@{Supported=$supported;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$computer.Manufacturer;Model=$computer.Model;EdgePath=$edge;EdgeVersion=$(if($version){$version.ToString()}else{$null});Managed=$management.Managed;ManagementSignals=$management.Signals;Elevated=$admin}
}
function Get-PolicyState {$keyExists=Test-Path -LiteralPath $script:PolicyPath;$valueExists=$false;$data=$null;$kind=$null;if($keyExists){$key=Get-Item -LiteralPath $script:PolicyPath;$valueExists=$key.GetValueNames() -contains $script:ValueName;if($valueExists){$data=$key.GetValue($script:ValueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);$kind=$key.GetValueKind($script:ValueName).ToString()}};[pscustomobject]@{KeyExists=$keyExists;ValueExists=$valueExists;Data=$data;Kind=$kind}}
function Save-State($support,$policy){$state=[ordered]@{schemaVersion=1;experiment='EXP-036';capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;policyPath=$script:PolicyPath;valueName=$script:ValueName;edgePath=$support.EdgePath;edgeVersion=$support.EdgeVersion;keyExists=$policy.KeyExists;valueExists=$policy.ValueExists;data=$policy.Data;kind=$policy.Kind};$state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding UTF8;return $state}
function Read-State {if(-not(Test-Path -LiteralPath $StatePath)){throw "State file missing: $StatePath"};$state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;if($state.schemaVersion -ne 1 -or $state.experiment -ne 'EXP-036' -or $state.machine -ne $env:COMPUTERNAME -or $state.policyPath -ne $script:PolicyPath -or $state.valueName -ne $script:ValueName){throw 'State identity validation failed.'};return $state}
function Assert-ApplySafe($support,$policy){if(-not $support.Elevated){throw 'Elevation is required.'};if($support.Managed){throw ('Enterprise management detected: '+($support.ManagementSignals -join ', '))};if($policy.ValueExists){throw 'Existing HideFirstRunExperience policy value detected; refusing to override management or prior configuration.'}}
function Set-ExperimentPolicy {if($PSCmdlet.ShouldProcess("$($script:PolicyPath)::$($script:ValueName)",'Set REG_DWORD 1')){if(-not(Test-Path -LiteralPath $script:PolicyPath)){New-Item -Path $script:PolicyPath -Force|Out-Null};New-ItemProperty -LiteralPath $script:PolicyPath -Name $script:ValueName -PropertyType DWord -Value 1 -Force|Out-Null}}
function Test-Applied {$p=Get-PolicyState;return ($p.ValueExists -and $p.Kind -eq 'DWord' -and [int]$p.Data -eq 1)}
function Restore-State($state){$current=Get-PolicyState;if($state.valueExists){throw 'Captured state contains a pre-existing policy value; this experiment should never have applied.'};if($current.ValueExists -and -not($current.Kind -eq 'DWord' -and [int]$current.Data -eq 1)){throw 'Rollback refused because the policy value changed after application.'};if($current.ValueExists -and $PSCmdlet.ShouldProcess("$($script:PolicyPath)::$($script:ValueName)",'Remove experiment policy value')){Remove-ItemProperty -LiteralPath $script:PolicyPath -Name $script:ValueName -ErrorAction Stop};if(-not $state.keyExists -and (Test-Path -LiteralPath $script:PolicyPath)){if((Get-Item -LiteralPath $script:PolicyPath).ValueCount -eq 0 -and (Get-ChildItem -LiteralPath $script:PolicyPath -ErrorAction SilentlyContinue).Count -eq 0){if($PSCmdlet.ShouldProcess($script:PolicyPath,'Remove empty experiment-created key')){Remove-Item -LiteralPath $script:PolicyPath -Force}}}}
try {
    $support=Get-SupportState;Write-ExpLog 'support-detection' ($(if($support.Supported){'pass'}else{'unsupported'})) @{os=$support.OS;build=$support.Build;manufacturer=$support.Manufacturer;model=$support.Model;edgeVersion=$support.EdgeVersion;managed=$support.Managed;elevated=$support.Elevated};if(-not $support.Supported){throw 'EXP-036 supports HP systems running Windows 11 with Microsoft Edge 80 or later only.'}
    switch($Action){
        'Check' {$p=Get-PolicyState;[pscustomobject]@{Support=$support;Policy=$p}}
        'Capture' {$p=Get-PolicyState;$s=Save-State $support $p;Write-ExpLog 'state-capture' 'pass' @{statePath=$StatePath;valueExists=$p.ValueExists};$s}
        'DryRun' {$p=Get-PolicyState;if((Test-Path -LiteralPath $StatePath) -and (Test-Applied)){[void](Read-State);Write-ExpLog 'dry-run' 'pass' @{wouldChange=$false;alreadyApplied=$true};[pscustomobject]@{WouldChange=$false;AlreadyApplied=$true}}else{Assert-ApplySafe $support $p;Write-ExpLog 'dry-run' 'pass' @{wouldSet=1;restartRequired=$true};[pscustomobject]@{WouldSet="$($script:PolicyPath)::$($script:ValueName)";Data=1;RestartRequired=$true}}}
        'Apply' {$p=Get-PolicyState;if(Test-Path -LiteralPath $StatePath){$s=Read-State;if($s.valueExists){throw 'Captured state is ineligible for application.'};if(Test-Applied){Write-ExpLog 'apply' 'pass' @{changed=$false;alreadyApplied=$true};[pscustomobject]@{Applied=$true;Changed=$false;BrowserRestartRequired=$false};break};Assert-ApplySafe $support $p}else{Assert-ApplySafe $support $p;Save-State $support $p|Out-Null};Set-ExperimentPolicy;if(-not(Test-Applied)){throw 'Apply verification failed.'};Write-ExpLog 'apply' 'pass' @{changed=$true;value=1;browserRestartRequired=$true};[pscustomobject]@{Applied=$true;Changed=$true;BrowserRestartRequired=$true}}
        'Verify' {$ok=Test-Applied;Write-ExpLog 'verify' ($(if($ok){'pass'}else{'fail'})) @{browserRestartRequired=$true};if(-not $ok){throw 'Policy verification failed.'};$true}
        'VerifyReboot' {$ok=Test-Applied;Write-ExpLog 'verify-reboot' ($(if($ok){'pass'}else{'fail'})) @{bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime};if(-not $ok){throw 'Reboot persistence verification failed.'};$true}
        'Rollback' {$s=Read-State;Restore-State $s;$p=Get-PolicyState;$ok=(-not $p.ValueExists -and ($s.keyExists -or -not $p.KeyExists));Write-ExpLog 'rollback' ($(if($ok){'pass'}else{'fail'})) @{valueExists=$p.ValueExists;keyExists=$p.KeyExists};if(-not $ok){throw 'Rollback verification failed.'};[pscustomobject]@{RolledBack=$true}}
    }
}catch{Write-ExpLog 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}

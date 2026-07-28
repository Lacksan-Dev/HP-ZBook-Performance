[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action = 'Check',
    [string]$StatePath = (Join-Path $PSScriptRoot 'state.json'),
    [string]$LogPath = (Join-Path $PSScriptRoot 'events.jsonl')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RunPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:ProtectedTokens = @('omnissa','vmware horizon','windows app','remote desktop','mstsc','tailscale','windows security','securityhealth','defender','credential','bitlocker','firewall')
function Write-ExpLog { param([string]$Event,[string]$Result,[hashtable]$Data=@{})
    $record=[ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-035';action=$Action;event=$Event;result=$Result;data=$Data}
    Add-Content -LiteralPath $LogPath -Value ($record|ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}
function Get-SupportState {
    $os=Get-CimInstance Win32_OperatingSystem; $computer=Get-CimInstance Win32_ComputerSystem
    $supported=([version]$os.Version).Major -ge 10 -and $os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett-Packard'
    [pscustomobject]@{Supported=$supported;OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$computer.Manufacturer;Model=$computer.Model}
}
function Test-ProtectedIdentity([string]$Name,[string]$Command) {
    $identity=($Name+' '+$Command).ToLowerInvariant(); foreach($token in $script:ProtectedTokens){if($identity.Contains($token)){return $true}}; return $false
}
function Test-LogiBoltIdentity([string]$Name,[string]$Command) {
    if(Test-ProtectedIdentity $Name $Command){return $false}
    $nameMatch=$Name -match '(?i)^(Logi Bolt|LogiBolt|Logitech Bolt)$'
    $exeMatch=$Command -match '(?i)(^|[\\/" ])(?:LogiBolt|logi-bolt)\.exe(?:[" ]|$)'
    $launchMatch=$Command -match '(?i)(--background|--minimized|--startup|--tray|/background|/minimized|/startup|/tray)'
    $updaterOnly=$Command -match '(?i)updater|update\.exe'
    return ($nameMatch -and $exeMatch -and $launchMatch -and -not $updaterOnly)
}
function Get-RunCandidates {
    if(-not(Test-Path $script:RunPath)){return @()}; $key=Get-Item -LiteralPath $script:RunPath
    $items=foreach($name in $key.GetValueNames()){$value=[string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if(Test-LogiBoltIdentity $name $value){[pscustomobject]@{Path=$script:RunPath;Name=$name;Data=$value;Kind=$key.GetValueKind($name).ToString()}}}; return @($items)
}
function Save-State([object[]]$Candidates){
    if($Candidates.Count -gt 1){throw 'More than one eligible Logi Bolt Run registration was found.'}
    $state=[ordered]@{schemaVersion=1;experiment='EXP-035';capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value);entries=@($Candidates)}
    $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding UTF8; return $state
}
function Read-State {
    if(-not(Test-Path $StatePath)){throw "State file missing: $StatePath"};$state=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if($state.schemaVersion -ne 1 -or $state.experiment -ne 'EXP-035' -or $state.machine -ne $env:COMPUTERNAME -or $state.userSid -ne $sid){throw 'State identity validation failed.'};return $state
}
function Remove-Candidates([object[]]$Candidates){foreach($entry in $Candidates){if(-not(Test-LogiBoltIdentity $entry.Name $entry.Data)){throw "Candidate identity changed: $($entry.Name)"};if($PSCmdlet.ShouldProcess("$($entry.Path)::$($entry.Name)",'Remove Logi Bolt startup registration')){Remove-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue}}}
function Restore-State($State){foreach($entry in @($State.entries)){if(-not(Test-LogiBoltIdentity $entry.Name $entry.Data)){throw "Rollback state identity rejected: $($entry.Name)"};if(Get-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue){throw "Rollback refused because the registration already exists: $($entry.Name)"};if($PSCmdlet.ShouldProcess("$($entry.Path)::$($entry.Name)",'Restore Logi Bolt startup registration')){if(-not(Test-Path $entry.Path)){New-Item -Path $entry.Path -Force|Out-Null};$key=Get-Item -LiteralPath $entry.Path;$key.SetValue($entry.Name,[string]$entry.Data,[Microsoft.Win32.RegistryValueKind]::$($entry.Kind))}}}
function Test-Removed($State){foreach($entry in @($State.entries)){if(Get-ItemProperty -LiteralPath $entry.Path -Name $entry.Name -ErrorAction SilentlyContinue){return $false}};return $true}
function Test-Restored($State){foreach($entry in @($State.entries)){$key=Get-Item -LiteralPath $entry.Path -ErrorAction SilentlyContinue;if(-not $key){return $false};$actual=[string]$key.GetValue($entry.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if($actual -ne [string]$entry.Data -or $key.GetValueKind($entry.Name).ToString() -ne [string]$entry.Kind){return $false}};return $true}
try {
    $support=Get-SupportState;Write-ExpLog 'support-detection' ($(if($support.Supported){'pass'}else{'unsupported'})) @{os=$support.OS;build=$support.Build;manufacturer=$support.Manufacturer;model=$support.Model};if(-not $support.Supported){throw 'EXP-035 supports HP systems running Windows 11 only.'}
    switch($Action){
        'Check' {$c=Get-RunCandidates;Write-ExpLog 'candidate-inventory' 'pass' @{count=$c.Count;names=@($c.Name)};$c}
        'Capture' {$c=Get-RunCandidates;$s=Save-State $c;Write-ExpLog 'state-capture' 'pass' @{count=$c.Count;statePath=$StatePath};$s}
        'DryRun' {$c=Get-RunCandidates;if($c.Count -gt 1){throw 'Dry run found multiple eligible registrations.'};Write-ExpLog 'dry-run' 'pass' @{count=$c.Count;names=@($c.Name)};[pscustomobject]@{WouldRemove=@($c);StatePath=$StatePath}}
        'Apply' {$c=Get-RunCandidates;if(-not(Test-Path $StatePath)){Save-State $c|Out-Null}else{$saved=Read-State;foreach($current in $c){$match=@($saved.entries|Where-Object{$_.Name -eq $current.Name -and $_.Data -eq $current.Data -and $_.Kind -eq $current.Kind});if($match.Count -ne 1){throw "Current candidate differs from captured state: $($current.Name)"}}};Remove-Candidates $c;$s=Read-State;if(-not(Test-Removed $s)){throw 'Apply verification failed.'};Write-ExpLog 'apply' 'pass' @{removed=$c.Count};[pscustomobject]@{Applied=$true;Removed=$c.Count}}
        'Verify' {$s=Read-State;$ok=Test-Removed $s;Write-ExpLog 'verify' ($(if($ok){'pass'}else{'fail'})) @{};if(-not $ok){throw 'Removal verification failed.'};$true}
        'VerifyReboot' {$s=Read-State;$ok=Test-Removed $s;Write-ExpLog 'verify-reboot' ($(if($ok){'pass'}else{'fail'})) @{bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime};if(-not $ok){throw 'Reboot persistence verification failed.'};$true}
        'Rollback' {$s=Read-State;Restore-State $s;if(-not(Test-Restored $s)){throw 'Rollback verification failed.'};Write-ExpLog 'rollback' 'pass' @{restored=@($s.entries).Count};[pscustomobject]@{RolledBack=$true;Restored=@($s.entries).Count}}
    }
} catch {Write-ExpLog 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
    [string]$Action='Check',
    [string]$StatePath=(Join-Path $PSScriptRoot 'state.json'),
    [string]$LogPath=(Join-Path $PSScriptRoot 'events.jsonl')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:RunPath='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:ValueName='com.squirrel.Teams.Teams'
$script:ProtectedTokens=@('omnissa','vmware horizon','windows app','remote desktop','mstsc','tailscale','securityhealth','defender','credential','bitlocker','firewall')
function Write-ExpLog { param([string]$Event,[string]$Result,[hashtable]$Data=@{})
    $record=[ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-043';action=$Action;event=$Event;result=$Result;data=$Data}
    Add-Content -LiteralPath $LogPath -Value ($record|ConvertTo-Json -Compress -Depth 8) -Encoding UTF8
}
function Get-SupportState {
    $os=Get-CimInstance Win32_OperatingSystem; $computer=Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{Supported=([version]$os.Version).Major -ge 10 -and $os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett-Packard';OS=$os.Caption;Build=$os.BuildNumber;Manufacturer=$computer.Manufacturer;Model=$computer.Model}
}
function Test-ProtectedIdentity([string]$Name,[string]$Command){$identity=($Name+' '+$Command).ToLowerInvariant();foreach($token in $script:ProtectedTokens){if($identity.Contains($token)){return $true}};return $false}
function Test-ClassicTeamsIdentity([string]$Name,[string]$Command){
    if(Test-ProtectedIdentity $Name $Command){return $false}
    if($Name -cne $script:ValueName){return $false}
    $update=$Command -match '(?i)(^|[\\/" ])Update\.exe(?:[" ]|$)'
    $process=$Command -match '(?i)--processStart\s+["'']?Teams\.exe["'']?'
    $system=$Command -match '(?i)--process-start-args\s+["'']?--system-initiated["'']?'
    $newTeams=$Command -match '(?i)ms-teams\.exe|MSTeams_8wekyb3d8bbwe'
    return ($update -and $process -and $system -and -not $newTeams)
}
function Get-Candidate {
    if(-not(Test-Path $script:RunPath)){return @()};$key=Get-Item -LiteralPath $script:RunPath
    if($script:ValueName -notin $key.GetValueNames()){return @()}
    $value=[string]$key.GetValue($script:ValueName,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    if(-not(Test-ClassicTeamsIdentity $script:ValueName $value)){throw 'Classic Teams Run value exists but identity validation failed.'}
    return @([pscustomobject]@{Path=$script:RunPath;Name=$script:ValueName;Data=$value;Kind=$key.GetValueKind($script:ValueName).ToString()})
}
function Save-State([object[]]$Entries){
    $state=[ordered]@{schemaVersion=1;experiment='EXP-043';capturedUtc=(Get-Date).ToUniversalTime().ToString('o');machine=$env:COMPUTERNAME;userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value);entries=@($Entries)}
    $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding UTF8;return $state
}
function Read-State {if(-not(Test-Path $StatePath)){throw "State file missing: $StatePath"};$s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json;$sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value;if($s.schemaVersion -ne 1 -or $s.experiment -ne 'EXP-043' -or $s.machine -ne $env:COMPUTERNAME -or $s.userSid -ne $sid){throw 'State identity validation failed.'};return $s}
function Test-Removed($State){foreach($e in @($State.entries)){if(Get-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue){return $false}};return $true}
function Test-Restored($State){foreach($e in @($State.entries)){$k=Get-Item -LiteralPath $e.Path -ErrorAction SilentlyContinue;if(-not $k){return $false};$v=[string]$k.GetValue($e.Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames);if($v -ne [string]$e.Data -or $k.GetValueKind($e.Name).ToString() -ne [string]$e.Kind){return $false}};return $true}
try {
    $support=Get-SupportState;Write-ExpLog 'support-detection' ($(if($support.Supported){'pass'}else{'unsupported'})) @{os=$support.OS;build=$support.Build;manufacturer=$support.Manufacturer;model=$support.Model};if(-not $support.Supported){throw 'EXP-043 supports HP systems running Windows 11 only.'}
    switch($Action){
        'Check' {$c=Get-Candidate;Write-ExpLog 'candidate-inventory' 'pass' @{count=$c.Count;names=@($c.Name)};$c}
        'Capture' {$c=Get-Candidate;$s=Save-State $c;Write-ExpLog 'state-capture' 'pass' @{count=$c.Count;statePath=$StatePath};$s}
        'DryRun' {$c=Get-Candidate;Write-ExpLog 'dry-run' 'pass' @{count=$c.Count;names=@($c.Name)};[pscustomobject]@{WouldRemove=@($c);StatePath=$StatePath}}
        'Apply' {$c=Get-Candidate;if(-not(Test-Path $StatePath)){Save-State $c|Out-Null}else{$saved=Read-State;foreach($e in $c){$m=@($saved.entries|Where-Object{$_.Name -eq $e.Name -and $_.Data -eq $e.Data -and $_.Kind -eq $e.Kind});if($m.Count -ne 1){throw 'Current candidate differs from captured state.'}}};foreach($e in $c){if($PSCmdlet.ShouldProcess("$($e.Path)::$($e.Name)",'Remove classic Teams startup registration')){Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name}};$s=Read-State;if(-not(Test-Removed $s)){throw 'Apply verification failed.'};Write-ExpLog 'apply' 'pass' @{removed=$c.Count};[pscustomobject]@{Applied=$true;Removed=$c.Count}}
        'Verify' {$s=Read-State;$ok=Test-Removed $s;Write-ExpLog 'verify' ($(if($ok){'pass'}else{'fail'})) @{};if(-not $ok){throw 'Removal verification failed.'};$true}
        'VerifyReboot' {$s=Read-State;$ok=Test-Removed $s;Write-ExpLog 'verify-reboot' ($(if($ok){'pass'}else{'fail'})) @{bootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime};if(-not $ok){throw 'Reboot persistence verification failed.'};$true}
        'Rollback' {$s=Read-State;foreach($e in @($s.entries)){if(-not(Test-ClassicTeamsIdentity $e.Name $e.Data)){throw 'Rollback state identity rejected.'};if(Get-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue){throw 'Rollback refused because the registration already exists.'};if($PSCmdlet.ShouldProcess("$($e.Path)::$($e.Name)",'Restore classic Teams startup registration')){if(-not(Test-Path $e.Path)){New-Item -Path $e.Path -Force|Out-Null};(Get-Item -LiteralPath $e.Path).SetValue($e.Name,[string]$e.Data,[Microsoft.Win32.RegistryValueKind]::$($e.Kind))}};if(-not(Test-Restored $s)){throw 'Rollback verification failed.'};Write-ExpLog 'rollback' 'pass' @{restored=@($s.entries).Count};[pscustomobject]@{RolledBack=$true;Restored=@($s.entries).Count}}
    }
} catch {Write-ExpLog 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName};throw}

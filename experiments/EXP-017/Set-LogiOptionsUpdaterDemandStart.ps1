[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Check','DryRun','Apply','Verify','Rollback','VerifyRollback')]
    [string]$Mode = 'Check',
    [string]$StatePath = "$PSScriptRoot\state.json",
    [string]$LogPath = "$PSScriptRoot\events.jsonl"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$allowedNames = @('logioptionsplus_updater','LogiOptionsPlusUpdaterService')

function Write-Event([string]$Action,[string]$Result,[hashtable]$Data=@{}) {
    $record = [ordered]@{ timestampUtc=(Get-Date).ToUniversalTime().ToString('o'); experiment='EXP-017'; action=$Action; result=$Result; data=$Data }
    $record | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $LogPath -Encoding utf8
}
function Get-Support {
    $os = Get-CimInstance Win32_OperatingSystem
    $computer = Get-CimInstance Win32_ComputerSystem
    [pscustomobject]@{ Supported=($os.Caption -match 'Windows 11' -and $computer.Manufacturer -match 'HP|Hewlett'); OS=$os.Caption; Manufacturer=$computer.Manufacturer; Model=$computer.Model }
}
function Get-Candidate {
    $svc = Get-CimInstance Win32_Service | Where-Object { $allowedNames -contains $_.Name } | Select-Object -First 1
    if (-not $svc) { return $null }
    if ($svc.PathName -notmatch '(?i)logi.*options.*updat') { throw "Service identity refused: $($svc.Name) path '$($svc.PathName)'" }
    if ($svc.PathName -match '(?i)windows\\system32|defender|tailscale|omnissa|remote desktop|msrdc|windowsapp') { throw 'Protected service identity refused.' }
    $svc
}
function Save-State($svc) {
    if (Test-Path -LiteralPath $StatePath) { return Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json }
    $state = [ordered]@{ schemaVersion=1; serviceName=$svc.Name; displayName=$svc.DisplayName; pathName=$svc.PathName; startMode=$svc.StartMode; state=$svc.State; capturedUtc=(Get-Date).ToUniversalTime().ToString('o') }
    $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding utf8
    [pscustomobject]$state
}
function Assert-StateIdentity($state,$svc) {
    if ($state.schemaVersion -ne 1 -or $state.serviceName -ne $svc.Name -or $state.pathName -ne $svc.PathName) { throw 'Captured state identity mismatch.' }
}

$support = Get-Support
if (-not $support.Supported) { Write-Event 'Support' 'Unsupported' @{ support=$support }; throw 'EXP-017 supports HP systems running Windows 11.' }
$svc = Get-Candidate
if (-not $svc) { Write-Event $Mode 'NoCandidate'; return [pscustomobject]@{ Supported=$true; CandidatePresent=$false; Changed=$false } }

switch ($Mode) {
    'Check' { Write-Event 'Check' 'Supported' @{ service=$svc.Name; startMode=$svc.StartMode; state=$svc.State }; return $svc }
    'DryRun' { $state=Save-State $svc; Write-Event 'DryRun' 'WouldSetManual' @{ service=$svc.Name; originalStartMode=$state.startMode }; return $state }
    'Apply' {
        $state=Save-State $svc; Assert-StateIdentity $state $svc
        if ($svc.StartMode -eq 'Manual') { Write-Event 'Apply' 'AlreadyCompliant' @{ service=$svc.Name }; return $svc }
        if ($PSCmdlet.ShouldProcess($svc.Name,'Set service startup type to Manual')) { Set-Service -Name $svc.Name -StartupType Manual }
        $after=Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'"
        if ($after.StartMode -ne 'Manual') { throw 'Verification failed after application.' }
        Write-Event 'Apply' 'Changed' @{ service=$svc.Name; from=$state.startMode; to='Manual' }; return $after
    }
    'Verify' {
        $ok=((Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'").StartMode -eq 'Manual')
        Write-Event 'Verify' $(if($ok){'Pass'}else{'Fail'}) @{ service=$svc.Name; rebootPersistenceCheck=$true }
        if(-not $ok){throw 'Service startup mode is not Manual.'}; return $ok
    }
    'Rollback' {
        if(-not (Test-Path -LiteralPath $StatePath)){throw 'Rollback state is missing.'}
        $state=Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json; Assert-StateIdentity $state $svc
        $startup = switch($state.startMode){'Auto'{'Automatic'} 'Automatic'{'Automatic'} 'Manual'{'Manual'} 'Disabled'{'Disabled'} default{throw "Unsupported original mode $($state.startMode)"}}
        if($PSCmdlet.ShouldProcess($svc.Name,"Restore startup type $startup")){Set-Service -Name $svc.Name -StartupType $startup; if($state.state -eq 'Running' -and (Get-Service $svc.Name).Status -ne 'Running'){Start-Service $svc.Name}}
        Write-Event 'Rollback' 'Restored' @{ service=$svc.Name; startMode=$state.startMode; state=$state.state }
    }
    'VerifyRollback' {
        $state=Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json; Assert-StateIdentity $state $svc
        $current=Get-CimInstance Win32_Service -Filter "Name='$($svc.Name)'"; $modeOk=($current.StartMode -eq $state.startMode -or ($state.startMode -eq 'Auto' -and $current.StartMode -eq 'Auto')); $runOk=($state.state -ne 'Running' -or $current.State -eq 'Running')
        Write-Event 'VerifyRollback' $(if($modeOk -and $runOk){'Pass'}else{'Fail'}) @{ modeOk=$modeOk; runningStateOk=$runOk }
        if(-not($modeOk -and $runOk)){throw 'Rollback verification failed.'}; return $true
    }
}

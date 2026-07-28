[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [ValidateSet('Scan','Recommend','DryRun','Apply','Verify','VerifyReboot','Report','Rollback')]
    [string]$Action = 'Scan',
    [string]$Profile = 'InventoryOnly',
    [string]$ManifestPath = (Join-Path $PSScriptRoot 'lacksan.manifest.json'),
    [string]$TransactionRoot = (Join-Path $PSScriptRoot 'transactions'),
    [string]$TransactionId,
    [string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$transaction = $null

function Read-Manifest {
    if (-not (Test-Path -LiteralPath $ManifestPath)) { throw "Manifest missing: $ManifestPath" }
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1) { throw 'Unsupported controller manifest schema.' }
    $ids = @($manifest.providers | ForEach-Object id)
    if ($ids.Count -ne @($ids | Select-Object -Unique).Count) { throw 'Duplicate provider IDs are forbidden.' }
    foreach ($provider in $manifest.providers) {
        if ($provider.mode -notin @('ReadOnly','Reversible')) { throw "Unsupported provider mode: $($provider.id)" }
        if ([string]::IsNullOrWhiteSpace([string]$provider.script)) { throw "Provider script missing: $($provider.id)" }
    }
    $manifest
}

function Resolve-Profile($Manifest,[string]$Id) {
    $profileObject = @($Manifest.profiles | Where-Object id -eq $Id)
    if ($profileObject.Count -ne 1) { throw "Unknown or duplicate profile: $Id" }
    $providers = foreach ($providerId in @($profileObject[0].providers)) {
        $provider = @($Manifest.providers | Where-Object id -eq $providerId)
        if ($provider.Count -ne 1) { throw "Profile references unknown or duplicate provider: $providerId" }
        $provider[0]
    }
    $selectedIds = @($providers | ForEach-Object id)
    $requiredScopes = @('WindowsSecurity','WindowsUpdate','Recovery','EnterpriseManagement','DeviceCriticalDrivers','Omnissa','WindowsApp','RemoteDesktop','Tailscale')
    foreach ($provider in $providers) {
        foreach ($required in @($provider.requires)) {
            if ($required -notin $selectedIds) { throw "Provider $($provider.id) requires $required." }
        }
        foreach ($conflict in @($provider.conflicts)) {
            if ($conflict -in $selectedIds) { throw "Provider conflict: $($provider.id) conflicts with $conflict." }
        }
        foreach ($scope in $requiredScopes) {
            if ($scope -notin @($provider.protectedScopes)) { throw "Provider $($provider.id) lacks protected scope declaration: $scope" }
        }
    }
    [pscustomobject]@{Profile=$profileObject[0];Providers=@($providers)}
}

function New-Transaction([string]$ProfileId) {
    if (-not (Test-Path -LiteralPath $TransactionRoot)) { New-Item -ItemType Directory -Path $TransactionRoot -Force | Out-Null }
    $id = if ($TransactionId) { $TransactionId } else { (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') }
    $path = Join-Path $TransactionRoot $id
    if (Test-Path -LiteralPath $path) { throw "Transaction already exists: $id" }
    New-Item -ItemType Directory -Path (Join-Path $path 'state') -Force | Out-Null
    $journal = [ordered]@{
        schemaVersion=1;experiment='EXP-046';transactionId=$id;profile=$ProfileId
        machine=$env:COMPUTERNAME;userSid=([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
        createdUtc=(Get-Date).ToUniversalTime().ToString('o');status='Created';appliedProviders=@()
    }
    $journal | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $path 'transaction.json') -Encoding UTF8
    [pscustomobject]@{Id=$id;Path=$path;Journal=$journal}
}

function Open-Transaction([string]$Id) {
    if ([string]::IsNullOrWhiteSpace($Id)) { throw 'TransactionId is required for this action.' }
    $path = Join-Path $TransactionRoot $Id
    $journalPath = Join-Path $path 'transaction.json'
    if (-not (Test-Path -LiteralPath $journalPath)) { throw "Transaction missing: $Id" }
    $journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($journal.schemaVersion -ne 1 -or $journal.experiment -ne 'EXP-046' -or $journal.machine -ne $env:COMPUTERNAME -or $journal.userSid -ne $sid) { throw 'Transaction identity validation failed.' }
    [pscustomobject]@{Id=$Id;Path=$path;Journal=$journal}
}

function Save-Journal($Transaction) {
    $Transaction.Journal | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Transaction.Path 'transaction.json') -Encoding UTF8
}

function Write-ControllerLog($Transaction,[string]$Event,[string]$Result,[object]$Data) {
    $record = [ordered]@{timestampUtc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-046';transactionId=$Transaction.Id;action=$Action;event=$Event;result=$Result;data=$Data}
    Add-Content -LiteralPath (Join-Path $Transaction.Path 'events.jsonl') -Value ($record | ConvertTo-Json -Compress -Depth 12) -Encoding UTF8
}

function Invoke-Provider($Provider,[string]$ProviderAction,$Transaction) {
    $scriptPath = Join-Path $PSScriptRoot ([string]$Provider.script)
    if (-not (Test-Path -LiteralPath $scriptPath)) { throw "Provider script missing: $($Provider.id)" }
    $statePath = Join-Path (Join-Path $Transaction.Path 'state') ("$($Provider.id).json")
    & $scriptPath -Action $ProviderAction -StatePath $statePath -LogPath (Join-Path $Transaction.Path 'events.jsonl')
}

function Get-Reversed([object[]]$Items) {
    $copy = @($Items)
    [array]::Reverse($copy)
    $copy
}

try {
    $manifest = Read-Manifest
    $selection = Resolve-Profile $manifest $Profile
    if ($Action -in @('Scan','Recommend','DryRun','Apply')) {
        $transaction = New-Transaction $Profile
    } else {
        $transaction = Open-Transaction $TransactionId
        $selection = Resolve-Profile $manifest ([string]$transaction.Journal.profile)
    }

    switch ($Action) {
        'Scan' {
            $results = foreach ($provider in $selection.Providers) { Invoke-Provider $provider 'Check' $transaction }
            $transaction.Journal.status='Scanned';Save-Journal $transaction;Write-ControllerLog $transaction 'scan' 'pass' @{providers=@($selection.Providers.id)}
            [pscustomobject]@{TransactionId=$transaction.Id;Profile=$Profile;Results=@($results)}
        }
        'Recommend' {
            $items = foreach ($provider in $selection.Providers) { [pscustomobject]@{Provider=$provider.id;Mode=$provider.mode;Recommended=$true;Reason='Profile-selected and manifest-compatible';RebootRequired=[bool]$provider.rebootRequired} }
            $transaction.Journal.status='Recommended';Save-Journal $transaction;Write-ControllerLog $transaction 'recommend' 'pass' @{count=@($items).Count}
            [pscustomobject]@{TransactionId=$transaction.Id;Profile=$Profile;Recommendations=@($items)}
        }
        'DryRun' {
            $items = foreach ($provider in $selection.Providers) { Invoke-Provider $provider 'DryRun' $transaction }
            $transaction.Journal.status='DryRunComplete';Save-Journal $transaction;Write-ControllerLog $transaction 'dry-run' 'pass' @{providers=@($selection.Providers.id)}
            [pscustomobject]@{TransactionId=$transaction.Id;Profile=$Profile;Preview=@($items)}
        }
        'Apply' {
            foreach ($provider in $selection.Providers) { Invoke-Provider $provider 'Capture' $transaction | Out-Null }
            $applied = [System.Collections.Generic.List[string]]::new()
            try {
                foreach ($provider in $selection.Providers) {
                    if ($PSCmdlet.ShouldProcess($provider.id,'Apply Lacksan provider')) {
                        Invoke-Provider $provider 'Apply' $transaction | Out-Null
                        $applied.Add([string]$provider.id)
                    }
                }
            } catch {
                foreach ($providerId in Get-Reversed @($applied.ToArray())) {
                    $provider=@($selection.Providers|Where-Object id -eq $providerId)[0]
                    Invoke-Provider $provider 'Rollback' $transaction | Out-Null
                }
                throw
            }
            $transaction.Journal.appliedProviders=@($applied.ToArray());$transaction.Journal.status='Applied';Save-Journal $transaction;Write-ControllerLog $transaction 'apply' 'pass' @{providers=@($applied.ToArray())}
            [pscustomobject]@{TransactionId=$transaction.Id;Profile=$Profile;AppliedProviders=@($applied.ToArray())}
        }
        'Verify' {
            foreach ($providerId in @($transaction.Journal.appliedProviders)) { $provider=@($selection.Providers|Where-Object id -eq $providerId)[0];Invoke-Provider $provider 'Verify' $transaction|Out-Null }
            $transaction.Journal.status='Verified';Save-Journal $transaction;Write-ControllerLog $transaction 'verify' 'pass' @{providers=@($transaction.Journal.appliedProviders)};$true
        }
        'VerifyReboot' {
            foreach ($providerId in @($transaction.Journal.appliedProviders)) { $provider=@($selection.Providers|Where-Object id -eq $providerId)[0];Invoke-Provider $provider 'VerifyReboot' $transaction|Out-Null }
            $transaction.Journal.status='RebootVerified';Save-Journal $transaction;Write-ControllerLog $transaction 'verify-reboot' 'pass' @{providers=@($transaction.Journal.appliedProviders)};$true
        }
        'Report' {
            $output = if ($ReportPath) { $ReportPath } else { Join-Path $transaction.Path 'report.json' }
            $safeReport=[ordered]@{schemaVersion=1;experiment='EXP-046';transactionId=$transaction.Id;profile=$transaction.Journal.profile;status=$transaction.Journal.status;createdUtc=$transaction.Journal.createdUtc;generatedUtc=(Get-Date).ToUniversalTime().ToString('o');appliedProviders=@($transaction.Journal.appliedProviders);physicalEvidence='needs-evidence'}
            $safeReport|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $output -Encoding UTF8;Write-ControllerLog $transaction 'report' 'pass' @{path=$output};Get-Item -LiteralPath $output
        }
        'Rollback' {
            foreach ($providerId in Get-Reversed @($transaction.Journal.appliedProviders)) {
                $provider=@($selection.Providers|Where-Object id -eq $providerId)[0]
                if ($PSCmdlet.ShouldProcess($provider.id,'Rollback Lacksan provider')) { Invoke-Provider $provider 'Rollback' $transaction|Out-Null }
            }
            $transaction.Journal.status='RolledBack';Save-Journal $transaction;Write-ControllerLog $transaction 'rollback' 'pass' @{providers=@($transaction.Journal.appliedProviders)};[pscustomobject]@{TransactionId=$transaction.Id;RolledBack=$true}
        }
    }
} catch {
    if ($null -ne $transaction) { Write-ControllerLog $transaction 'failure' 'fail' @{message=$_.Exception.Message;type=$_.Exception.GetType().FullName} }
    throw
}

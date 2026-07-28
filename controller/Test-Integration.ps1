[CmdletBinding()]
param([string]$OutputRoot = (Join-Path $env:TEMP 'Lacksan-EXP-046-Integration'))
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$controller = Join-Path $PSScriptRoot 'Invoke-LacksanController.ps1'
$manifest = Join-Path $PSScriptRoot 'lacksan.manifest.json'
$transactionRoot = Join-Path $OutputRoot 'transactions'

if (Test-Path -LiteralPath $OutputRoot) { Remove-Item -LiteralPath $OutputRoot -Recurse -Force }
New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null

$errors = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile($controller,[ref]$tokens,[ref]$errors) | Out-Null
if (@($errors).Count -gt 0) { throw ($errors | ForEach-Object Message | Out-String) }

$manifestObject = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if ($manifestObject.schemaVersion -ne 1) { throw 'Manifest schema check failed.' }
if (@($manifestObject.providers | Where-Object mode -notin @('ReadOnly','Reversible')).Count -gt 0) { throw 'Manifest provider mode check failed.' }

$result = & $controller -Action DryRun -Profile InventoryOnly -TransactionRoot $transactionRoot -Confirm:$false
if (-not $result.TransactionId) { throw 'Dry-run transaction ID missing.' }
$journalPath = Join-Path (Join-Path $transactionRoot $result.TransactionId) 'transaction.json'
$logPath = Join-Path (Join-Path $transactionRoot $result.TransactionId) 'events.jsonl'
if (-not (Test-Path -LiteralPath $journalPath)) { throw 'Transaction journal missing.' }
if (-not (Test-Path -LiteralPath $logPath)) { throw 'Structured log missing.' }
$journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
if ($journal.status -ne 'DryRunComplete') { throw 'Dry-run journal status failed.' }

[pscustomobject]@{
    Passed = $true
    Experiment = 'EXP-046'
    TransactionId = $result.TransactionId
    MutationCount = 0
    Journal = $journalPath
    Log = $logPath
}

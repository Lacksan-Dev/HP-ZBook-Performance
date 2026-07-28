[CmdletBinding()]
param()
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$script=Join-Path $PSScriptRoot 'Invoke-Exp030HpPrintScanDoctorService.ps1'
if(-not(Test-Path -LiteralPath $script)){throw 'Experiment script missing'}
$errors=$null
$tokens=[System.Management.Automation.PSParser]::Tokenize((Get-Content -LiteralPath $script -Raw),[ref]$errors)
if($errors.Count -gt 0){throw ($errors|Out-String)}
$text=Get-Content -LiteralPath $script -Raw
foreach($required in 'HPPrintScanDoctorService','DryRun','VerifyReboot','Rollback','ShouldProcess','events.jsonl','state.json'){
  if($text -notmatch [regex]::Escape($required)){throw "Missing contract token: $required"}
}
foreach($protected in "ServiceName='Spooler'","ServiceName='WinDefend'","ServiceName='wuauserv'","ServiceName='Tailscale'"){
  if($text -match [regex]::Escape($protected)){throw "Protected service target detected: $protected"}
}
[pscustomobject]@{experiment='EXP-030';syntax='pass';contract='pass';destructiveOperationsExecuted=$false}

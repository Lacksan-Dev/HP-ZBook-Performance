[CmdletBinding()]
param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Invoke-Exp026HpDiags.ps1'))

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $ScriptPath)){throw 'Experiment script missing'}
$text=Get-Content -LiteralPath $ScriptPath -Raw

$required=@(
  "ServiceName='HPDiagsCap'",
  'SupportsShouldProcess',
  "'DryRun'",
  "'VerifyReboot'",
  "'Rollback'",
  'ConvertTo-Json -Compress',
  'Rollback verification failed'
)
foreach($token in $required){if($text -notmatch [regex]::Escape($token)){throw "Required contract token missing: $token"}}

$forbidden=@('Uninstall-Package','Remove-AppxPackage','Disable-PnpDevice','pnputil','sc.exe delete','Remove-Item')
foreach($token in $forbidden){if($text -match [regex]::Escape($token)){throw "Destructive token found: $token"}}

[pscustomobject]@{experiment='EXP-026';staticContract=$true;destructiveCommands=$false;checkedUtc=(Get-Date).ToUniversalTime().ToString('o')}

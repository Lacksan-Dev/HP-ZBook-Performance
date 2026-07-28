[CmdletBinding()]
param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Invoke-LogiBoltRunCalibration.ps1'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ScriptPath)){throw "Missing experiment script: $ScriptPath"}
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$tokens,[ref]$errors)
if($errors.Count -gt 0){throw ('PowerShell parse failed: '+(($errors|ForEach-Object Message)-join '; '))}
$source=Get-Content -LiteralPath $ScriptPath -Raw
$required=@('SupportsShouldProcess=$true',"'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'",'DoNotExpandEnvironmentNames','Test-LogiBoltIdentity','ConvertTo-Json -Compress','Rollback refused because the registration already exists')
foreach($item in $required){if(-not $source.Contains($item)){throw "Required contract token missing: $item"}}
$forbidden=@('Remove-AppxPackage','Uninstall-Package','Set-Service','Disable-ScheduledTask','Unregister-ScheduledTask','pnputil','devcon')
foreach($item in $forbidden){if($source.Contains($item)){throw "Out-of-scope operation found: $item"}}
[pscustomobject]@{Experiment='EXP-035';ParsePassed=$true;ContractTokens=$required.Count;ForbiddenOperationsFound=0;LiveChangesApplied=$false}

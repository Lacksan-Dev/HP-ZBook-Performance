[CmdletBinding()]param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Invoke-EdgeBackgroundModePolicy.ps1'))
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ScriptPath)){throw "Missing experiment script: $ScriptPath"}
$tokens=$null;$errors=$null;[void][System.Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$tokens,[ref]$errors)
if($errors.Count-gt 0){throw ('PowerShell parse failed: '+(($errors|ForEach-Object Message)-join'; '))}
$source=Get-Content -LiteralPath $ScriptPath -Raw
$required=@('SupportsShouldProcess=$true','BackgroundModeEnabled','RecommendedPath','PropertyType DWord -Value 0','Get-ManagementState','DoNotExpandEnvironmentNames','ConvertTo-Json -Compress','VerifyReboot','Rollback verification failed')
foreach($item in $required){if(-not$source.Contains($item)){throw "Required contract token missing: $item"}}
$forbidden=@('Remove-AppxPackage','Uninstall-Package','Set-Service','Stop-Service','Disable-ScheduledTask','Unregister-ScheduledTask','Clear-BrowsingData','pnputil','devcon','Remove-ItemProperty -LiteralPath $script:MandatoryPath')
foreach($item in $forbidden){if($source.Contains($item)){throw "Out-of-scope operation found: $item"}}
[pscustomobject]@{Experiment='EXP-037';ParsePassed=$true;ContractTokens=$required.Count;ForbiddenOperationsFound=0;LiveChangesApplied=$false}
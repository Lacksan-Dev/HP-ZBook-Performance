[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$scriptPath=Join-Path $PSScriptRoot 'Invoke-ClassicTeamsRunCalibration.ps1'
if(-not(Test-Path $scriptPath)){throw 'Experiment script missing.'}
$parseErrors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$null,[ref]$parseErrors)
if($parseErrors.Count -gt 0){throw ($parseErrors|ForEach-Object Message|Out-String)}
$source=Get-Content -LiteralPath $scriptPath -Raw
$required=@('SupportsShouldProcess','Get-SupportState','Save-State','Read-State','DryRun','VerifyReboot','Rollback','Write-ExpLog','DoNotExpandEnvironmentNames','com.squirrel.Teams.Teams')
foreach($token in $required){if($source -notmatch [regex]::Escape($token)){throw "Missing contract token: $token"}}
if($source -match '(?i)Remove-AppxPackage|Uninstall|sc\.exe\s+delete|Disable-WindowsOptionalFeature'){throw 'Destructive operation detected.'}
[pscustomobject]@{Passed=$true;Mode='read-only';Script=$scriptPath;Checks=$required.Count}

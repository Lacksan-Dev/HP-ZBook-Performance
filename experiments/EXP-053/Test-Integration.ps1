[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$provider=Join-Path $root 'controller/providers/LogitechGHubRun.ps1'
$manifest=Join-Path $root 'controller/lacksan.manifest.json'
if(-not(Test-Path $provider)){throw'Missing Logitech G Hub provider.'}
if(-not(Test-Path $manifest)){throw'Missing controller manifest.'}
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)
if($errors.Count-ne 0){throw'Provider parser check failed.'}
$data=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
if(@($data.profiles|Where-Object id -eq 'LogitechGHubDemandLaunch').Count-ne 1){throw'Profile registration missing.'}
if(@($data.providers|Where-Object id -eq 'logitech-ghub-run').Count-ne 1){throw'Provider registration missing.'}
$content=Get-Content -LiteralPath $provider -Raw
foreach($required in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback','DoNotExpandEnvironmentNames','Rollback refused','Write-ProviderLog')){if($content-notmatch[regex]::Escape($required)){throw"Missing contract token: $required"}}
if($content-match'Remove-AppxPackage|Uninstall-Package|Remove-Service|pnputil|Set-MpPreference'){throw'Forbidden mutation detected.'}
'EXP-053 zero-mutation integration check passed.'

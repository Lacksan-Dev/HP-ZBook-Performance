[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$manifestPath=Join-Path $root 'controller/lacksan.manifest.json'
$providerPath=Join-Path $root 'controller/providers/EdgeStartupBoostPolicy.ps1'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$profile=@($manifest.profiles|Where-Object id -eq 'EdgeTrueDemandLaunch')
if($profile.Count-ne 1){throw'EdgeTrueDemandLaunch profile registration missing or duplicated.'}
$provider=@($manifest.providers|Where-Object id -eq 'edge-startup-boost-policy')
if($provider.Count-ne 1){throw'edge-startup-boost-policy provider registration missing or duplicated.'}
if(-not(Test-Path -LiteralPath $providerPath)){throw'Edge provider script missing.'}
$before=Get-FileHash -LiteralPath $providerPath -Algorithm SHA256
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors)
if($errors.Count-ne 0){throw('Provider parse errors: '+(($errors.Message)-join'; '))}
$content=Get-Content -LiteralPath $providerPath -Raw
foreach($required in @('Get-SupportState','Save-State','DryRun','Apply','Verify','VerifyReboot','Rollback','StartupBoostEnabled','Enterprise management detected','Rollback refused')){if($content-notmatch[regex]::Escape($required)){throw"Missing contract token: $required"}}
foreach($forbidden in @('Remove-AppxPackage','Uninstall-Package','Remove-Service','Stop-Service','Set-MpPreference')){if($content-match[regex]::Escape($forbidden)){throw"Forbidden mutation token found: $forbidden"}}
$after=Get-FileHash -LiteralPath $providerPath -Algorithm SHA256
if($before.Hash-ne$after.Hash){throw'Integration check changed the provider file.'}
[pscustomobject]@{Experiment='EXP-054';Profile='EdgeTrueDemandLaunch';Provider='edge-startup-boost-policy';MutationCount=0;Result='pass'}

[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repoRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$manifestPath=Join-Path $repoRoot 'controller/lacksan.manifest.json'
$providerPath=Join-Path $repoRoot 'controller/providers/LogiBoltRun.ps1'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$profile=@($manifest.profiles|Where-Object id -eq 'LogiBoltDemandLaunch')
if($profile.Count-ne 1){throw'LogiBoltDemandLaunch profile registration missing or duplicated.'}
$provider=@($manifest.providers|Where-Object id -eq 'logi-bolt-run')
if($provider.Count-ne 1){throw'logi-bolt-run provider registration missing or duplicated.'}
if(-not(Test-Path -LiteralPath $providerPath)){throw'Logi Bolt provider script missing.'}
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$errors)
if($errors.Count-ne 0){throw("Provider parser errors: "+(($errors|ForEach-Object Message)-join'; '))}
$content=Get-Content -LiteralPath $providerPath -Raw
foreach($required in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback','DoNotExpandEnvironmentNames','Rollback refused')){if($content-notmatch[regex]::Escape($required)){throw"Provider contract token missing: $required"}}
foreach($forbidden in @('Remove-AppxPackage','Uninstall-Package','Remove-Service','pnputil','Set-MpPreference')){if($content-match[regex]::Escape($forbidden)){throw"Forbidden mutation token found: $forbidden"}}
[pscustomobject]@{Experiment='EXP-051';Result='Pass';MutationPerformed=$false;Profile='LogiBoltDemandLaunch';Provider='logi-bolt-run'}

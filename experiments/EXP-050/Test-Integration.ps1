[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$provider=Join-Path $root 'controller/providers/LogiOptionsPlusRun.ps1'
$manifest=Join-Path $root 'controller/lacksan.manifest.json'
if(-not(Test-Path $provider)){throw'Missing Logi Options+ provider.'}
if(-not(Test-Path $manifest)){throw'Missing controller manifest.'}
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)
if($errors.Count-ne 0){throw'Provider parser check failed.'}
$data=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
if(@($data.profiles|Where-Object id -eq 'LogiOptionsPlusDemandLaunch').Count-ne 1){throw'Profile registration missing.'}
$content=Get-Content -LiteralPath $provider -Raw
foreach($required in @('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback','DoNotExpandEnvironmentNames','Remove-ItemProperty','SetValue','Write-ProviderLog')){if($content-notmatch[regex]::Escape($required)){throw"Missing contract token: $required"}}
foreach($forbidden in @('Remove-AppxPackage','Uninstall-Package','Remove-Service','pnputil','Set-MpPreference')){if($content-match[regex]::Escape($forbidden)){throw"Forbidden mutation token: $forbidden"}}
[pscustomobject]@{Experiment='EXP-050';Result='Pass';MutationPerformed=$false;Provider='logi-options-plus-run'}

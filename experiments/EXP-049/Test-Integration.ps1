[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Resolve-Path (Join-Path $PSScriptRoot '../..')
$provider=Join-Path $root 'controller/providers/ClassicTeamsRun.ps1'
$manifest=Join-Path $root 'controller/lacksan.manifest.json'
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)
if(@($errors).Count-ne 0){throw'Provider syntax validation failed.'}
$m=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
$p=@($m.providers|Where-Object id -eq 'classic-teams-run')
if($p.Count-ne 1-or$p[0].mode-ne'Reversible'){throw'Manifest provider validation failed.'}
$profile=@($m.profiles|Where-Object id -eq 'ClassicTeamsDemandLaunch')
if($profile.Count-ne 1-or@($profile[0].providers)-notcontains'classic-teams-run'){throw'Profile validation failed.'}
[pscustomobject]@{Passed=$true;Experiment='EXP-049';MutationCount=0;Provider=$provider;Manifest=$manifest}

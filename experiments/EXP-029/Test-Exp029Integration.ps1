[CmdletBinding()]
param()
$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp029OfficeAnimations.ps1'
if(-not(Test-Path -LiteralPath $scriptPath)){throw 'Implementation missing'}
$tokens=$null;$errors=$null
[System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)|Out-Null
if($errors.Count -gt 0){throw ($errors|ForEach-Object Message|Out-String)}
$text=Get-Content -LiteralPath $scriptPath -Raw
$required=@('DisableAnimations','DryRun','VerifyReboot','Rollback','ShouldProcess','state-captured','reboot-verified','rolled-back','Enterprise Office policy controls')
foreach($token in $required){if($text -notmatch [regex]::Escape($token)){throw "Required contract token missing: $token"}}
$forbidden=@('Remove-AppxPackage','Uninstall-Package','Disable-PnpDevice','pnputil','sc.exe delete','Stop-Service','Set-Service','Disable-ScheduledTask')
foreach($token in $forbidden){if($text -match [regex]::Escape($token)){throw "Forbidden destructive token present: $token"}}
[pscustomobject]@{experiment='EXP-029';parse='pass';contract='pass';destructiveActions='absent'}

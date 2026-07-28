[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$scriptPath=Join-Path $PSScriptRoot 'Invoke-OneDriveRunCalibration.ps1'
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|ForEach-Object Message|Out-String)}
$source=Get-Content -LiteralPath $scriptPath -Raw
foreach($required in @('SupportsShouldProcess','DoNotExpandEnvironmentNames','VerifyReboot','Rollback','Test-OneDriveIdentity','OneDriveStandaloneUpdater')){if($source-notmatch[regex]::Escape($required)){throw "Missing contract token: $required"}}
foreach($forbidden in @('Remove-AppxPackage','Uninstall-Package','Set-Service','Disable-ScheduledTask','Unregister-ScheduledTask','pnputil','devcon')){if($source-match[regex]::Escape($forbidden)){throw "Forbidden operation present: $forbidden"}}
[pscustomobject]@{Experiment='EXP-045';Parse='Pass';Contract='Pass';DestructiveOperations='Absent'}

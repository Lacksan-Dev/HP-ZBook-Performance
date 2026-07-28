[CmdletBinding()]
param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Invoke-EdgeSleepingTabsPolicy.ps1'))
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $ScriptPath)){throw "Missing script: $ScriptPath"}
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|ForEach-Object Message|Out-String)}
$source=Get-Content -LiteralPath $ScriptPath -Raw
foreach($required in @('SleepingTabsEnabled','Recommended','DryRun','VerifyReboot','Rollback','Write-ExpLog','State identity validation failed')) {
    if(-not$source.Contains($required)){throw "Missing required contract token: $required"}
}
foreach($forbidden in @('Remove-AppxPackage','Uninstall-Package','Set-Service','Stop-Service','Disable-ScheduledTask','Unregister-ScheduledTask','pnputil','devcon')) {
    if($source.Contains($forbidden)){throw "Forbidden operation present: $forbidden"}
}
[pscustomobject]@{Experiment='EXP-039';Parse='pass';Lifecycle='pass';ProtectedScope='pass';WritesPerformed=$false}

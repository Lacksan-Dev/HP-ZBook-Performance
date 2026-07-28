[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$scriptPath=Join-Path $PSScriptRoot 'Invoke-EdgePerformanceDetectorPolicy.ps1'
$tokens=$null;$errors=$null
[void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ('PowerShell parse errors: '+(($errors|ForEach-Object Message)-join'; '))}
$source=Get-Content -LiteralPath $scriptPath -Raw
foreach($required in @('PerformanceDetectorEnabled','Recommended','DryRun','VerifyReboot','Rollback','ConvertTo-Json -Compress','TreatmentValue=0')){
    if(-not $source.Contains($required)){throw "Missing required contract token: $required"}
}
foreach($forbidden in @('Remove-AppxPackage','Uninstall-Package','Set-Service','Stop-Service','Disable-ScheduledTask','Unregister-ScheduledTask','pnputil','devcon')){
    if($source.Contains($forbidden)){throw "Forbidden operation found: $forbidden"}
}
[pscustomobject]@{Experiment='EXP-042';Parse='Pass';Contract='Pass';DestructiveOperations='Absent'}

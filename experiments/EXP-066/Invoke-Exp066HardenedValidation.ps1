[CmdletBinding(SupportsShouldProcess=$true)]
param(
 [ValidateSet('Start','Continue','Status','Summarize','Stop')][string]$Action='Status',
 [ValidateRange(1,20)][int]$RunsPerArm=5,
 [ValidateRange(30,600)][int]$SampleSeconds=120,
 [ValidateRange(1,10)][int]$SampleIntervalSeconds=2,
 [switch]$AllowAutomaticReboot,
 [string]$EvidenceRoot="$PSScriptRoot\lab-evidence",
 [string]$RunDirectory
)
Set-StrictMode -Version Latest
$harness=Join-Path $PSScriptRoot 'Invoke-Exp066LabHarness.ps1'
$provider=Join-Path $PSScriptRoot '..\..\controller\providers\HpNetworkHsaManualDemandStart.ps1'
if(!(Test-Path -LiteralPath $harness)){throw 'EXP-066 lab harness missing.'}
if(!(Test-Path -LiteralPath $provider)){throw 'Hardened EXP-066 provider missing.'}
$args=@{Action=$Action;RunsPerArm=$RunsPerArm;SampleSeconds=$SampleSeconds;SampleIntervalSeconds=$SampleIntervalSeconds;EvidenceRoot=$EvidenceRoot;ControllerPath=$provider}
if($RunDirectory){$args.RunDirectory=$RunDirectory}
if($AllowAutomaticReboot){$args.AllowAutomaticReboot=$true}
if($WhatIfPreference){$args.WhatIf=$true}
& $harness @args
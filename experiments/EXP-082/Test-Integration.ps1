[CmdletBinding()]
param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Invoke-WindowsSearchWebPolicyCalibration.ps1'))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

# Zero-mutation integration path. Run in an elevated Windows PowerShell session on a supported HP Windows 11 test system.
& $ScriptPath -Action Check
& $ScriptPath -Action DryRun -WhatIf

Write-Host 'Zero-mutation integration completed. Review events.jsonl and confirm that no registry value changed.'
Write-Host 'Physical validation remains needs-evidence: capture five matched baseline and treatment runs, SearchHost resource activity, local app/setting/file/indexed-content behavior, Outlook readiness, protected remote-access readiness, reboot persistence, and exact rollback.'
Write-Host 'For the mutation phase, use Capture, Apply, Verify, restart the Search UI or sign out, VerifyReboot after reboot, then Rollback and verify local Search behavior again.'

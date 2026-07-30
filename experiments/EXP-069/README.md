# EXP-069: HP Insights Analytics Manual demand-start

## Candidate

Change only `HPTouchpointAnalyticsService` from Automatic or Automatic (Delayed Start) to Manual. Preserve its running state during application. Restore the captured startup mode, delayed-start value, and running state during rollback.

## Safety boundary

The provider requires an HP Windows 11 system, elevation, one exact HP Insights or HP Touchpoint Analytics service, `TouchpointAnalyticsClientService.exe`, a valid HP publisher signature, zero dependencies and dependents, no enterprise service-policy ownership, and no active HP Insights or Touchpoint Analytics client process.

It changes no packages, files, scheduled tasks, devices, drivers, firmware, security controls, update components, recovery settings, enterprise-management settings, network configuration, or protected remote-access applications.

## Zero-mutation integration checks

Run from an elevated PowerShell session on the intended HP validation system:

```powershell
$provider = '.\controller\providers\HPInsightsAnalyticsService.ps1'
$state = Join-Path $env:TEMP 'EXP-069-state.json'
$log = Join-Path $env:TEMP 'EXP-069-log.jsonl'

& $provider -Action Check -StatePath $state -LogPath $log
& $provider -Action DryRun -StatePath $state -LogPath $log
& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf

Invoke-Pester .\controller\tests\EXP-069.HPInsightsAnalyticsService.Tests.ps1
```

Confirm that Check and DryRun make zero service changes, `-WhatIf` makes zero service changes, every JSONL line parses independently, and unsupported or ambiguous systems terminate before mutation.

## Physical validation

1. Record device model, BIOS, Windows build, service identity, executable version and SHA-256, power source, thermal state, and benchmark conditions.
2. Capture five matched baseline sign-in trials with sign-in-to-usable-desktop time and first-120-second CPU and disk activity.
3. Run Capture, DryRun, Apply, and Verify.
4. Confirm the service remains in its pre-application running state and HP Insights launches or demand-starts correctly when requested.
5. Reboot and run VerifyReboot.
6. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
7. Capture five matched treatment trials and report medians without discarding failed or inconclusive runs.
8. Run Rollback and verify exact startup mode, delayed-start value, and running state restoration.

## Evidence status

Physical execution, repeated measurements, demand-start behavior, reboot persistence, protected-application readiness, exact rollback execution, and medians remain `needs-evidence`. The candidate remains Experimental and receives no Stable assignment.

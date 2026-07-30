# EXP-065: HP System Info HSA service demand-start calibration

Status: Experimental  
Evidence: needs-evidence

## Candidate

Change the exact `HPSysInfoCap` service from Automatic or Automatic (Delayed Start) to Manual. Preserve the current running state during application. Change no application, package, task, file, driver, device, firmware, security control, update mechanism, recovery component, enterprise-management setting, or protected remote-access application.

## Support boundary

The provider proceeds only on Windows 11 running on an HP or Hewlett-Packard system, with elevation, exactly one matching service, matching display and executable identity, a valid HP publisher signature, no detected service-policy ownership, and no dependencies or dependent services requiring review. Unsupported, ambiguous, unsigned, policy-owned, dependency-sensitive, driver-backed, or drifted states terminate without mutation.

## Engineering contract

`controller/providers/HPSystemInfoHsaService.ps1` exposes `Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback`. It captures machine and Windows identity, service configuration, delayed-start value, running state, account, binary path, executable version, signature, dependencies, and dependent services. JSONL logs record support, capture, dry run, application, verification, reboot verification, rollback, and failures.

Application uses only service startup configuration and leaves the running state unchanged. Repeated application returns success without a second mutation. Rollback refuses identity or configuration drift, restores the exact startup mode and delayed-start value, then restores and verifies the original running state.

## Zero-mutation integration path

```powershell
$provider = '.\controller\providers\HPSystemInfoHsaService.ps1'
$state = Join-Path $env:TEMP 'EXP-065-state.json'
$log = Join-Path $env:TEMP 'EXP-065-log.jsonl'
& $provider -Action Check -StatePath $state -LogPath $log
& $provider -Action DryRun -StatePath $state -LogPath $log -WhatIf
```

## Physical validation

Run five matched baseline and five treatment boots or sign-ins. Report medians for usable-desktop time and first-120-second CPU and disk activity. Verify HP system-information demand-start behavior, HP update behavior, Device Manager, protected Windows scopes, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale. Verify reboot persistence and exact rollback.

A demand-start failure, HP application regression, protected-scope regression, or rollback mismatch remains preserved as failed or inconclusive evidence. No performance claim or Stable assignment is permitted without explicit human approval and completed physical evidence.

# EXP-063: HP App Helper HSA service demand-start calibration

Status: Experimental  
Evidence: needs-evidence

## Candidate

Change the exact `HPAppHelperCap` service from Automatic or Automatic (Delayed Start) to Manual. Preserve the current running state during application. Change no application, package, task, file, driver, device, firmware, security control, update mechanism, recovery component, enterprise-management setting, or protected remote-access application.

## Support boundary

The provider proceeds only on Windows 11 running on an HP or Hewlett-Packard system, with elevation, exactly one matching service, matching display and executable identity, a valid HP publisher signature, no detected service-policy ownership, and no dependencies or dependent services requiring review. Unsupported, ambiguous, unsigned, policy-owned, dependency-sensitive, driver-backed, or drifted states terminate without mutation.

## Engineering contract

`controller/providers/HPAppHelperHsaService.ps1` exposes `Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback`. It captures machine and Windows identity, service configuration, delayed-start value, running state, account, binary path, executable version, signature, dependencies, and dependent services. JSONL logs record support, capture, dry run, application, verification, reboot verification, rollback, and failures.

Application uses only service startup configuration and leaves the running state unchanged. Repeated application returns success without a second mutation. Rollback refuses identity or configuration drift, restores the exact startup mode and delayed-start value, then restores and verifies the original running state.

## Zero-mutation integration path

Run from an elevated Windows PowerShell session on the target HP system:

```powershell
$provider = '.\controller\providers\HPAppHelperHsaService.ps1'
$state = Join-Path $env:TEMP 'EXP-063-state.json'
$log = Join-Path $env:TEMP 'EXP-063-log.jsonl'
& $provider -Action Check -StatePath $state -LogPath $log
& $provider -Action DryRun -StatePath $state -LogPath $log -WhatIf
```

Confirm that no service configuration or running state changes during this path. Preserve the generated support and refusal evidence.

## Physical validation

Record device model, Windows build, BIOS, HP App Helper version, storage and display drivers, power source, power mode, thermal state, installed HP applications, network state, and instrumentation version.

1. Capture service and system state.
2. Run at least five matched baseline boots or sign-ins.
3. Apply the candidate and verify the service remains in its original running state.
4. Reboot and run at least five matched treatment boots or sign-ins.
5. Report raw runs, medians, dispersion, failures, and instrumentation overhead for usable-desktop time and first-120-second CPU and disk activity.
6. Launch HP Support Assistant and every installed HP application likely to request the helper. Record whether the service demand-starts and whether each function succeeds.
7. Verify HP update behavior, Device Manager, Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale.
8. Roll back, verify exact configuration and running-state restoration, reboot, and repeat functional checks.

A demand-start failure, HP application regression, protected-scope regression, or rollback mismatch remains preserved as failed or inconclusive evidence. No performance claim or Stable assignment is permitted without explicit human approval and completed physical evidence.

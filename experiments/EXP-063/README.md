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

Before and after the integration path, capture these commands and compare their output:

```powershell
Get-CimInstance Win32_Service -Filter "Name='HPAppHelperCap'" |
    Select-Object Name, DisplayName, StartMode, State, StartName, PathName

Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\HPAppHelperCap' |
    Select-Object Start, DelayedAutoStart, ImagePath, ObjectName
```

The service configuration and running state must remain identical. The dry run must report the exact proposed target, preserve-running-state behavior, and zero applied mutations. Preserve all support refusals and command failures as evidence rather than replacing them with a successful rerun.

## Application and verification sequence

1. Run `Check` and retain the structured result.
2. Run `Capture` and retain the versioned machine-bound state artifact.
3. Run `DryRun` and `DryRun -WhatIf`; confirm zero mutation.
4. Run `Apply`; confirm the service remains in its captured running state.
5. Run `Verify`; confirm Manual start and `DelayedAutoStart=0`.
6. Run `Apply` again; confirm idempotent success with zero additional mutation.
7. Reboot once and run `VerifyReboot`.
8. Complete HP application and protected-scope functional checks.
9. Run `Rollback`; confirm exact startup, delayed-start, and running-state restoration.
10. Reboot again and repeat the functional checks.

Stop treatment and execute rollback when service identity, dependencies, dependents, management state, executable identity, protected scope, or expected applied state drifts.

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

## Evidence retention

Keep baseline, treatment, rollback, failed, rejected, and inconclusive runs. Each run record must include a unique run identifier, timestamp, boot identifier, test phase, service state, startup mode, delayed-start value, first-120-second CPU and disk measurements, protected-application readiness, HP application result, instrumentation status, and free-text anomaly field. Missing physical measurements remain `needs-evidence` and do not erase repository engineering progress.

A demand-start failure, HP application regression, protected-scope regression, or rollback mismatch remains preserved as failed or inconclusive evidence. No performance claim or Stable assignment is permitted without explicit human approval and completed physical evidence.

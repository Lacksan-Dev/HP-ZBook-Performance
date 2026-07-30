# EXP-075: HP TechPulse SmartHealth demand-start

## Status

Experimental. Physical measurements remain `needs-evidence`. Stable requires explicit human approval.

## Candidate

Change exactly one HP-published Windows service whose executable resolves to `C:\Program Files\HP\HP TechPulse SmartHealth\hptpsmarthealth.exe` from Automatic or Automatic (Delayed Start) to Manual. Application preserves the current running state.

The provider refuses ambiguous service identity, invalid publisher signature, dependencies, active HP Workforce Experience or TechPulse processes, Windows or HP enrollment evidence, Intune or Configuration Manager ownership, service-policy ownership, and protected-component dependencies.

## Mutation boundary

The only intended mutation is the selected service startup configuration and its `DelayedAutoStart` value. No package, application, file, scheduled task, enrollment record, certificate, device, driver, INF, firmware, network setting, security setting, update component, recovery setting, or protected remote-access application changes.

## Controller profile

`HPTechPulseSmartHealthDemandStart`

Provider: `hp-techpulse-smarthealth-service`

## Non-destructive integration path

Run from elevated Windows PowerShell on an HP Windows 11 test system:

```powershell
$state = Join-Path $env:ProgramData 'Lacksan\EXP-075\state.json'
$log = Join-Path $env:ProgramData 'Lacksan\EXP-075\events.jsonl'

.\controller\providers\HPTechPulseSmartHealthService.ps1 -Action Check -LogPath $log
.\controller\providers\HPTechPulseSmartHealthService.ps1 -Action DryRun -StatePath $state -LogPath $log
.\controller\providers\HPTechPulseSmartHealthService.ps1 -Action Apply -StatePath $state -LogPath $log -WhatIf
```

Confirm that Check and DryRun write structured evidence and that `-WhatIf` leaves the service registry and running state unchanged.

## Physical validation

1. Capture Windows build, HP model, BIOS, service identity, executable version and SHA-256, signature, dependencies, power source, thermal state, management state, and pending reboot state.
2. Execute five matched baseline cold boots using the original service configuration.
3. Apply the provider without stopping the service, then verify immediate Manual state.
4. Execute five matched treatment cold boots.
5. Record sign-in to usable desktop, first-120-second CPU, disk, and network activity, HP process activity, and service start events. Preserve raw runs and report medians.
6. Launch the supported HP service-scan or diagnostic workflow. Record demand-start behavior and completion status.
7. Verify Omnissa, Windows App, Remote Desktop, Tailscale, normal networking, Windows security, updates, recovery, and enterprise-management readiness after every run.
8. Run `VerifyReboot` after a cold boot.
9. Execute exact rollback, verify startup mode, delayed-start state, and original running state, then repeat HP workflow and protected-application checks.
10. Preserve failed and inconclusive runs without replacing their evidence.

## Rollback

```powershell
.\controller\providers\HPTechPulseSmartHealthService.ps1 -Action Rollback -StatePath $state -LogPath $log
```

Rollback refuses identity, executable hash, signature, dependency, applied-configuration, or management-ownership drift. It restores the exact captured startup mode, delayed-start value, and running state.

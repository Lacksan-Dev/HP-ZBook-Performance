# EXP-067: HP Diagnostics HSA Manual demand-start

## Status
Experimental. Physical measurements remain `needs-evidence`. Stable requires explicit human approval.

## Candidate
Change exactly one verified `HPDiagsCap` service from Automatic or Automatic Delayed Start to Manual while preserving its running state during application.

## Safety and support boundary
The provider requires HP Windows 11, elevation, one exact service, `DiagsCap.exe`, a valid HP publisher signature, safe dependencies, absence of service-policy ownership, and no active HP diagnostics process. It changes no application, package, task, file, driver, device, firmware, security control, update component, recovery component, enterprise-management setting, or protected remote-access application.

## Zero-mutation integration
Run `Check`, then `DryRun -WhatIf` with new state and JSONL paths. Confirm the provider reports one bounded startup-mode candidate and leaves the service, processes, files, packages, drivers, and protected scopes unchanged.

## Physical validation
Use five matched baseline and five treatment boots or sign-ins. Retain raw trials and medians for usable-desktop latency and first-120-second CPU and disk activity. Verify HP diagnostics manual launch and demand-start, hardware scan availability, HP update behavior, Device Manager, reboot persistence, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

## Rollback
Rollback validates experiment, machine, service identity, executable version and SHA-256, signature, dependencies, dependents, and applied configuration. It restores the exact startup mode, delayed-start value, and original running state, then verifies all three. Preserve every failed or inconclusive result.

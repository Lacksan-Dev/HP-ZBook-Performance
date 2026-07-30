# EXP-070: HP Connection Recovery Manual demand-start

## Status

Experimental. Physical measurements remain `needs-evidence`. Stable remains unassigned.

## Candidate

Change only the exact `HPCommRecovery` service from Automatic or Automatic (Delayed Start) to Manual. Preserve its running state during application and restore the exact captured startup mode, delayed-start value, and running state during rollback.

## Safety and support boundary

The provider requires HP Windows 11, elevation, exactly one matching service, an HP Connection Recovery display identity, `HPCommRecovery.exe`, a valid HP publisher signature, zero dependencies and dependents, no enterprise service-policy ownership, and no active HP Connection Recovery process.

It captures service identity, startup configuration, running state, account, executable version and SHA-256, signature, machine and Windows identity, adapters, bindings, routes, DNS servers, and proxy state. Application changes service startup configuration only. It changes no network-stack object, application, package, file, task, driver, device, firmware, Windows protection, update component, recovery setting, enterprise-management setting, or protected remote-access application.

## Zero-mutation integration

```powershell
$provider='.\controller\providers\HPConnectionRecoveryService.ps1'
$state=Join-Path $env:TEMP 'EXP-070-state.json'
$log=Join-Path $env:TEMP 'EXP-070-log.jsonl'
& $provider -Action Check -StatePath $state -LogPath $log
& $provider -Action DryRun -StatePath $state -LogPath $log
& $provider -Action Apply -StatePath $state -LogPath $log -WhatIf
Invoke-Pester .\controller\tests\EXP-070.HPConnectionRecoveryService.Tests.ps1
```

Confirm that Check, DryRun, and `Apply -WhatIf` leave service configuration, adapters, bindings, routes, DNS, proxy, firewall, VPN, drivers, packages, and protected applications unchanged. Confirm every JSONL line parses independently.

## Physical validation

1. Record HP model, BIOS, Windows build, service identity, executable version and SHA-256, network drivers, power source, thermal state, and benchmark conditions.
2. Preserve five matched baseline sign-ins with usable-desktop latency and first-120-second CPU and disk activity.
3. Run Capture, DryRun, Apply, and Verify.
4. Verify Ethernet, Wi-Fi, DHCP, DNS, IPv4, IPv6, HTTPS, VPN, sleep and wake networking, and HP connection-recovery behavior.
5. Verify Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
6. Reboot and run VerifyReboot.
7. Preserve five matched treatment sign-ins and report medians without discarding failed or inconclusive trials.
8. Run Rollback and verify exact startup mode, delayed-start value, running state, and unchanged protected network boundary.

Physical execution, repeated measurements, recovery behavior, reboot persistence, protected-application readiness, exact rollback, and medians remain `needs-evidence`.

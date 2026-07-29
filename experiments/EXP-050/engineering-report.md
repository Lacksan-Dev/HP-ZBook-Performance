# EXP-050 Engineering Report

## Purpose
Integrate one exact Logi Options+ current-user tray or background Run registration into the Lacksan Controller as `LogiOptionsPlusDemandLaunch`.

## Mechanism
The provider inventories `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`, accepts at most one recognized Logi Options+ value, captures the exact unexpanded command and registry kind, removes only that value, verifies absence, records JSONL events, and restores the exact value during rollback.

## Safety boundaries
The provider refuses protected identities, updater-only commands, broad executable matches, and multiple candidates. It changes no package, executable, service, scheduled task, StartupTask registration, Logitech device or driver, Windows security or update component, recovery setting, credential or accessibility component, enterprise-management configuration, Omnissa, Windows App, Remote Desktop, or Tailscale configuration.

## Validation completed
Repository-static validation covers PowerShell parsing, the full reversible action contract, manifest registration, protected scopes, exact Run-key scope, recognized executable identities, updater refusal, and forbidden mutation tokens. The integration test performs zero Windows mutations.

## Physical evidence request
Run at least five matched baseline and five treatment sign-in trials on an HP Windows 11 lab system. Record Windows build, model, BIOS, Logitech software and driver versions, power source, power mode, thermal state, sign-in-to-usable-desktop time, first-120-second CPU and disk activity, protected remote-access readiness, Logi Options+ on-demand launch, device-settings readiness, update behavior, reboot persistence, and exact rollback. Report medians and preserve failed or inconclusive runs.

## Release status
Experimental. Physical measurements remain `needs-evidence`. No performance result and no Stable designation.

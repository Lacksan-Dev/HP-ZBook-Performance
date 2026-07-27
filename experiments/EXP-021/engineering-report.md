# EXP-021 Engineering Report

## Purpose
Evaluate one reversible startup variable: the current-user Office SDX Helper `Run` registration when both the value name and command identify `sdxhelper.exe`.

## Mechanism
The module captures the exact unexpanded registry command and registry value kind, then removes only that value. It refuses name-only matches, command drift after capture, cross-computer state, cross-user state, and rollback overwrites.

## Supported systems
HP systems running Windows 11 build 22000 or later. The candidate must exist under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` and pass strict Office SDX Helper identity checks.

## Applied changes
Repository implementation only. No live Windows state was changed during engineering.

## Engineering controls
- support detection
- exact original-state capture
- dry run through `ShouldProcess`
- verified apply
- JSONL logging
- idempotent repeated application
- terminating failures on identity drift
- reboot-persistence evidence
- exact rollback with overwrite refusal
- rollback verification
- Pester contract tests

## Preserved boundaries
Office applications, Click-to-Run, Office Automatic Updates, OneDrive, packages, files, services, scheduled tasks, Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged.

## Validation handoff
Run on the physical HP ZBook with AC power, stable thermal state, documented Windows build, BIOS, Office version, driver versions, and background conditions.

1. Capture baseline state and confirm candidate identity.
2. Execute dry run and verify zero state change.
3. Collect at least five baseline sign-in trials.
4. Apply the calibration and verify the exact value is absent.
5. Reboot and verify persistence.
6. Collect at least five calibrated sign-in trials.
7. Validate Office launch, document open/save, Click-to-Run update check, Office repair entry points, OneDrive synchronization, and protected remote-access readiness.
8. Roll back and verify the exact command and value kind are restored.
9. Reboot and verify restoration persistence.
10. Report medians for sign-in to usable desktop and first-120-second CPU and disk activity. Record instrumentation overhead separately.

## Success threshold
A measurable median responsiveness improvement with all preserved workflows passing and exact rollback confirmed.

## Failure threshold
Any Office servicing, update, repair, document, OneDrive, security, management, driver, or protected remote-access regression; state drift; failed persistence; or failed exact rollback.

## Release status
Experimental. Physical evidence remains required. Stable status requires explicit human approval.

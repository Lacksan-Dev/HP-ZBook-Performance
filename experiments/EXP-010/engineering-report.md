# EXP-010 Engineering Report

## Purpose

Remove only the current-user Microsoft OneDrive auto-start registration so OneDrive launches on demand instead of during Windows sign-in.

## Implemented scope

- HP Windows 11 support detection
- exact candidate path and value-name lock
- command-identity check requiring `OneDrive.exe`
- current-state capture before the first change
- dry-run output
- reversible application through `ShouldProcess`
- immediate application verification
- JSONL structured logging
- idempotent repeated application
- explicit failure handling
- reboot-persistence verification through the `Verify` action after restart
- exact rollback from the captured value
- rollback verification
- Pester contract tests

## Preserved state

The implementation leaves the OneDrive application, files, synchronized folders, account state, Known Folder Move configuration, shell integration, services, scheduled tasks, packages, updater, Windows security, Windows Update, recovery, enterprise management, drivers, Omnissa, Windows App, Remote Desktop, and Tailscale unchanged.

## Evidence classification

Repository implementation evidence only. No physical performance result is claimed.

## Physical validation required

1. Capture system metadata, power source, power mode, thermal state, network state, OneDrive account state, and Windows build.
2. Run repeated control sign-ins with the OneDrive registration present.
3. Apply EXP-010 and restart.
4. Verify the Run value remains absent after restart.
5. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
6. Launch OneDrive on demand and confirm synchronization and shell integration.
7. Run repeated treatment sign-ins.
8. Calculate medians for sign-in-to-usable, first-120-second CPU, disk, and network activity.
9. Roll back and restart.
10. Verify exact restoration and repeat the OneDrive workflow checks.

## Release state

Experimental. Physical measurements remain `needs-evidence`. Stable status requires explicit human approval.

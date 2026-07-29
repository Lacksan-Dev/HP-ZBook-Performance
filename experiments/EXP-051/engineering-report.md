# EXP-051 Engineering Report

## Purpose
Integrate one bounded Logi Bolt current-user Run registration into the Lacksan Controller transaction model.

## Mechanism
The provider inventories `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` using unexpanded registry data. It accepts one recognized Logi Bolt value and executable only when an explicit background-launch argument exists. Apply removes that value after controller capture. Rollback restores the exact value name, data, and registry kind and refuses overwrite.

## Engineering controls
- HP Windows 11 support detection
- protected-identity refusal
- exact current-state capture tied to computer and user SID
- dry run
- verified application
- structured JSONL logging
- idempotent zero-candidate behavior
- terminating failure records
- immediate and reboot-persistence verification
- exact restoration and rollback verification
- Pester contract coverage
- zero-mutation integration check

## Preserved components
Logi Bolt installation, packages, files, updater services, scheduled tasks, StartupTask registrations, Logitech HID devices and drivers, Windows security, Windows Update, recovery, credentials, accessibility, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Validation requirements
Use at least five matched baseline and treatment trials. Record Windows build, HP model, BIOS, Logitech driver and application versions, power source, thermal state, instrumentation, sign-in-to-usable-desktop time, first-120-second CPU and disk activity, protected remote-access readiness, Logi Bolt function, reboot persistence, and exact rollback. Report medians and preserve failed or inconclusive trials.

## Release state
Experimental. Physical evidence remains `needs-evidence`. No performance claim and no Stable assignment.

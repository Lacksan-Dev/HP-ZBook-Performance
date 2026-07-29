# EXP-052: Logi Tune Controller Integration

Status: Experimental

## Purpose
Integrate one bounded Logi Tune current-user tray or background Run registration into the Lacksan Controller transaction model.

## Hypothesis
Removing one exact Logi Tune auto-launch registration may reduce sign-in contention while preserving manual launch, camera and headset readiness, Logitech device-critical drivers, updates, and protected remote-access applications.

## Mechanism and controls
The `LogiTuneDemandLaunch` profile combines read-only system inventory with the reversible `logi-tune-run` provider. Eligibility requires an HP system running Windows 11, one recognized value name, a recognized Logi Tune executable, and an explicit background, minimized, startup, tray, or silent argument. Updater-only commands, protected identities, broad matches, and multiple candidates are refused.

The provider captures the exact unexpanded registry command, value kind, computer identity, user SID, and timestamp before application. It provides dry run, verified removal, JSONL logging, idempotent zero-candidate behavior, terminating failure records, immediate and reboot verification, rollback overwrite refusal, exact restoration, and rollback verification.

## Preserved components
Logi Tune installation, packages, files, services, scheduled tasks, StartupTask registrations, Logitech HID, audio, video, camera, headset, receiver, keyboard, mouse, Bluetooth, and device-critical drivers, Windows security, Windows Update, recovery, credentials, accessibility, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Validation handoff
Run on an HP Windows 11 target with one eligible Logi Tune registration. Record Windows build, HP model, BIOS, Logi Tune version, Logitech driver versions, power source, thermal state, and instrumentation version. Complete at least five matched baseline and five treatment sign-in trials. Compare medians for sign-in to usable desktop and CPU and disk activity during the first 120 seconds. Confirm protected remote-access readiness, Logi Tune manual launch, camera and headset visibility, settings access, update behavior, reboot persistence, and exact rollback. Preserve every failed or inconclusive trial and qualify instrumentation overhead.

Physical execution and median measurements remain `needs-evidence`. No performance result and no Stable assignment.

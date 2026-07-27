# EXP-017 Engineering Report

## Candidate
Change only a recognized Logi Options+ updater service from its captured startup mode to Manual. The implementation accepts `logioptionsplus_updater` or `LogiOptionsPlusUpdaterService` only when the executable path independently identifies Logi Options+ updater software.

## Safety and support
The script supports HP systems running Windows 11. It refuses identity mismatches and protected Windows, Defender, Omnissa, Windows App, Remote Desktop, and Tailscale identities. It changes no application, package, file, scheduled task, driver, HID component, security control, Windows service, or running state during application.

## Engineering controls
- support detection
- exact original service name, display name, executable path, startup mode, and running-state capture
- dry run
- ShouldProcess application
- post-change verification
- JSONL logging
- idempotent repeated application
- terminating failure handling
- reboot-persistence verification through `Verify`
- exact startup-mode and running-state rollback
- rollback verification
- Pester contract tests

## Validation handoff
Physical HP ZBook validation must record Windows build, device, BIOS, Logitech version, power source, thermal state, and workload conditions. Run repeated baseline and Manual-start trials, calculate medians, verify reboot persistence, test Logi Options+ on-demand configuration and update behavior, verify protected remote-access readiness, execute rollback, and confirm exact restoration.

## Release state
Experimental. Physical evidence remains pending. No performance claim is made.

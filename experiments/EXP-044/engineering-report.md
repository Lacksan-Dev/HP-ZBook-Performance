# EXP-044 Engineering Report

## Candidate
Remove one bounded current-user Logi Options+ tray auto-launch registration from `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.

## Scope
The implementation accepts one exact Logi Options+ value-name identity, a recognized Logi Options+ user-space executable, and a background-launch argument. It refuses updater-only commands, protected identities, broad matches, and multiple eligible registrations.

## Lifecycle
- `Check`: inventory bounded candidates.
- `Capture`: save exact unexpanded command, value kind, machine identity, user SID, and timestamp.
- `DryRun`: report the exact registration that would be removed.
- `Apply`: verify captured identity, remove the registration, and verify absence.
- `Verify`: verify the captured registration remains absent.
- `VerifyReboot`: verify absence after reboot and log the boot time.
- `Rollback`: refuse overwrite, restore exact value name, command, and registry kind, then verify equality.

## Safety
No application, package, executable, service, task, StartupTask, device, driver, update, security, recovery, credential, accessibility, enterprise-management, networking, Omnissa, Windows App, Remote Desktop, or Tailscale component is modified.

## Tests
Pester contract tests cover parsing, ShouldProcess, lifecycle actions, exact registry capture, bounded identity checks, structured logging, rollback overwrite refusal, and forbidden destructive operations. `Test-Integration.ps1` performs a read-only parse and contract-token check.

## Physical validation handoff
Run at least five matched baseline and five treatment sign-in trials on the same HP ZBook, Windows build, BIOS, driver set, power source, and thermal condition. Record medians for usable-desktop time, first-120-second CPU and disk activity, protected remote-access readiness, Logi Options+ on-demand launch, Logitech device-settings readiness, and update-check behavior. Execute reboot verification and exact rollback. Record instrumentation overhead separately.

Physical measurements remain `needs-evidence`. No performance improvement is claimed.

# EXP-051: Logi Bolt Controller Integration

Status: Experimental

## Hypothesis
Removing one exact current-user Logi Bolt tray or background Run registration may reduce sign-in contention while preserving manual Logi Bolt launch and device-critical Logitech drivers.

## Scope
The `LogiBoltDemandLaunch` controller profile combines read-only system inventory with the reversible `logi-bolt-run` provider. Eligibility requires an HP system running Windows 11, one exact recognized value name, a recognized Logi Bolt executable, and an explicit background, minimized, startup, tray, or silent argument.

Updater-only commands, broad matches, protected identities, multiple eligible entries, packages, files, services, tasks, StartupTask registrations, devices, and drivers remain outside scope.

## Procedure
1. Run controller scan and recommendation.
2. Run `DryRun` for `LogiBoltDemandLaunch`.
3. Capture exact original state.
4. Apply the profile and verify immediately.
5. Reboot and run reboot verification.
6. Validate Logi Bolt manual launch, receiver visibility, keyboard and mouse function, settings access, and protected remote-access readiness.
7. Execute exact rollback and verify restoration.
8. Run at least five matched baseline and treatment sign-in trials and compare medians.

## Evidence state
Physical HP Windows 11 application, reboot, rollback, functional validation, instrumentation qualification, and repeated median measurements are `needs-evidence`. No performance result is claimed.

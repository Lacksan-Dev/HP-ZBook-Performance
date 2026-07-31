# EXP-051: Logi Bolt Controller Integration

Status: Experimental
Stage: Validation
Evidence: needs-evidence

## Hypothesis
Removing one exact current-user Logi Bolt tray or background Run registration may reduce sign-in contention while preserving manual Logi Bolt launch, existing receiver pairing, basic keyboard and mouse operation, and device-critical Logitech drivers.

## Scope
The `LogiBoltDemandLaunch` controller profile combines read-only system inventory with the reversible `logi-bolt-run` provider. Eligibility requires an unmanaged HP system running Windows 11, exactly one recognized current-user Run value, a resolved `LogiBolt.exe` or `logi-bolt.exe` beneath a Logitech or Logi Bolt application directory, explicit background-launch arguments, and a valid Logitech or Logi Authenticode publisher.

The provider captures the exact registry path, value name, registry type, unexpanded command, executable path, executable SHA-256, executable version, publisher subject, machine identity, and user SID. It refuses updater, repair, uninstall, firmware, pairing, protected-identity, ambiguous, unsigned, enterprise-managed, and multiple-candidate states.

Mutation is limited to deleting the single captured Run value. The Logi Bolt installation, packages, files, updater services, scheduled tasks, StartupTask registrations, receiver pairing, Bluetooth state, HID devices, drivers, firmware, Windows security, Windows Update, recovery, credentials, accessibility, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged.

## Integration procedure
1. Run the controller inventory and recommendation path.
2. Run `DryRun` for `LogiBoltDemandLaunch` and confirm one eligible value and zero mutation.
3. Capture state to a protected test artifact and inspect the structured JSONL support and capture records.
4. Apply the profile. Confirm one Run value was removed and a repeated apply returns an idempotent zero-mutation result.
5. Run immediate verification.
6. Reboot and run `VerifyReboot`; retain boot time and persistence evidence.
7. Launch Logi Bolt manually and verify receiver visibility, existing pairing, keyboard and mouse operation, and available settings.
8. Verify Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
9. Execute rollback. The provider must refuse overwrite, publisher drift, executable hash drift, command drift, machine drift, and user-SID drift.
10. Confirm the exact registry type and unexpanded command were restored.

## Measurement protocol
Run five matched baseline sign-ins and five matched treatment sign-ins under controlled AC power, power mode, thermal state, Windows build, BIOS, driver, application-version, network, and instrumentation conditions. Preserve raw runs and report medians for:

- sign-in to usable desktop
- first-120-second aggregate CPU utilization
- first-120-second aggregate disk activity
- Logi Bolt process activity and manual-launch readiness
- receiver, keyboard, and mouse readiness
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness

Record instrumentation overhead. Preserve favorable, adverse, failed, and inconclusive evidence without substituting estimated measurements.

## Evidence state
Physical HP Windows 11 application, five matched baseline and treatment trials, first-120-second CPU and disk measurements, manual Logi Bolt launch, receiver and peripheral checks, protected-application readiness, reboot persistence, exact rollback execution, instrumentation qualification, and median results remain `needs-evidence`. Stable remains unassigned.

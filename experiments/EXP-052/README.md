# EXP-052: Logi Tune Controller Integration

Status: Experimental
Stage: Validation
Evidence: needs-evidence

## Hypothesis
Removing one exact current-user Logi Tune tray or background Run registration may reduce sign-in contention while preserving manual Logi Tune launch, camera, headset, microphone, speaker, keyboard, mouse, and device-critical Logitech drivers.

## Scope
The `LogiTuneDemandLaunch` profile combines read-only system inventory with the reversible `logi-tune-run` provider. Eligibility requires an unmanaged HP system running Windows 11, exactly one recognized current-user Run value, a resolved `LogiTune.exe`, `LogiTuneUI.exe`, or `logi-tune.exe` beneath a Logitech or Logi Tune application directory, explicit background-launch arguments, and a valid Logitech or Logi Authenticode publisher.

The provider captures the exact registry path, value name, registry type, unexpanded command, executable path, SHA-256, version, publisher subject, machine identity, and user SID. It refuses updater, repair, uninstall, firmware, pairing, driver, protected-identity, ambiguous, unsigned, enterprise-managed, and multiple-candidate states.

Mutation is limited to deleting the single captured Run value. Logi Tune files, services, tasks, packages, StartupTask registrations, Logitech HID/audio/video devices, receivers, Bluetooth, firmware, device-critical drivers, Windows security, Windows Update, recovery, credentials, accessibility, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged.

## Integration procedure
1. Run inventory and `DryRun`; confirm one candidate and zero mutation.
2. Capture state and inspect structured JSONL records.
3. Apply once, verify removal, then repeat application and confirm idempotent zero mutation.
4. Reboot and run `VerifyReboot`; retain boot-time evidence.
5. Launch Logi Tune manually and verify camera, headset, microphone, speaker, keyboard, mouse, settings, and update behavior.
6. Verify Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
7. Execute rollback. Require overwrite refusal plus publisher, executable-hash, command, machine, and user-SID drift refusal.
8. Confirm exact registry type and unexpanded command restoration.

## Measurement protocol
Run five matched baseline and five treatment sign-ins under controlled AC power, power mode, thermal state, Windows build, BIOS, driver, application-version, network, and instrumentation conditions. Preserve raw runs and report medians for sign-in to usable desktop, first-120-second CPU and disk activity, Logi Tune readiness, peripheral readiness, and protected remote-access readiness. Record instrumentation overhead and preserve favorable, adverse, failed, and inconclusive evidence.

## Evidence state
Physical HP Windows 11 application, repeated measurements, manual application and peripheral checks, protected-application readiness, reboot persistence, exact rollback execution, instrumentation qualification, and medians remain `needs-evidence`. Stable remains unassigned.

# EXP-032 engineering report

## Candidate
Change only `LGHUBUpdaterService` startup mode to `Manual` when HP Windows 11 support and strict service-name, display-name, and executable-command identity checks pass.

## Safety boundary
The implementation changes one Logitech G Hub updater service startup mode. Application leaves its current running state unchanged. It performs no package, executable, scheduled-task, startup-registration, device, driver, Logitech HID, keyboard, mouse, receiver, Bluetooth, Windows platform service, security, update, recovery, credential, accessibility, enterprise-management, networking, Omnissa, Windows App, Remote Desktop, or Tailscale modification.

## Lifecycle
- `Check`: platform, service, display-name, executable, and protected-identity detection.
- `Capture`: exact service identity, executable command, startup mode, delayed-auto state, running state, machine, and timestamp.
- `DryRun`: state-backed plan with zero service mutation.
- `Apply`: `ShouldProcess`-guarded change to Manual with immediate startup-mode and running-state verification.
- `Verify`: confirms the target startup mode.
- `VerifyReboot`: confirms persistence after reboot.
- `Rollback`: requires unchanged service identity, restores exact startup mode, delayed-auto state, and running state, then verifies all fields.

Every action appends JSONL events. Repeated application is idempotent. Failures are logged and terminating.

## Tests
Pester contract tests cover identity controls, lifecycle coverage, logging, idempotence, protected identities, running-state preservation, delayed-auto restoration, rollback, and absence of destructive package, device, and driver operations. The integration script performs only `Check` and `DryRun`, validates state and logs when supported, and accepts explicit support refusal elsewhere.

## Physical validation handoff
Physical evidence remains `needs-evidence`:

1. Record HP model, Windows build, BIOS, Logitech G Hub version, updater binary version, power source, and thermal state.
2. Run at least five matched baseline and five candidate sign-in trials.
3. Report medians for sign-in-to-usable desktop and first-120-second CPU and disk activity.
4. Validate Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
5. Validate G Hub launch, device detection, saved configuration, update checks, and updater demand-start behavior.
6. Confirm Logitech keyboard, mouse, receiver, Bluetooth, lighting, macro, and profile functions relevant to the device.
7. Reboot and execute `VerifyReboot`.
8. Execute rollback, verify exact restoration, reboot again, and repeat G Hub validation.
9. Preserve failed or inconclusive measurements without a performance claim.

# EXP-031 engineering report

## Candidate
Change only `HPSupportSolutionsFrameworkService` startup mode to `Manual` when HP Windows 11 support and strict service, display-name, and executable-command identity checks pass.

## Safety boundary
The implementation changes one service startup mode. It leaves the current running state unchanged during application. It performs no package, executable, scheduled-task, startup-registration, device, driver, Windows platform service, security, update, recovery, credential, accessibility, enterprise-management, networking, Omnissa, Windows App, Remote Desktop, or Tailscale modification.

## Lifecycle
- `Check`: support and identity detection.
- `Capture`: exact service identity, command, startup mode, running state, machine, and timestamp.
- `DryRun`: state-backed plan with no service mutation.
- `Apply`: `ShouldProcess`-guarded change to Manual with immediate mode and running-state verification.
- `Verify`: confirms the target mode.
- `VerifyReboot`: confirms persistence after reboot.
- `Rollback`: requires unchanged service identity, restores the exact captured startup mode and running state, then verifies both.

All actions append JSONL events. Repeated application is idempotent. Failures are logged and terminating.

## Tests
Pester contract tests cover identity controls, lifecycle coverage, logging, idempotence, protected identities, running-state preservation, rollback, and absence of destructive operations. The integration script performs only `Check` and `DryRun`, validates evidence and logs when supported, and accepts explicit support refusal on other systems.

## Physical validation handoff
Physical evidence remains `needs-evidence`:

1. Record HP model, Windows build, BIOS, power source, thermal state, HP Support Assistant version, and service binary version.
2. Run at least five baseline and five candidate sign-in trials under matched conditions.
3. Report medians for sign-in-to-usable desktop and first-120-second CPU and disk activity.
4. Validate Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
5. Validate HP Support Assistant device detection, diagnostics, and service demand-start behavior.
6. Reboot and execute `VerifyReboot`.
7. Execute rollback, verify exact restoration, reboot again, and retest HP Support Assistant.
8. Preserve failed or inconclusive measurements without a performance claim.

# EXP-042 Engineering Report

## Candidate
Disable only the Microsoft Edge Performance Detector through the recommended `PerformanceDetectorEnabled` policy value set to `0`.

## Supported basis
Microsoft documents `PerformanceDetectorEnabled` for Microsoft Edge 107 or later. The policy supports mandatory and recommended configuration and controls the detector that identifies tab performance issues and recommends corrective actions.

## Safety boundary
The implementation refuses enterprise-managed systems and any machine with an existing mandatory or recommended value for this policy. It changes no profile, password, cookie, favorite, extension, cache, SmartScreen, update component, service, scheduled task, package, device, driver, Startup registration, security control, recovery component, enterprise-management component, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component.

## Lifecycle
- `Check`: report support, management, and exact policy state.
- `Capture`: save machine-bound original state.
- `DryRun`: report the exact proposed registry value without changing it.
- `Apply`: set one recommended `REG_DWORD` value to `0` and verify it.
- `Verify`: verify the exact treatment value.
- `VerifyReboot`: verify persistence and record the current boot time.
- `Rollback`: remove only the experiment-created value, refuse unexpected mutation, remove an empty experiment-created key, and verify restoration.

All lifecycle operations emit JSONL records. Repeated application is idempotent. Terminating failures are logged and rethrown.

## Tests
Pester contract tests validate parsing, scope, support floor, lifecycle coverage, protected-operation exclusions, enterprise refusal, existing-policy refusal, rollback verification, and rollback mutation refusal. `Test-Integration.ps1` performs a non-destructive parse and static contract check.

## Physical validation handoff
On an eligible HP ZBook running Windows 11 with Edge 107 or later:

1. Capture Windows build, BIOS, device model, Edge version, power source, thermal state, and benchmark conditions.
2. Run at least five baseline trials and five treatment trials.
3. Measure cold process launch, first visible window, first interactive window, first new-tab readiness, first controlled navigation, post-launch CPU and memory, browser idle CPU and memory, and notification behavior.
4. Use medians and preserve every failed or inconclusive trial.
5. Restart Edge, reboot Windows, run `VerifyReboot`, and repeat treatment measurements.
6. Run exact rollback, verify the value is absent, restart Edge, and repeat a rollback confirmation trial.
7. Validate SmartScreen, Edge Update, profiles, browsing data, extensions, Omnissa, Windows App, Remote Desktop, and Tailscale readiness.

Physical measurements remain `needs-evidence`. No performance improvement is claimed.

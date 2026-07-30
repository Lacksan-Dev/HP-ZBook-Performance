# EXP-078: Edge graphics acceleration policy

## Candidate

Set only `HKLM\SOFTWARE\Policies\Microsoft\Edge\HardwareAccelerationModeEnabled` to `REG_DWORD 1` on an elevated, unmanaged HP Windows 11 system with exactly one Microsoft Edge 77 or later installation and at least one detected graphics adapter.

Microsoft documents this policy as mandatory-only, supported on Windows from Edge 77, and requiring a browser restart. Leaving the policy unconfigured also permits graphics acceleration when available. This experiment therefore requires measured evidence before any conclusion.

## Safety and reversibility

The provider refuses enterprise management, ambiguous or unsupported Edge installations, missing graphics-adapter inventory, and any existing policy value. It captures machine identity, Edge path and version, graphics adapter and driver details, and the exact pre-change registry state before mutation. Rollback removes only the experiment-created value and refuses policy drift.

No Edge profile, credential, cookie, favorite, extension, SmartScreen setting, update component, package, file, service, scheduled task, Windows security control, Windows Update component, recovery setting, enterprise-management setting, device-critical driver, network setting, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component is changed.

## Zero-mutation integration check

Run `Check`, `Capture`, `DryRun`, and `Apply -WhatIf` with unique state and JSONL log paths. Confirm that the target value remains absent, the state file records the exact baseline, the log is parseable one JSON object per line, and every protected application remains ready.

## Physical validation

Use five matched baseline and five matched treatment trials. Fully exit Edge between runs and restart Edge after policy application. Record Windows build, HP model, BIOS, Edge version, GPU name and driver, power source, thermal state, and benchmark conditions.

Measure medians for cold process launch, first visible window, first interactive window, first controlled navigation, new-tab readiness, controlled scrolling responsiveness, CPU, GPU, working set, disk activity, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale. Verify policy visibility in `edge://policy`, reboot persistence, and exact rollback. Preserve every failed, adverse, and inconclusive run.

## Evidence state

Physical measurements, browser-restart verification, reboot persistence, protected-application readiness, and executed rollback remain `needs-evidence`. The experiment remains Experimental. Stable assignment requires explicit human approval.

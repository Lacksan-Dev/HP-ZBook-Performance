# EXP-076: Edge new-tab-page prerender

## Candidate
Set only the supported recommended Microsoft Edge policy `NewTabPagePrerenderEnabled` to `REG_DWORD 0` on eligible HP Windows 11 systems running Edge 85 or later.

## Hypothesis
Disabling new-tab-page prerender may reduce idle Edge resource use and contention with Outlook and protected remote-access applications. The treatment may increase new-tab readiness latency, so both resource cost and user-visible latency must be measured.

## Safety and refusal boundaries
The provider refuses non-HP systems, Windows versions other than Windows 11, non-elevated execution, absent or ambiguous Edge installations, Edge versions below 85, enterprise-management signals, and any existing mandatory or recommended value for this policy. It changes no profile, credential, cookie, favorite, extension, package, service, task, file, browser security control, update component, recovery setting, driver, network setting, or protected remote-access application.

## Actions
`Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback` are supported. State identity includes experiment, provider, machine, Edge path/version, original mandatory and recommended policy state, and the treatment value. Rollback refuses policy drift and removes only the experiment-created recommended value.

## Integration check
On a Windows PowerShell host, parse the provider and run `Check`. Run `DryRun` with a temporary state and log path on an unmanaged eligible HP test system. Confirm zero registry mutation. Run `Apply -WhatIf` and confirm zero registry mutation. Inspect the JSONL log for support-detection and dry-run records. Do not emulate elevation, management state, HP identity, or Edge identity.

## Physical validation
Use at least five matched baseline and five treatment trials under equivalent power, thermal, network, profile, extension, and workload conditions. Record Windows build, HP model, BIOS, Edge version, power source, thermal state, and instrumentation overhead.

Measure medians for Edge process count, working set, CPU, disk, and network activity before opening a new tab; cold launch; first visible and interactive window; new-tab readiness; first controlled navigation; Outlook responsiveness; and Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Verify browser-restart behavior, reboot persistence, idempotent reapplication, exact rollback, and post-rollback equivalence.

Retain adverse, failed, and inconclusive evidence. Physical measurements remain `needs-evidence`. Never assign Stable automatically.

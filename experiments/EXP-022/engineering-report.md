# EXP-022 Engineering Report

## Purpose
Evaluate one Microsoft Edge demand-launch variable: the recommended `HardwareAccelerationModeEnabled` policy.

## Implemented mechanism
The PowerShell experiment changes only `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\HardwareAccelerationModeEnabled` after HP Windows 11 and Edge support checks. A mandatory policy at `HKLM\SOFTWARE\Policies\Microsoft\Edge` causes refusal.

## Safety and reversibility
- Captures path existence, value existence, DWORD value, and registry value kind before application.
- Supports `-WhatIf` through `ShouldProcess`.
- Verifies application and repeated application.
- Records JSONL events.
- Verifies persistence after reboot.
- Restores the exact captured value or removes the experiment-created value.
- Refuses state files from another experiment or computer.

## Preserved components
Edge profiles, passwords, cookies, favorites, extensions, SmartScreen, Edge Update, mandatory management policy, Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged.

## Repository validation
Pester contract tests cover support boundaries, mandatory-policy refusal, exact state capture, dry-run enforcement, idempotence, reboot verification, rollback verification, and JSONL logging. Physical execution remains pending.

## Physical validation handoff
Run baseline and candidate conditions with a fixed Edge version, Windows build, BIOS, graphics driver, power source, thermal state, profile, extensions, cache condition, and navigation target. Use at least five repetitions per condition and compare medians for:

- process launch latency
- first visible window
- first interactive window
- first new-tab readiness
- first controlled navigation
- prelaunch private working set
- GPU process readiness

Execute application, repeated application, reboot persistence, exact rollback, and post-rollback workflow verification. Record instrumentation overhead separately.

## Status
Experimental. Physical measurements remain `needs-evidence`. No performance claim is made.

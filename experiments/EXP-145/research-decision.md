# EXP-145 research decision: inventory-bound packaged StartupTask rollback gate

## Scope

EXP-145 targets exactly one priority packaged-app `StartupTask` selected from the EXP-143 normalized inventory. Candidate families include Microsoft Teams, Microsoft Office/Microsoft 365 quick-launch behavior, Logi Options+, Logi Bolt, Logi Tune, Logitech G Hub, or another confirmed non-allowlisted user application.

This decision preserves the owning package, package data, files, services, scheduled tasks, Run/RunOnce registrations, Startup folders, device configuration, firmware, device-critical drivers, Windows security, Windows Update, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Supported Windows surface

Packaged startup registrations are exposed through `Windows.ApplicationModel.StartupTask`.

Relevant supported operations and states:

- `StartupTask.GetAsync(taskId)` retrieves a manifest-declared startup task.
- `StartupTask.State` reports `Disabled`, `DisabledByUser`, `Enabled`, `DisabledByPolicy`, or `EnabledByPolicy`.
- `StartupTask.Disable()` disables an eligible startup task.
- `StartupTask.RequestEnableAsync()` requests enablement.
- `DisabledByUser` represents a user-owned disable decision that requires user re-enablement.
- `DisabledByPolicy` and `EnabledByPolicy` represent management-owned state.

Primary Microsoft documentation reviewed for the repository's existing EXP-093 packaged StartupTask decision:

- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask
- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptaskstate
- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask.requestenableasync

## Engineering decision

A production mutation provider is gated in this cycle because the repository requires exact rollback and EXP-145 has no physical state-transition proof for the selected EXP-143 candidate.

The supported API can disable an eligible task, while exact programmatic restoration depends on the captured runtime state and Windows ownership semantics. A provider may therefore proceed only after the target package/task combination demonstrates that an initially `Enabled` task can be disabled and restored to exactly `Enabled` through supported APIs in a documented repeatable workflow.

`DisabledByUser`, `DisabledByPolicy`, and `EnabledByPolicy` baselines are ineligible for automated treatment. Undocumented `StartupApproved` registry mutation, package re-registration, manifest editing, and policy override remain outside scope.

## EXP-143 selection binding

The physical probe must consume one exact EXP-143 normalized `priority-target` record and bind the evidence to:

- EXP-143 inventory artifact hash;
- package full name and package family name;
- package name, version, architecture, publisher, and installation identity;
- application identity and manifest StartupTask ID;
- runtime StartupTask state;
- entry point or executable evidence and final executable identity where resolvable;
- registration source;
- machine identity, user SID, Windows build, boot identity, and management state;
- normalized pre-change startup inventory and hash.

Selection must refuse ambiguous candidates, duplicate product/mechanism coverage, missing package/task identity, unresolved executable identity where the manifest requires one, unsigned or identity-mismatched targets, management ownership, and every protected identity declared by EXP-145.

## Required physical state-transition probe

Run the probe on the target HP Windows 11 lab profile with the exact selected EXP-143 candidate:

1. Capture the complete EXP-143 selection binding and a normalized packaged-StartupTask inventory before any state transition.
2. Verify exactly one selected package and exactly one selected StartupTask.
3. Verify the owning package remains installed and healthy, and capture supported update/servicing state without changing it.
4. Refuse `DisabledByUser`, `DisabledByPolicy`, `EnabledByPolicy`, ambiguous identity, management ownership, package drift, protected scope, or an original state other than `Enabled` for the first reversible treatment.
5. Invoke `Disable()` exactly once in the required current-user context.
6. Verify the selected task reaches `Disabled` while every unrelated StartupTask remains byte-for-byte equivalent in the normalized snapshot.
7. Sign out/in or reboot and verify the selected disabled state persists.
8. Invoke `RequestEnableAsync()` in the required interactive context.
9. Capture the returned state and verify the selected task returns exactly to `Enabled` without Task Manager, Settings, undocumented registry edits, package re-registration, manifest edits, or policy changes.
10. Reboot again and verify restored persistence plus exact equality of the normalized packaged-StartupTask inventory except for expected volatile metadata.
11. Verify manual application launch and one controlled core function for the selected product.
12. Verify supported servicing/update readiness for the selected product.
13. Verify Omnissa, Windows App, Remote Desktop, and Tailscale readiness and preserve Windows security/update/recovery/management/device state.
14. Preserve every favorable, adverse, failed, rejected, and inconclusive transition as raw evidence.

## Provider acceptance contract after the probe passes

Only after exact restore is demonstrated may the EXP-145 mutation provider merge. It must implement:

- HP Windows 11 and current-user support detection;
- exact EXP-143 `priority-target` binding and duplicate-experiment refusal;
- package, manifest, task, publisher/product, executable/entry-point, management, and protected-scope validation;
- exact original-state capture plus pre-change normalized snapshot/hash;
- state-artifact overwrite refusal;
- `Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback` actions;
- `ShouldProcess` and `-WhatIf` with zero production mutation;
- focused application through the supported StartupTask API only;
- immediate and observed-reboot persistence verification;
- structured JSONL logging with experiment ID, machine identity, user SID, timestamp, action, before state, after state, result, refusal reason, and failure detail;
- idempotent repeated application and rollback;
- terminating failure handling that retains failure evidence;
- package/task/executable/product/management/protected-scope drift refusal;
- exact supported-API rollback to the captured state;
- conflicting-state rollback refusal with `needs-evidence` retention;
- post-rollback equality verification against the captured normalized state;
- Pester fixture coverage for selection binding, eligible and ineligible states, protected refusal, dry run, `WhatIf`, idempotence, drift refusal, conflicting-state rollback refusal, exact restoration, and zero mutation outside the selected task;
- opt-in Windows integration coverage proving read-only actions leave StartupTask, security, update, device, and protected-application state unchanged.

## Performance validation after the gate passes

Use five matched baseline and five matched treatment cold boots. Retain raw trials and report medians plus dispersion for sign-in to usable desktop, first-120-second system CPU and disk activity, selected launch-chain CPU time/disk I/O/working set/process starts/network activity where attributable, protected-application readiness, manual application readiness, and supported servicing readiness.

Record Windows build, HP model, BIOS, package/product version, StartupTask identity/state, executable version/hash where resolvable, power source, power mode, thermal state, management state, network condition, and instrumentation overhead.

## Evidence state

The supported Windows API surface and repository implementation gate are defined. EXP-143 physical candidate identity, supported state-transition proof, exact rollback execution, five matched baseline/treatment boots, first-120-second attribution, application function, servicing readiness, protected-application readiness, medians, dispersion, and instrumentation qualification remain `needs-evidence`.

Release state remains Experimental. Stable remains unassigned.

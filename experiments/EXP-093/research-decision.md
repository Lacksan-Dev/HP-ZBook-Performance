# EXP-093 research decision: Teams packaged StartupTask rollback gate

## Scope

This experiment targets one Microsoft Teams packaged-app `StartupTask` registration only. It preserves the Teams package, package data, credentials, servicing, manual launch, Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Supported Windows mechanism

Microsoft exposes packaged startup registrations through `Windows.ApplicationModel.StartupTask`.

Relevant supported operations and states:

- `StartupTask.GetAsync(taskId)` retrieves a startup task by manifest task ID.
- `StartupTask.State` reports `Disabled`, `DisabledByUser`, `Enabled`, `DisabledByPolicy`, or `EnabledByPolicy`.
- `StartupTask.Disable()` disables a startup task.
- `StartupTask.RequestEnableAsync()` requests enablement.
- Microsoft documents that a task in `DisabledByUser` state can only be re-enabled by the user.
- Microsoft documents that `RequestEnableAsync()` does not override a Task Manager user-disable decision.

Primary documentation reviewed 2026-08-01:

- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask
- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptaskstate
- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask.requestenableasync

## Engineering decision

No mutation provider is approved in this cycle.

The repository requires exact rollback. A provider that disables a packaged StartupTask must first prove on the target Windows 11 and Teams package combination that the supported disable path can be restored to the exact captured `Enabled` state without undocumented registry edits, package re-registration, policy override, or loss of user control.

A `DisabledByUser` baseline is ineligible because Microsoft explicitly requires user re-enablement. `DisabledByPolicy` and `EnabledByPolicy` are also ineligible because management owns the state.

The provider must never edit undocumented `StartupApproved` registry storage as a substitute for the supported StartupTask API.

## Required physical probe before implementation

Run a zero-customer-impact validation on a disposable or rollback-capable Windows 11 lab profile with the exact installed Teams package:

1. Record Windows build, edition, device, BIOS, Teams package full name, package family name, package version, manifest path, StartupTask ID, current `StartupTaskState`, user SID, management state, power source, thermal state, and protected-application readiness.
2. Verify exactly one Teams package and exactly one eligible startup task.
3. Refuse `DisabledByUser`, `DisabledByPolicy`, `EnabledByPolicy`, ambiguous task identity, enterprise ownership, or package drift.
4. When the baseline state is `Enabled`, invoke the supported `Disable()` method once.
5. Verify the resulting runtime state immediately and after sign-out/sign-in or reboot.
6. Invoke the supported `RequestEnableAsync()` restore path in the required interactive context.
7. Verify whether the state returns exactly to `Enabled` without requiring Task Manager, Settings, registry editing, package re-registration, or policy changes.
8. Verify Teams manual launch, sign-in, update/servicing behavior, notifications after manual launch, and protected remote-access readiness.
9. Preserve raw state transitions and any user-consent UI as evidence.

## Implementation acceptance gate

Engineering may proceed only if the physical probe demonstrates all of the following:

- exact Teams package and StartupTask identity can be detected reliably;
- `Enabled` can be changed through the supported API;
- the supported restore path returns the task to `Enabled` under a documented, repeatable workflow;
- reboot persistence is observable;
- no undocumented registry mutation is required;
- management-owned states are refused;
- protected applications and Windows protections remain unchanged.

If exact restore cannot be demonstrated, preserve EXP-093 as Rejected or Inconclusive evidence for automated mutation and continue startup cleanup through Run, RunOnce, Startup-folder, and sign-in scheduled-task candidates that meet the rollback contract.

## Performance benchmark after the gate passes

Use five matched baseline cold boots and five matched treatment cold boots. Report medians plus dispersion for sign-in to usable desktop, first-120-second CPU and disk activity, Teams process activity, manual Teams launch readiness, and Omnissa, Windows App, Remote Desktop, and Tailscale readiness. Preserve failed and adverse runs.

## Evidence state

The supported API surface is documented. Exact Teams state transition and exact rollback behavior on the lab machine remain `needs-evidence`. No performance claim is made. Release status remains Experimental. Stable is excluded.

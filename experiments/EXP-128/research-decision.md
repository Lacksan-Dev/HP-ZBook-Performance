# EXP-128 research decision: Microsoft 365 packaged StartupTask rollback gate

## Scope

This experiment covers exactly one Microsoft Office or Microsoft 365 packaged `StartupTask` whose manifest and runtime identity attribute it to user-facing Office launch or another explicitly identified non-servicing user-space helper.

The treatment candidate changes only that StartupTask state. Microsoft 365 installation, Click-to-Run servicing, activation, documents, add-ins, updates, services, scheduled tasks, Run/RunOnce registrations, Startup folders, package files/data, application settings, Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain preserved.

## Supported Windows mechanism

Microsoft documents packaged desktop startup registrations through the `desktop:StartupTask` manifest extension and `Windows.ApplicationModel.StartupTask` API.

Relevant supported behavior reviewed 2026-08-02:

- A packaged desktop application can declare a `windows.startupTask` / `desktop:StartupTask` manifest extension with a unique `TaskId` and executable identity.
- `StartupTask.State` exposes runtime state including `Disabled`, `DisabledByUser`, `Enabled`, `DisabledByPolicy`, and `EnabledByPolicy`.
- `StartupTask.Disable()` provides the supported disable path.
- `StartupTask.RequestEnableAsync()` requests enablement.
- Microsoft documents that a task disabled by the user through Task Manager cannot be programmatically re-enabled through `RequestEnableAsync()`.

Primary references:

- https://learn.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-desktop-startuptask
- https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/desktop-to-uwp-extensions
- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask
- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptaskstate
- https://learn.microsoft.com/en-us/uwp/api/windows.applicationmodel.startuptask.requestenableasync

## Engineering decision

Mutation engineering remains gated on a physical supported-API state-transition proof for the exact Windows 11 and Microsoft 365 package combination.

The repository requires exact rollback. Manifest discovery alone cannot prove that an externally orchestrated experiment can restore the captured runtime state. `DisabledByUser`, `DisabledByPolicy`, and `EnabledByPolicy` are ineligible states. A provider may proceed only after a physical probe demonstrates that an eligible captured `Enabled` state can be changed through the supported API and returned exactly to `Enabled` through a documented repeatable supported workflow.

Undocumented `StartupApproved` registry mutation, package re-registration, policy override, task recreation, and direct package-file edits remain outside scope.

## Zero-mutation inventory added in this cycle

`controller/research/Microsoft365StartupTaskInventory.ps1` performs read-only candidate inventory. It records Windows/OEM/elevation and management context, Microsoft 365 package identity, manifest-declared packaged StartupTask IDs and executables, Microsoft publisher identity, related Office startup mechanisms, protected-service/process observations, and machine/user/boot binding. Sensitive local paths are represented by hashes in the evidence artifact.

The inventory intentionally exposes no Apply or Rollback action. Its purpose is to identify whether a physical transition probe has a viable exact candidate while preserving every startup mechanism and protected component.

## Required physical transition probe before provider implementation

Use an eligible unmanaged HP Windows 11 lab profile with the exact installed Microsoft 365 package and preserve raw transition evidence:

1. Run the read-only inventory and require exactly one Microsoft-published package plus exactly one manifest StartupTask attributable to an Office/Microsoft 365 user application or explicitly identified non-servicing helper.
2. Record Windows build, HP model, BIOS, package full name/family/name/version/publisher, StartupTask ID, manifest executable/entry point, resolved executable identity when available, user SID, management state, related Office startup registrations, and protected-application readiness.
3. Resolve the task through the supported `Windows.ApplicationModel.StartupTask` API in an execution context where Microsoft documents that API as valid for the package.
4. Capture the exact runtime state and refuse `DisabledByUser`, `DisabledByPolicy`, `EnabledByPolicy`, ambiguous identity, enterprise ownership, servicing/update/activation/licensing/setup identity, or package drift.
5. For an eligible `Enabled` baseline, invoke `Disable()` once and capture the returned/current runtime state.
6. Verify the disabled state immediately and after a controlled sign-out/sign-in or reboot.
7. Invoke only the supported `RequestEnableAsync()` restoration path from the valid interactive/package context and capture any user-consent UI or returned state.
8. Require exact return to `Enabled` without Task Manager, Settings, undocumented registry writes, policy edits, package re-registration, manifest edits, or package repair.
9. Verify Microsoft 365 manual launch, Click-to-Run servicing/update readiness, protected remote-access readiness, Windows security/update/recovery state, and all unrelated startup registrations.
10. Preserve favorable, adverse, failed, rejected, and inconclusive transition evidence.

## Implementation acceptance gate

A mutation provider may proceed only after the physical probe establishes all of the following:

- exact package and StartupTask identity is reproducibly detectable;
- the candidate is a user-space Office/Microsoft 365 launch path rather than servicing, activation, licensing, repair, setup, security, management, or update infrastructure;
- the captured runtime state is `Enabled` and management ownership is absent;
- supported disablement succeeds;
- supported restoration returns exactly to `Enabled` under a repeatable workflow;
- reboot persistence is observable;
- unrelated packaged StartupTasks and all other startup mechanisms remain unchanged;
- Microsoft 365 servicing and manual application launch remain functional;
- Windows protections and Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged and ready.

If exact supported restoration cannot be reproduced, retain the result as rejected or inconclusive evidence for automated mutation and continue with startup candidates that satisfy the rollback contract.

## Performance benchmark after the gate passes

Use five matched baseline cold boots and five matched treatment cold boots. Retain raw runs and report medians plus dispersion for sign-in-to-usable-desktop latency, first-120-second CPU and disk activity, selected Microsoft 365 launch-chain CPU/disk/working-set/process/network activity, manual Office launch readiness, Click-to-Run servicing readiness, and protected remote-access readiness.

Hold Windows build, HP model, BIOS, Microsoft 365 package/product version, StartupTask identity, related Office startup registrations, power source/mode, thermal state, network state, management state, and instrumentation constant.

## Evidence state

Manifest/API research and zero-mutation inventory engineering are complete for this cycle. Physical package/runtime eligibility, supported state-transition proof, five baseline and five treatment boots, first-120-second attribution, reboot persistence, Microsoft 365 functional checks, protected-application checks, executed exact rollback, medians, dispersion, and instrumentation qualification remain `needs-evidence`.

Release status remains Experimental.
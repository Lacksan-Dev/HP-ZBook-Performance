# EXP-135 research decision: generic packaged StartupTask selection and rollback gate

## Scope

EXP-135 covers exactly one current-user packaged StartupTask belonging to a user application outside the product-specific StartupTask experiments already active in the repository.

The candidate will be selected only after physical attribution shows the highest reproducible first-120-second startup cost among eligible registrations. The owning package, files, data, services, scheduled tasks, Run/RunOnce registrations, Startup folders, settings, supported servicing, Windows security, Windows Update, recovery, enterprise management, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain preserved.

## Supported Windows mechanism

Packaged desktop startup registrations use the `desktop:StartupTask` manifest extension and `Windows.ApplicationModel.StartupTask` runtime API. Relevant runtime operations are `StartupTask.Disable()` and `StartupTask.RequestEnableAsync()`.

Runtime state must be captured physically. `DisabledByUser`, `DisabledByPolicy`, and `EnabledByPolicy` are outside the exact automated restoration boundary. A candidate may advance only when an eligible captured `Enabled` state can be disabled and returned exactly to `Enabled` through a repeatable supported workflow.

Undocumented `StartupApproved` registry edits, policy overrides, package re-registration, manifest edits, package repair, direct package-file changes, and task recreation remain outside scope.

## Zero-mutation inventory added in this cycle

`controller/research/NonAllowlistedStartupTaskInventory.ps1` performs read-only discovery. It records HP Windows 11 and management context, package identity, manifest StartupTask identity, executable version/hash/signature where resolvable, related startup mechanisms, protected-service/process observations, machine/user/boot binding, and explicit candidate classifications.

Candidates attributed to protected, servicing, update, security, credential, accessibility, recovery, driver, firmware, or already-focused Microsoft 365, Teams, or Logitech product paths are excluded from generic selection. Local paths and package-full-name detail are represented by hashes in the evidence artifact where practical.

The inventory exposes only Check and Capture. `mutationSupported` remains false and `selectionStatus` remains `needs-evidence` until physical runtime-state, measured-cost, and restoration evidence satisfy the gate.

## Required physical transition and selection probe

1. Run the read-only inventory on the target HP Windows 11 lab profile and retain the raw artifact.
2. Record Windows build, HP model, BIOS, package name/family/version/publisher, manifest StartupTask ID, executable or entry point, executable version/hash/signature where resolvable, user SID, management state, related startup mechanisms, and protected-application readiness.
3. Capture runtime StartupTask state through the supported Windows API and refuse `DisabledByUser`, `DisabledByPolicy`, `EnabledByPolicy`, ambiguous identity, management ownership, servicing/update identity, protected identity, and any package already covered by a focused active experiment.
4. Measure first-120-second CPU time, disk I/O, working set, process starts, and network activity for each otherwise eligible launch chain across repeated matched startup trials.
5. Select exactly one candidate with the highest reproducible first-120-second startup cost.
6. For an eligible `Enabled` candidate, invoke `StartupTask.Disable()` once through a valid supported context and capture the resulting state.
7. Verify the disabled state immediately and after a controlled sign-out/sign-in or reboot.
8. Invoke only `StartupTask.RequestEnableAsync()` for restoration and capture returned state plus any interactive consent behavior.
9. Require exact return to `Enabled`, followed by a reboot verification.
10. Verify owning-application manual launch and one controlled core function, supported update/servicing readiness where applicable, all unrelated startup mechanisms, Windows protections, and Omnissa, Windows App, Remote Desktop, and Tailscale.
11. Preserve favorable, adverse, failed, rejected, and inconclusive evidence.

## Implementation acceptance gate

Mutation engineering may proceed only after physical evidence establishes all of the following:

- exactly one selected package and StartupTask identity is reproducibly detectable;
- the package falls outside focused active StartupTask experiments;
- the candidate performs user-application launch behavior rather than servicing, security, update, recovery, credential, accessibility, management, device, driver, or protected remote-access work;
- physical attribution establishes the highest reproducible first-120-second startup cost among eligible registrations;
- captured runtime state is `Enabled` and management ownership is absent;
- supported disablement succeeds;
- supported restoration returns exactly to `Enabled` through a repeatable workflow;
- reboot persistence and exact restored state are observable;
- unrelated packaged StartupTasks and other startup mechanisms remain unchanged;
- owning-application function and supported servicing remain functional;
- Windows protections and protected remote-access applications remain unchanged and ready.

If exact supported restoration or measured selection cannot be reproduced, retain the result as rejected or inconclusive evidence and keep mutation engineering gated.

## Performance benchmark after the gate passes

Use five matched baseline cold boots with the captured original state and five matched treatment cold boots with the selected StartupTask disabled. Retain raw trials and report medians plus dispersion for sign-in-to-usable-desktop latency, first-120-second system CPU and disk activity, selected launch-chain CPU/disk/working-set/process/network activity, protected-application readiness, owning-application manual launch/core-function readiness, and supported servicing readiness.

Hold Windows build, HP model, BIOS, package/version, StartupTask identity, executable identity, power source/mode, thermal state, management state, network state, startup inventory, and instrumentation constant.

## Evidence state

Zero-mutation inventory engineering and the physical acceptance gate are complete for this cycle. Physical runtime-state discovery, measured candidate attribution, supported state-transition proof, five matched baseline and treatment cold boots, protected-application checks, owning-application functional checks, servicing checks, reboot persistence, executed exact rollback, medians, dispersion, and instrumentation qualification remain `needs-evidence`.

Release status remains Experimental.

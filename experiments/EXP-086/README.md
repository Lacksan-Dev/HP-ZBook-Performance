# EXP-086: Existing High performance scheme AC comparison

## Status
- Release state: Experimental
- Workflow stage: validation
- Evidence state: needs-evidence
- Stable requires explicit human approval

## Scope
Evaluate one reversible variable on an HP Windows 11 system connected to stable AC power: activate exactly one existing canonical High performance power scheme, compare it with the captured original active scheme, and restore the original scheme exactly.

The experiment selects an existing scheme only. It creates, imports, duplicates, deletes, and edits no scheme. It changes no individual processor, PCIe, USB, display, disk, sleep, battery, network, OEM thermal, BIOS, firmware, driver, service, task, startup, application, security, update, recovery, enterprise-management, Omnissa, Windows App, Remote Desktop, or Tailscale setting.

## Eligibility and refusal
Proceed only when Windows 11, HP hardware, elevation, stable AC power, exactly one active scheme, and exactly one existing canonical High performance scheme are confirmed. The original active scheme must differ from the candidate and remain available for rollback.

Capture Modern Standby capability, supported sleep states, OEM thermal utilities, domain and MDM ownership, PolicyManager, Configuration Manager, provisioning, servicing state, pending restart state, thermal condition, and protected-application readiness.

Refuse application when the candidate is absent, duplicated, corrupted, already active, policy-owned, immediately reverted by another actor, or unsupported by the platform. Refuse during battery operation, active firmware servicing, pending system restart, recovery activity, thermal alarm, or unsupported remote-only validation.

## Current-state capture
Before mutation, store a versioned JSON artifact containing:

- experiment and provider identity
- same-machine identity without serial-number exposure
- UTC capture time
- original active scheme GUID and friendly name
- candidate scheme GUID and friendly name
- complete available-scheme inventory
- AC and battery state
- Windows build, HP model, BIOS, CPU, storage, GPU, drivers, Modern Standby, OEM utility, management, and thermal evidence
- protected-application readiness
- normalized protected-scope snapshot references
- cryptographic hash of normalized state

Application and rollback refuse artifacts from another machine, experiment, provider, schema, original scheme, or candidate scheme.

## Dry run
Dry run performs full support detection and capture, then reports eligibility, refusal reasons, original and candidate identities, AC state, management findings, expected mutation count of one active-scheme selection, verification requirements, and exact rollback target.

Dry run and `-WhatIf` produce zero mutation.

## Application
Application must:

1. Re-run support detection.
2. Validate the captured artifact.
3. Re-read scheme inventory, active scheme, AC state, management state, servicing state, thermal state, and protected scope.
4. Refuse on drift, AC loss, thermal alarm, missing rollback scheme, or policy ownership.
5. Select only the captured existing High performance GUID through the supported Windows power interface.
6. Verify the active GUID immediately.
7. Verify no scheme was created, imported, duplicated, deleted, or edited.
8. Emit structured JSONL events for detection, capture, plan, application, verification, refusal, and failure.
9. Terminate on partial, reverted, or unverifiable state while retaining evidence.

Repeated application against the verified treatment state must be idempotent with zero additional mutation.

## Verification
Immediately and after a controlled restart on AC power, verify:

- the exact candidate GUID remains active
- complete scheme inventory remains unchanged
- no individual power value changed
- OEM thermal mode, BIOS, drivers, devices, services, tasks, startup registrations, security, updates, recovery, and management remain unchanged
- Outlook, Edge, networking, audio, display, dock, sleep, wake, Omnissa, Windows App, Remote Desktop, and Tailscale function normally
- thermal, clock, fan, and power observations remain within declared tolerances

Record any automatic scheme reversal, thermal throttling, fan escalation, sleep or wake regression, application regression, or protected-application regression as adverse or failed evidence.

## Benchmark
Run at least five matched baseline restarts using the original scheme and five matched treatment restarts using High performance. Report raw runs, medians, and dispersion for:

- sign-in to usable desktop
- first-120-second CPU and disk activity
- classic Outlook start to responsive main window
- Edge start to first visible and first interactive window
- first controlled Edge navigation
- wake-to-network readiness where supported
- protected-application readiness
- effective clock, package temperature, throttling indicators, fan behavior, idle package power, and wall-power telemetry where available
- instrumentation overhead

Hold Windows build, BIOS, drivers, application state, startup set, services, AC adapter, dock, display topology, network, thermal settling interval, room conditions, and procedure constant. Missing physical measurements remain needs-evidence.

## Result handling
Success requires at least a 10 percent median reduction in one predeclared primary responsiveness metric with no material regression in reliability, protected applications, thermals, fan behavior, sleep, wake, networking, or idle power beyond the declared tolerance.

Preserve favorable, adverse, failed, rejected, and inconclusive results. Failure evidence includes thermal throttling, unstable clocks, excessive fan activity, power regression, sleep or wake regression, policy conflict, scheme drift, protected-component impact, reboot mismatch, or rollback mismatch.

## Exact rollback
Rollback must validate the original artifact, re-run support checks, confirm both scheme GUIDs still exist, confirm inventory has not drifted, and confirm the current active scheme is the exact treatment GUID.

Refuse rollback when another actor changed the active scheme, the original scheme disappeared, scheme definitions drifted, AC state is unsafe, or management ownership appeared.

Select the exact captured original active scheme GUID, verify restoration, repeat functional and protected-scope checks, and retain the complete JSONL rollback transaction. Rollback deletes no scheme and edits no scheme contents.

## Pester contract
A live provider must test Check, Capture, DryRun, Apply, Verify, VerifyReboot, and Rollback; support and refusal detection; state-artifact identity; `SupportsShouldProcess`; `ShouldProcess`; `-WhatIf`; one-mutation scope; immediate and reboot verification; JSONL logging; sensitive-data exclusion; idempotence; terminating failure handling; drift refusal; exact rollback; and absence of commands that create, import, duplicate, delete, or edit schemes or weaken protected scope.

## Zero-mutation integration
Run Check, Capture, DryRun, and `Apply -WhatIf` against eligible-looking, missing-candidate, ambiguous-candidate, battery-powered, Modern Standby, managed, OEM-enforced, pending-restart, thermal-alarm, and remote-only cases. Compare normalized scheme, registry, service, task, file, package, device, driver, firmware, BIOS, security, update, recovery, management, and protected-application snapshots before and after. Mutation count must remain zero.

## Pending evidence
Physical HP execution, exact scheme identities, AC stability, management ownership, five baseline and treatment trials, responsiveness measurements, thermal and fan observations, protected-application readiness, restart persistence, exact rollback, medians, dispersion, and observer overhead remain needs-evidence.

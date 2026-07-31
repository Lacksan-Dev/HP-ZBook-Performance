# EXP-087: HP Support Solutions Framework Manual demand-start

## Status

- Release state: Experimental
- Workflow stage: validation
- Evidence state: needs-evidence
- Stable assignment: prohibited without explicit human approval

## Purpose

Evaluate one reversible startup-mode change for the exact Windows service owned by HP Support Solutions Framework. The treatment changes the verified service from Automatic or Automatic (Delayed Start) to Manual while preserving its running state during application.

This protocol authorizes no broad HP cleanup. It changes no product, executable, localhost endpoint, scheduled task, package, file, certificate, browser component, device, driver, INF, firmware component, DriverStore content, Windows security control, Windows Update component, recovery setting, enterprise-management setting, or protected remote-access application.

## Candidate selection

Proceed only after local inventory proves all of the following:

1. Windows 11 is running on an HP or Hewlett-Packard business system.
2. The session is elevated.
3. Exactly one installed product identity matches HP Support Solutions Framework.
4. Exactly one Windows service is demonstrably owned by that product.
5. The service executable exists beneath the captured product installation path.
6. The executable has a valid HP Inc. or Hewlett-Packard Authenticode signature.
7. The service is user mode and has no driver, security, update, recovery, credential, accessibility, networking, device-critical, enterprise-management, Omnissa, Windows App, Remote Desktop, or Tailscale dependency.
8. No domain policy, MDM, PolicyManager, Configuration Manager, provisioning package, support contract, remote-support workflow, or fleet-management owner controls continuous service operation.
9. HP product detection and diagnostics can be exercised safely through a declared manual-start or demand-start procedure.
10. Current start mode is Automatic or Automatic (Delayed Start). Disabled, Boot, System, ambiguous, missing, shared-host, or already-Manual states are ineligible.

Refuse mutation when any identity, publisher, dependency, listener, task, management, recovery, or demand-start condition is ambiguous.

## Required support inventory

Capture before any change:

- Windows edition, build, servicing state, pending-reboot state, and last boot time
- HP manufacturer, model, BIOS version, and BIOS date
- AC or battery state, Windows power mode, thermal snapshot, and active power scheme
- product name, publisher, version, uninstall identity, installation path, and architecture
- exact service name, display name, description, startup mode, delayed-start value, running state, process ID, service account, service type, error control, recovery actions, required privileges, triggers, dependencies, and dependent services
- raw service binary command line and resolved executable path
- executable size, version, SHA-256, Authenticode status, signer subject, and signer thumbprint
- associated scheduled tasks, localhost listeners, processes, files, and registry registrations, recorded read-only
- management indicators from domain membership, MDM enrollment, PolicyManager, Configuration Manager, provisioning, service-policy locations, and product enrollment state
- protected-application readiness for Omnissa, Windows App, Remote Desktop, and Tailscale
- baseline Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, device, driver, network, and enterprise-management state hashes or normalized snapshots

Exclude serial numbers, tenant identifiers, user content, credentials, tokens, mailbox data, browser data, and certificate private material from logs.

## State artifact

Store a versioned JSON state artifact before mutation. It must include:

- schema version
- experiment ID `EXP-087`
- provider ID reserved for implementation
- machine identity suitable for same-machine validation without exposing a serial number
- capture timestamp in UTC
- exact product and service identity
- original startup mode, delayed-start state, and running state
- executable path, SHA-256, version, publisher, signature status, signer thumbprint
- dependencies, dependents, recovery actions, triggers, listeners, and management indicators
- protected-scope baseline references
- a cryptographic hash of the normalized captured state

Application and rollback must refuse a state artifact from another machine, experiment, provider, service identity, executable identity, or schema version.

## Dry run

The dry run performs full support detection and current-state capture, then reports:

- eligibility and every refusal reason
- exact service selected
- current startup mode and delayed-start state
- target startup mode `Manual`
- running-state preservation behavior
- expected mutation count, which must equal one service configuration transaction
- required restart and reboot verification steps
- exact rollback target

Dry run and `-WhatIf` must produce zero service, registry, process, listener, task, file, package, device, driver, security, update, recovery, management, or protected-application mutation.

## Application transaction

Application must:

1. Re-run support detection.
2. Load and validate the captured state artifact.
3. Re-read service, executable, signature, dependency, listener, recovery, management, and protected-scope state.
4. Refuse on any drift.
5. Preserve the current running state. Do not stop or restart the service during application.
6. Change only the exact service startup configuration to Manual.
7. Clear delayed automatic start only when it belonged to the captured target service.
8. Verify the exact resulting start mode and delayed-start state immediately.
9. Emit structured JSONL events for support detection, capture validation, planned mutation, mutation result, verification, and failures.
10. Terminate on any partial or unverifiable result and retain all evidence.

Repeated application against the exact verified treatment state must succeed idempotently with zero additional mutations.

## Immediate verification

Confirm:

- exact service identity remains unchanged
- executable path, hash, signature, account, dependencies, dependents, recovery actions, triggers, and listeners remain unchanged
- startup mode equals Manual
- delayed automatic start equals disabled or absent as defined by the implementation contract
- running state equals the captured pre-application state
- HP Support Solutions Framework product identity, files, tasks, localhost endpoint, and certificates remain present
- no protected scope changed
- Omnissa, Windows App, Remote Desktop, and Tailscale remain ready

## Reboot-persistence verification

After a controlled reboot:

1. Verify the same service and executable identities.
2. Verify startup mode remains Manual.
3. Record whether the service stayed stopped, started through a trigger, or started through an HP workflow.
4. Verify HP product detection and the selected diagnostic workflow.
5. Record localhost listener creation and removal behavior.
6. Verify protected applications and normal networking.
7. Compare protected-scope snapshots with baseline.
8. Preserve any unexpected start, failure, listener, task, service-control, or application event as evidence.

A reboot alone does not prove demand-start support. The declared HP workflow must be exercised separately.

## Functional demand-start test

Use one controlled HP product-detection or diagnostic operation whose steps and expected output are recorded before treatment. During treatment:

- record service state and process state before launch
- launch the controlled workflow
- record service-control events, process start, localhost listener state, CPU time, working set, disk I/O, network activity, completion status, and elapsed time
- verify the workflow returns the expected product or diagnostic result
- verify the service reaches a safe post-workflow state

If the workflow requires manual service start, record that as a customer-function tradeoff. If the service cannot start, the localhost endpoint fails, product detection fails, diagnostics fail, or protected applications regress, preserve the result as failed or inconclusive and execute rollback.

## Benchmark design

Run five matched baseline cold boots using the captured original configuration and five matched treatment cold boots using Manual demand-start. Alternate or randomize order where practical and allow Windows Update, HP update activity, indexing, installation activity, and thermal state to settle.

Record raw runs and report medians plus dispersion for:

- sign-in to usable desktop
- first-120-second system CPU and disk activity
- first-120-second CPU time, disk I/O, working set, network activity, localhost activity, and start events attributable to HP Support Solutions Framework
- time until Omnissa, Windows App, Remote Desktop, and Tailscale are ready
- controlled HP product-detection readiness
- controlled HP diagnostic readiness
- service start latency when explicitly requested
- controlled workflow completion time and result correctness
- instrumentation overhead

Hold Windows build, HP model, BIOS, service and product versions, executable hash, drivers, startup registrations, power source, power mode, dock, display topology, network, thermal conditions, and test procedure constant.

Do not invent absent physical measurements. Missing measurements remain `needs-evidence`.

## Success, failure, and inconclusive handling

Success requires a reproducible median reduction in a predeclared startup-latency or resource metric with zero material regression in HP product detection, diagnostics, update behavior, localhost communication, protected-application readiness, security, reliability, recovery, networking, or management.

Failure evidence includes:

- inability to start the service when explicitly requested
- HP product-detection or diagnostic failure
- localhost endpoint failure
- unexpected service, task, listener, file, package, certificate, device, driver, network, security, update, recovery, or management change
- protected-application regression
- reboot-persistence mismatch
- rollback refusal or rollback mismatch

Results below the declared threshold remain Inconclusive or Rejected evidence. Preserve every raw run, failure log, event trace, refusal reason, and rollback record.

## Exact rollback

Rollback must:

1. Load and validate the original state artifact.
2. Re-run support and management detection.
3. Verify product identity, service identity, executable path, executable hash, signature, service account, dependencies, dependents, recovery actions, triggers, listeners, and protected scopes have not drifted.
4. Refuse when the current service configuration differs from the exact treatment state or when another actor owns the setting.
5. Restore the captured startup mode and delayed-start state exactly.
6. Restore the captured running state only after identity and dependency validation.
7. Verify the restored configuration and state.
8. Re-run HP product-detection, diagnostic, localhost, networking, protected-application, and protected-scope checks.
9. Log the complete rollback transaction and retain the state artifact.

Rollback changes no second service and removes no product component.

## Required Pester contract for implementation

A future live provider must test:

- exact experiment, provider, product, service, and executable identities
- every lifecycle action: Check, Capture, DryRun, Apply, Verify, VerifyReboot, and Rollback
- Windows 11, HP hardware, elevation, publisher, product, service, dependency, listener, recovery, management, and demand-start support detection
- refusal of ambiguous, multiple, unsigned, shared-host, protected, policy-owned, already-disabled, and drifted states
- exact current-state capture and state-artifact identity validation
- `SupportsShouldProcess`, `ShouldProcess`, `-WhatIf`, and zero-mutation dry run
- single-service mutation scope
- running-state preservation during application
- immediate and reboot verification
- structured JSONL logging and sensitive-data exclusions
- idempotent repeated application
- terminating failure handling
- exact rollback, overwrite refusal, drift refusal, and rollback verification
- explicit absence of commands that weaken Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, enterprise management, networking, devices, drivers, firmware, or protected applications

## Zero-mutation integration procedure

On Windows 11, execute Check, Capture, DryRun, and `Apply -WhatIf` against:

- an eligible-looking HP system
- a system where the product is absent
- a system with ambiguous service identity
- a domain-joined or MDM-managed system
- a service with dependencies or dependents
- a service with invalid publisher identity
- a system with an active HP support workflow

Before and after each path, compare normalized service, registry, task, process, listener, file, package, device, driver, security, update, recovery, management, network, and protected-application snapshots. Mutation count must remain zero.

## Pending physical evidence

The following remain `needs-evidence`:

- exact local HP Support Solutions Framework product and service identity
- publisher and executable-hash capture
- dependency, recovery, trigger, task, listener, and management inventory
- supported demand-start or declared manual-start behavior
- five baseline and five treatment runs
- HP product-detection and diagnostic checks
- localhost behavior
- reboot persistence
- protected-application readiness
- exact physical rollback execution
- median results and instrumentation overhead

Preserve this issue as Experimental. Never assign Stable automatically.

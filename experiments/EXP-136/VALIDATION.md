# EXP-136 validation gate

Issue: #309
Status: Experimental
Evidence: needs-evidence

## Repository-stage purpose

The repository-stage probe is read-only. It inventories user-logon scheduled tasks, records exact task XML and executable identity, excludes protected and servicing scopes, and accepts physical attribution evidence for deterministic ranking. It cannot disable or re-register a task.

## Candidate-selection gate

A treatment provider may be engineered only after physical evidence identifies exactly one candidate that satisfies every condition below:

1. Windows 11 support is confirmed on the target system.
2. The task has a user-logon trigger or bounded post-logon delay.
3. Exactly one action resolves to one locally present executable.
4. Authenticode status is Valid and publisher/product identity is attributable to the user application.
5. The task has no security, credential, accessibility, recovery, update, servicing, driver, firmware, enterprise-management, or protected remote-access purpose.
6. A more specific active experiment does not cover the same product and startup mechanism.
7. At least five physical attribution trials exist for the task.
8. Attribution includes first-120-second CPU time and disk I/O, with process starts, working set, and network activity captured when instrumentation supports them.
9. The highest measured startup-cost candidate is unique. A tie remains inconclusive.
10. Manual launch and one controlled core function can be exercised after treatment.

## Mutation contract for the later provider

The dedicated treatment provider must implement Check, Capture, DryRun, Apply, Verify, VerifyReboot, and Rollback. It must capture the complete original task XML before mutation, change only the selected task enabled state, use `ShouldProcess` and `-WhatIf`, emit structured JSONL evidence, preserve terminating failure evidence, and refuse task-definition, executable, product, management, or protected-scope drift.

Application may alter no Run or RunOnce value, Startup-folder registration, packaged StartupTask, service, package, application file, device, driver, firmware, security, update, recovery, credential, accessibility, enterprise-management, Omnissa, Windows App, Remote Desktop, or Tailscale configuration.

## Exact rollback acceptance gate

Before any treatment provider can merge, demonstrate from a physical fixture that:

1. The captured task path and task name still resolve to the same task.
2. The captured XML SHA-256 still matches the pre-treatment definition except for the permitted enabled-state transition representation.
3. The action executable path, Authenticode publisher, SHA-256, product identity, and version have not drifted.
4. Management ownership and protected-scope snapshots have not drifted.
5. Restoring the captured enabled state returns the task to exact observed behavior.
6. If Task Scheduler requires XML re-registration to recover exact state, re-registration uses only the captured XML after all drift checks pass.
7. A post-rollback reboot confirms the captured task state and XML identity.
8. Manual application launch, the controlled core function, supported servicing, Omnissa, Windows App, Remote Desktop, and Tailscale pass their recorded checks.

Any collision, drift, functional regression, ambiguous attribution, rollback mismatch, or instrumentation failure is retained as failed or inconclusive evidence.

## Physical benchmark

Run five matched baseline cold boots and five matched treatment cold boots. Retain raw trials and report medians plus dispersion for usable-desktop readiness, first-120-second system CPU and disk activity, attributable launch-chain resource cost, protected-application readiness, manual application launch, one controlled core function, and supported servicing readiness where applicable.

Record Windows build, HP model, BIOS, task XML hash, executable/product version and hash, power source, power mode, thermal state, management state, network condition, and instrumentation overhead.

Stable assignment remains outside this experiment.

# EXP-088: HP Support Assistant Quick Start task

## Candidate
Disable one verified HP Support Assistant Quick Start scheduled task by changing its enabled state only. The provider refuses broad matches, multiple candidates, unsigned actions, non-logon triggers, protected purposes, and managed systems.

## Zero-mutation integration
1. Run `Check`, then `Capture` and `DryRun` on an elevated HP Windows 11 test system.
2. Hash exported scheduled-task XML before and after each action.
3. Confirm DryRun changes no task, service, package, file, certificate, device, driver, firmware, security, update, recovery, management, or protected remote-access state.
4. Exercise unsupported, managed, zero-candidate, multiple-candidate, unsigned, non-logon, and protected-purpose refusal cases.
5. Run the Pester contract suite.

## Physical validation
Record Windows build, HP model, BIOS, HP Support Assistant and framework versions, task identity and XML hash, action executable version and SHA-256, drivers, AC state, power mode, thermal state, network, and instrumentation overhead. Run five matched baseline cold boots and five matched treatment cold boots. Retain every raw run and report medians plus dispersion for usable-desktop latency, first-120-second CPU and disk activity, relevant process starts and network activity, Outlook readiness, Edge readiness, and Omnissa, Windows App, Remote Desktop, and Tailscale readiness.

Before application, immediately after application, after reboot, and after rollback, verify manual HP Support Assistant launch, controlled diagnostics, controlled update discovery, exact task identity, and protected-component readiness. Missing physical results remain `needs-evidence`. Preserve favorable, adverse, failed, and inconclusive evidence.

## Apply and persistence
Use a captured state file and JSONL log. Apply must disable one exact task and preserve its XML. Verify immediately and after reboot. Any task-definition, executable, publisher, ownership, or management drift ends the run as a failure and preserves evidence.

## Exact rollback
Rollback accepts only the same machine, user, experiment, provider, task path, task name, and unchanged XML hash. Restore the captured enabled state with `Enable-ScheduledTask`; never recreate or overwrite the task definition. Verify exact XML equality and enabled state, then repeat HP workflows and protected-application checks.

## Safety boundary
Preserve Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, credentials, accessibility, enterprise management, device-critical drivers, firmware, HP Support Assistant installation and update capability, Omnissa, Windows App, Remote Desktop, and Tailscale. Experimental only. Stable requires explicit human approval.

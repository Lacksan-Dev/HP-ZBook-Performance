# EXP-082 engineering report

## Candidate

Apply the documented Windows Search policy pair as one reversible transaction:

- `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search\DisableWebSearch` = `REG_DWORD 1`
- `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search\ConnectedSearchUseWeb` = `REG_DWORD 0`

The candidate changes policy values only. Search service configuration, index data and scope, packages, tasks, executables, firewall rules, DNS, Edge, Windows security, updates, recovery, enterprise management, device-critical drivers, and protected remote-access applications remain unchanged.

## Support and refusal controls

The implementation requires an elevated supported Windows 11 Pro, Enterprise, Education, or IoT Enterprise build. It refuses domain membership, MDM enrollment, PolicyManager ownership, Configuration Manager presence, existing configured target values, unsupported editions or builds, missing state, machine identity mismatch, target drift, and rollback drift.

## Transaction behavior

`Capture` records whether the policy key existed and, for each target, whether the value existed, registry type, and exact value. `DryRun` and `-WhatIf` produce zero mutation. `Apply` writes both values within one guarded operation and verifies the complete pair. Repeated application is idempotent. `Verify` records Search UI restart guidance. `VerifyReboot` verifies persistent target state and records the boot time. `Rollback` requires the complete applied identity, restores captured values exactly, removes experiment-created values, and removes the policy key only when the experiment created it and it remains empty.

Every action writes JSONL events with UTC timestamp, experiment, action, event, result, and structured data. Terminating failures also produce a structured failure event.

## Validation state

Static Pester contract coverage and zero-mutation integration guidance are included. Physical execution remains `needs-evidence`.

Required physical evidence:

1. Five matched baseline and five treatment trials using the same local query set and network condition.
2. Median invocation-to-first-rendered-local-result, keyboard-selectable-result, and launched-local-application timings.
3. SearchHost CPU, disk, memory, and network activity during the controlled query set.
4. Sign-in, Outlook, Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
5. Local application, setting, file, and indexed-content Search behavior before and after treatment.
6. Search UI restart behavior, reboot persistence, exact rollback execution, and post-rollback behavior.
7. Preservation of favorable, adverse, failed, and inconclusive evidence.

Release state remains Experimental. Stable requires explicit human approval.

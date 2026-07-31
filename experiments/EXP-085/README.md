# EXP-085: Logitech Gaming Software exact-version removal protocol

## Status

Experimental validation design. Physical execution and performance measurements remain `needs-evidence`. Preserve favorable, adverse, failed, rejected, and inconclusive evidence. Stable assignment requires explicit human approval.

## Focused candidate

Remove exactly one verified Logitech Gaming Software user-space product installation through its captured supported uninstall mechanism. The candidate may remove only product-owned user-space application components. It must preserve Logitech and Windows HID, USB, Bluetooth, audio, receiver, keyboard, mouse, headset, camera, firmware, onboard profiles, existing pairing, device-critical drivers, Windows security, Windows Update, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Required support detection

Application must terminate before mutation unless every condition passes:

1. Windows 11 and elevation are detected.
2. Exactly one uninstall inventory entry identifies Logitech Gaming Software.
3. Publisher resolves to Logitech or Logi.
4. Product name, display version, architecture, product code or uninstall identity, install location, uninstall command, quiet uninstall command, and registry source are captured.
5. The uninstall command is parsed into an executable and arguments without shell interpretation.
6. The command contains no driver-store, PnP, firmware, receiver-pairing, device-removal, broad wildcard, PowerShell, command-shell, or script-host operation.
7. A local offline installer matching the captured product version and architecture is supplied before application.
8. Installer path, size, SHA-256, Authenticode status, publisher, product metadata, and version are captured.
9. The rollback installer publisher is valid Logitech or Logi and its version matches the captured product version.
10. Domain, MDM, PolicyManager, Configuration Manager, provisioning, software-deployment, and pending-servicing checks show no management owner or pending reboot conflict.
11. Protected-scope capture succeeds.

Refuse absent, ambiguous, multiple, unsigned, version-mismatched, hash-drifted, enterprise-managed, pending-reboot, shared-driver, unsafe-command, or unsupported product states.

## Current-state capture

Create a schema-versioned state artifact before mutation. Refuse overwrite. Bind the artifact to EXP-085, provider version, machine identity, Windows build, user SID, capture time, and boot time. Capture:

- uninstall inventory source, key path, product name, publisher, version, architecture, product code, install location, uninstall command, and quiet uninstall command
- exact parsed executable and argument array
- installer path, SHA-256, size, file version, product version, signature status, signer subject, signer thumbprint, and timestamp
- product-owned processes with executable paths, versions, hashes, and signer identities
- product-owned services with names, display names, startup modes, delayed-start states, running states, accounts, dependencies, dependents, binary paths, executable hashes, and signatures
- product-owned scheduled tasks with paths, names, XML, XML hashes, enabled states, actions, triggers, principals, and last-run data
- product-owned Run, RunOnce, Startup-folder, and StartupTask registrations with exact value types, raw data, shortcut bytes, metadata, or manifest identity
- installation-directory inventory with relative paths, sizes, hashes, signatures, ACL summaries, and timestamps, excluding user content and secrets
- Logitech PnP devices, driver versions, provider names, INF identities, receiver state, Bluetooth identities, and Device Manager problem codes as read-only preservation evidence
- Windows security, update, recovery, management, and protected remote-access snapshots

Do not collect profile contents, macros, credentials, device serial numbers, message content, browser data, network endpoints, or unrelated user files.

## Dry run and `-WhatIf`

Dry run must perform the complete support, identity, installer, management, protected-scope, and rollback-readiness evaluation. It must report one planned uninstall transaction, expected product-owned user-space components, exact rollback media, verification plan, refusal reasons, and expected reboot requirement. Dry run and `-WhatIf` must produce zero mutations.

## Application

Application may invoke only the captured supported silent uninstall command for the exact product identity. Use `ShouldProcess`. Record process ID, start time, exit time, exit code, standard error summary, and timeout result. Treat undocumented or non-success exit codes as terminating failures. Do not perform broad post-uninstall deletion. Do not remove devices, drivers, INF packages, DriverStore content, firmware, pairing, certificates, security controls, update components, recovery components, or management agents.

When the uninstaller reports reboot required, preserve that status and proceed only to pre-reboot verification. Never synthesize success before post-reboot verification.

## Immediate verification

Verify that the exact uninstall identity is absent and expected product-owned user-space processes have exited. Verify product-owned services, scheduled tasks, and startup registrations against the captured inventory without wildcard deletion. Record retained files and registrations as residual evidence rather than deleting them broadly. Confirm protected scope, device inventory, driver inventory, receiver or Bluetooth state, and Device Manager problem codes remain unchanged.

## Reboot persistence

After a controlled reboot, verify the captured product identity remains absent, product-owned user-space auto-launch activity remains absent, and no unexpected Logitech Gaming Software process or service starts. Repeat protected-scope, device, driver, pairing, security, update, recovery, management, and remote-access checks. Any drift is failure evidence and triggers rollback evaluation.

## Structured logging

Write append-only JSONL records containing schema version, UTC timestamp, experiment, provider version, machine-bound state reference, action, phase, result, mutation count, exit code, reboot-required state, verification result, refusal reason, and sanitized failure details. Exclude credentials, command-line secrets, device serial numbers, user content, mailbox data, browser data, and network tokens.

## Idempotence and failure handling

Repeated Check and DryRun operations must remain mutation-free. Repeated Apply after verified removal must return an idempotent result with zero mutations. Repeated Rollback after verified restoration must return an idempotent result with zero mutations. Failures must terminate, retain state and logs, preserve partial evidence, and avoid broad cleanup.

## Exact rollback

Rollback is permitted only when the state artifact passes machine, user, experiment, provider, product, installer, signature, version, architecture, and SHA-256 validation. Refuse rollback if another Logitech Gaming Software identity is present, the rollback installer changed, management ownership appeared, protected scope drifted materially, or device and driver preservation cannot be established.

Invoke only the captured exact-version installer through its documented silent installation mechanism. Verify successful exit code and reboot requirement. After installation and any required reboot, verify:

- exact product name, publisher, version, architecture, product code or uninstall identity, and install location
- expected product-owned services, tasks, startup registrations, and executables
- basic keyboard, mouse, receiver, Bluetooth, audio, headset, and camera operation for connected Logitech devices
- advanced macros, lighting, profile switching, onboard-profile interaction, and software-managed audio features that were present before removal
- unchanged Logitech and Windows device-critical drivers, INF identities, firmware, pairing, and Device Manager state
- unchanged Windows security, update, recovery, enterprise-management, and protected remote-access state

Rollback must never restore state by copying captured program files or registry exports over a changed installation. The exact signed installer is the rollback mechanism.

## Pester contract requirements

Tests must cover support detection; strict single-product matching; Logitech publisher validation; installer version, architecture, signature, and hash checks; unsafe command refusal; enterprise-management and pending-reboot refusal; state overwrite refusal; machine and user binding; zero-mutation DryRun and `-WhatIf`; exact command invocation; exit-code handling; immediate and reboot verification; structured-log schema; idempotent Apply and Rollback; product, installer, management, protected-scope, device, driver, and hash drift refusal; protected-component exclusions; and exact-version rollback verification.

Parser tests must reject command shells, PowerShell, script hosts, PnP utilities, driver-store tools, firmware tools, device-removal tools, wildcard cleanup, and commands that reference products beyond the captured Logitech Gaming Software identity.

## Integration procedure

Use an isolated HP Windows 11 validation machine with connected representative Logitech devices and exact rollback media.

1. Capture before-state inventories and hashes.
2. Run Check, Capture, DryRun, and Apply `-WhatIf`; compare before and after snapshots and require zero mutation.
3. Execute Apply and immediate verification.
4. Reboot and execute persistence verification.
5. Test basic devices, advanced features, Omnissa, Windows App, Remote Desktop, and Tailscale.
6. Execute exact rollback and verification.
7. Reboot and repeat functional and protected-scope checks.
8. Retain every log, state artifact, raw measurement, refusal, failure, and residual finding.

## Physical measurement plan

Run five matched baseline sign-ins and five matched treatment sign-ins under controlled AC power, power mode, network, thermal, connected-device, Windows build, BIOS, driver, and application conditions. Report raw runs, medians, dispersion, and instrumentation overhead for sign-in to usable desktop, first-120-second system CPU and disk activity, Logitech user-space CPU and I/O, idle process count and working set, Outlook readiness, Edge readiness, and Omnissa, Windows App, Remote Desktop, and Tailscale readiness.

A favorable conclusion requires a reproducible responsiveness or resource improvement with zero basic-device, protected-application, security, update, recovery, management, or rollback regression. Advanced-feature loss must be reported as customer-effect evidence. Missing physical measurements remain `needs-evidence` while safe engineering continues.
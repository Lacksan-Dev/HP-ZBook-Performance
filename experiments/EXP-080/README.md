# EXP-080: Logitech Download Assistant Run-registration removal

## Status

Experimental. Physical measurements remain `needs-evidence`. Stable remains excluded.

## Focused candidate

Remove exactly one verified Logitech Download Assistant auto-launch value from one approved Run location:

- `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
- `HKLM\Software\Microsoft\Windows\CurrentVersion\Run`
- `HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`

The experiment changes one registry value only. It preserves the Logitech Download Assistant executable, installed Logitech products, services, scheduled tasks, packages, PnP devices, driver-store packages, receiver pairing, firmware, and basic keyboard and mouse operation.

## Support detection and refusal rules

Proceed only when all conditions pass:

1. Windows 11 is detected on an HP or Hewlett-Packard system.
2. Elevation is present for machine-wide values.
3. Domain join, MDM enrollment, PolicyManager ownership, Configuration Manager ownership, and enforced startup policy are absent.
4. Exactly one eligible Run value exists across the approved locations.
5. The exact value name and unexpanded command identify Logitech Download Assistant.
6. The resolved executable is a regular file under a Logitech or Logi application directory.
7. Authenticode status is valid and the signer identifies Logitech or Logi.
8. The command is a user-space launch command and does not invoke an installer, uninstaller, repair workflow, firmware tool, pairing tool, driver tool, service controller, scheduled-task controller, PowerShell, `cmd.exe`, `rundll32.exe`, or another command interpreter.
9. The value identity does not match Omnissa, Windows App, Remote Desktop, Tailscale, Windows Security, Windows Update, recovery, credentials, accessibility, enterprise management, or a device-critical component.

Refuse absent, ambiguous, multiple-candidate, unsigned, publisher-mismatched, path-mismatched, enterprise-managed, protected, interpreter-based, installer-related, driver-related, firmware-related, pairing-related, or already-mutated states.

## Current-state capture

Before mutation, write a schema-versioned state artifact containing:

- Experiment and provider identifiers
- Capture time in UTC
- Machine name and current user SID
- Windows edition, build, HP manufacturer, and model
- Management-detection signals
- Registry hive, path, view, value name, value existence, exact value type, and unexpanded value data
- Expanded command and resolved executable path
- Executable SHA-256, file version, product name, company name, Authenticode status, signer subject, and signer thumbprint
- Registry key owner and SDDL where available
- Protected-scope inventory hashes or normalized snapshots

The state path must be supplied explicitly. Capture must refuse overwriting an existing state artifact. Logs and state artifacts must exclude usernames beyond the SID, email addresses, tenant identifiers, tokens, secrets, document paths, browser data, and command-line content unrelated to the selected registration.

## Dry run

`DryRun` and `-WhatIf` must execute support detection, candidate discovery, signature inspection, protected-scope checks, and proposed-state calculation without changing registry, files, services, tasks, packages, devices, drivers, firmware, networking, security, updates, recovery, management state, or protected remote-access applications.

The result must report the exact registry value that would be removed, the executable identity, refusal reasons, mutation count, reboot-persistence requirement, and rollback requirements.

## Application

Application must:

1. Read and validate the captured state artifact.
2. Re-run support, management, candidate, executable, signature, and protected-scope detection.
3. Refuse machine, user, registry, executable, publisher, policy, or protected-scope drift.
4. Remove only the captured Run value through `ShouldProcess`.
5. Verify immediate absence of the exact value.
6. Record one structured JSONL event for support detection, capture validation, proposed mutation, mutation result, verification result, and any failure.

A repeated application after successful removal must return an idempotent success with zero mutations, provided the state artifact still matches the machine and the target remains absent.

## Verification

Immediate verification requires:

- The exact Run value is absent.
- No second Run value changed.
- The Logitech Download Assistant executable and installation remain present.
- No Logitech service, task, package, device, driver, receiver, pairing, or firmware state changed.
- Windows Security, Windows Update, recovery, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged.

Reboot-persistence verification requires a boot time later than the captured application event, continued absence of the exact value, no Logitech Download Assistant sign-in launch, and repeated protected-scope checks.

## Failure handling

All detection, capture, mutation, verification, and rollback failures must terminate with a nonzero result and append a structured failure event containing the stage, exception type, bounded message, and evidence-artifact reference. Preserve rejected, failed, adverse, and inconclusive evidence. Never replace a failed record with a later successful run.

## Exact rollback

Rollback must:

1. Validate schema version, experiment, provider, machine, user SID, registry location, value identity, and captured original state.
2. Refuse rollback if the target value already exists, the registry location is policy-owned, the executable path or SHA-256 drifted, Authenticode status or signer identity drifted, or protected scope changed.
3. Recreate the exact registry key only when required.
4. Restore the original value name, value type, and unexpanded value data exactly.
5. Verify exact equality after restoration.
6. Reboot and verify restored auto-launch behavior, peripheral readiness, and protected-application readiness.

Rollback must never reinstall software, recreate tasks, alter services, modify devices or drivers, touch firmware or pairing state, or overwrite a value created by another actor.

## Pester contract

Tests must cover:

- PowerShell parser success
- Complete `Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback` lifecycle
- HP Windows 11 and elevation detection
- Domain, MDM, PolicyManager, Configuration Manager, and startup-policy refusal
- Approved registry paths and registry-view handling
- Single-candidate enforcement
- Exact value-name, executable-path, file-name, and publisher validation
- Command-interpreter, updater, installer, repair, uninstall, firmware, pairing, driver, service, task, and protected-identity refusal
- Exact unexpanded registry capture and value-kind restoration
- State-artifact overwrite refusal
- Machine, user, executable-hash, signer, registry, policy, and protected-scope drift refusal
- Dry run, `ShouldProcess`, structured JSONL logging, idempotence, and terminating failure behavior
- Immediate and reboot-persistence verification
- Exact rollback and rollback-overwrite refusal
- A forbidden-mutation token list covering package, service, task, PnP, driver, firmware, security, update, recovery, network, and protected-application changes

## Zero-mutation integration procedure

The repository integration test must parse the provider, validate manifest registration, inspect required lifecycle and safety tokens, inspect forbidden mutation tokens, and compare normalized before-and-after snapshots while invoking only `Check`, `Capture` to a temporary path, `DryRun`, and `-WhatIf`.

The snapshot must include approved Run locations, Logitech services and tasks, installed Logitech products, Logitech PnP devices, signed drivers, Windows Security services and policy, Windows Update services and policy, recovery configuration, enterprise-management signals, network adapters and bindings, and process or readiness observations for Omnissa, Windows App, Remote Desktop, and Tailscale. Delete only temporary test artifacts after comparison.

## Physical validation

Use five matched baseline sign-ins and five matched treatment sign-ins on the same HP Windows 11 machine. Hold Windows build, BIOS, drivers, installed applications, network, AC power, power mode, thermal state, startup profile, instrumentation, test order, and idle-settling interval constant.

Record raw runs and report medians plus dispersion for:

- Sign-in to usable desktop
- Aggregate CPU utilization during the first 120 seconds
- Aggregate disk activity during the first 120 seconds
- Logitech Download Assistant process presence and resource use
- Omnissa, Windows App, Remote Desktop, and Tailscale readiness

Before treatment, immediately after treatment, after reboot, and after rollback, verify basic Logitech keyboard, mouse, receiver, and Bluetooth operation where present; Device Manager health; Windows Security; Windows Update; recovery; enterprise management; and protected remote-access readiness.

Physical execution, matched timing measurements, peripheral checks, reboot persistence, exact rollback execution, instrumentation-overhead qualification, medians, and dispersion remain `needs-evidence`.
# EXP-160 Startup-folder registration validation contract

Release state: Experimental

Evidence state: `needs-evidence`

## Scope

EXP-160 removes exactly one priority non-allowlisted Startup-folder registration selected by the normalized EXP-143 inventory. The only permitted production mutation is deletion of the selected file or shortcut from the current-user or common Startup folder. Application binaries, services, scheduled tasks, packages, drivers, firmware, security controls, update mechanisms, recovery state, enterprise management, and unrelated startup registrations remain outside scope.

The existing `controller/providers/InventoryBoundStartupFolderRemoval.ps1` implementation currently carries the unrelated experiment identifier `EXP-155` in its default state path, default JSONL log path, persisted experiment identity, and associated tests. EXP-155 belongs to an Edge new-tab experiment. No EXP-160 physical execution should use that provider until the identity is corrected consistently to EXP-160 and repository checks pass.

## Support detection

Proceed only when all conditions pass:

1. Windows 11 is detected on an HP or Hewlett-Packard system.
2. Required elevation is present for the selected Startup-folder surface.
3. A real EXP-143 selection artifact identifies exactly one `priority-target` record with surface `StartupFolder` and a non-empty inventory hash.
4. The selected path resolves under only the current-user or common Startup folder.
5. The selected file exists and its exact path, bytes, SHA-256, timestamps, attributes, ACL, and shortcut metadata where applicable can be captured.
6. A shortcut target resolves to a real executable. Shortcut arguments require separate qualification rather than broad acceptance.
7. Executable publisher, product, version, SHA-256, and signature are captured and agree with the selected user-application identity.
8. Enterprise, domain, MDM, ConfigMgr, provisioning, or other external management ownership is absent unless explicitly placed in experiment scope.
9. The selected registration has no protected Windows, security, credential, accessibility, update, recovery, device-driver, firmware, Omnissa, Windows App, Remote Desktop, or Tailscale identity or dependency.
10. Logitech HID, keyboard, mouse, receiver, Bluetooth, audio/video, and device-critical driver functions remain outside the mutation surface.

Refuse absent, ambiguous, multiple, unsigned, identity-mismatched, protected, externally managed, argument-ambiguous, or outside-surface selections.

## Exact current-state capture

Before any mutation capture at minimum:

- experiment identity `EXP-160`
- machine identity and current user SID
- Windows build, HP model, BIOS, boot identity, power source, power mode, and available thermal state
- EXP-143 selection artifact identity and inventory hash
- Startup surface and absolute selected path
- raw file bytes encoded in the machine-local state artifact
- SHA-256, length, creation time, last-write time, last-access time, attributes, owner, and ACL/SDDL
- shortcut target, arguments, working directory, icon, description, window style, and hotkey where applicable
- resolved executable path, product, version, SHA-256, signature status, publisher, and certificate thumbprint
- normalized snapshot and hash of both Startup folders
- protected startup registrations and protected service configuration
- management ownership indicators

Raw machine evidence remains machine-local. Only bounded sanitized evidence may enter the repository.

## Dry run

Dry run and `-WhatIf` must perform full support and drift detection while producing zero production mutation. The result must declare exactly one proposed deletion, its selected path and inventory hash, the protected scopes preserved, reboot verification requirement, exact rollback method, and `needs-evidence` state.

## Application

Application may delete only the selected registration after revalidating:

- machine and user binding
- EXP-160 state identity
- selection and inventory hash
- exact candidate file hash and shortcut metadata
- executable identity, signature, and hash
- management state
- protected scope
- unchanged unrelated Startup-folder snapshot

Repeated application must be idempotent. If the selected registration is already absent and all drift checks pass, record an idempotent zero-mutation result.

## Verification

Immediate verification requires:

- selected registration absent
- all unrelated Startup-folder registrations unchanged
- protected registrations and protected service configuration unchanged
- resolved application executable still present and identity-equivalent
- no package, application, service, task, driver, firmware, security, update, recovery, or enterprise-management mutation

Any mismatch is failed or inconclusive evidence and triggers rollback eligibility evaluation.

## Structured logging

Write JSONL records containing schema version, UTC timestamp, experiment `EXP-160`, action, event, result, machine identity, user SID, bounded before/after evidence, refusal reason where applicable, failure type/message, and `needs-evidence` when physical proof remains missing. Do not log secrets, credentials, tenant identifiers, raw profile data, or sensitive clipboard/content data.

## Reboot persistence

`VerifyReboot` must require a boot identity later than the captured boot. It must revalidate candidate absence, selection/executable identity, management ownership, unrelated Startup-folder snapshot, and protected configuration. A same-boot verification must refuse rather than infer persistence.

## Exact rollback

Rollback restores exactly the captured file bytes, timestamps, attributes, ACL, and shortcut content only when all drift checks pass. It must refuse overwrite when the original path has acquired any conflicting object or when executable, management, unrelated Startup-folder, protected, or selection identity has drifted.

Rollback must verify byte-for-byte SHA-256 equality and normalized shortcut metadata equality. A later reboot must confirm restoration persistence and protected-application readiness.

## Required tests

Pester and zero-mutation Windows integration coverage must verify:

- PowerShell parsing
- lifecycle actions `Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback`
- identity is consistently `EXP-160`, with no `EXP-155` state path, log path, environment variable, test title, or persisted experiment identity
- EXP-143 `priority-target` and `StartupFolder` selection binding
- current-user and common Startup-folder allowlist
- exact bytes, hash, timestamps, attributes, ACL, and shortcut metadata capture
- protected-scope refusal
- argument-bearing shortcut refusal pending separate qualification
- zero mutation in `Check`, `DryRun`, and `Apply -WhatIf`
- single-file deletion boundary
- idempotent repeated application
- later-boot requirement
- unrelated Startup-folder drift refusal
- conflicting-path rollback refusal
- exact content restoration
- absence of broad package, service, scheduled-task, PnP, firewall, Defender, driver, or firmware mutation

## Physical validation

Physical measurements remain `needs-evidence` until a real EXP-143 inventory selects the exact registration. Then run at least five matched baseline and five matched treatment cold boots or sign-ins under comparable conditions. Retain raw trials and report medians plus dispersion for sign-in to usable desktop, first-120-second CPU and disk activity, attributable selected-application activity where measurable, manual application readiness, supported update-path readiness, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

Record Windows build, HP model, BIOS, application and executable versions/hashes, relevant driver versions, power source/mode, thermal state, instrumentation overhead, benchmark order, and failures. Preserve favorable, adverse, failed, rejected, and inconclusive evidence.

## Merge gate

An EXP-160 implementation PR is mergeable after repository checks pass, the provider and tests consistently identify EXP-160, mutation remains limited to one selected Startup-folder registration, exact original-state capture exists, dry run and verification exist, structured logging and idempotence exist, reboot persistence is enforced, sensitive-data review passes, and exact collision-safe rollback exists.

Never assign Stable from this experiment automatically.
# EXP-143 Startup Registration Inventory

Release state: Experimental
Evidence state: needs-evidence
Parent: EXP-002

## Purpose
Produce one deterministic, read-only evidence bundle covering every approved EXP-002 startup-registration surface before selecting another mutation candidate.

## Inventory surfaces
1. Current-user and all-users Startup folders. Record path, file identity, SHA-256 where readable, and shortcut target/arguments/working directory where resolvable.
2. Approved HKCU/HKLM Run and RunOnce locations in applicable 32-bit and 64-bit registry views. Record hive, path, view, value name, value kind, and exact unexpanded value data.
3. Packaged application StartupTask registrations. Record package family/full name, application/task identity, entry point or executable evidence, registration source, and current state.
4. Scheduled tasks containing a user-logon trigger. Record task path/name, principal, enabled state, actions, triggers, exported XML, and SHA-256 of canonical evidence where available.

## Classification
Every registration receives one classification and a reason:

- `protected`: Omnissa, Windows App, Remote Desktop, Tailscale, Windows security, credential, accessibility, device-driver, recovery, update, or externally owned management components.
- `priority-target`: Teams, Microsoft Office/Microsoft 365 quick-launch behavior, Logitech/Logi Options+, Logi Bolt, Logi Tune, G Hub tray/telemetry/updater, or another clearly user-space priority registration.
- `other-user-application`: user application outside the protected scope.
- `review-required`: identity or ownership evidence is insufficient for safe classification.

Logitech HID, keyboard, mouse, receiver, Bluetooth, and device-critical driver registrations always remain outside cleanup candidacy.

## Zero-mutation invariant
This experiment performs inventory only. The provider must verify that startup-registration state hashes before and after collection match. Any detected mutation invalidates the run and is preserved as failed evidence.

## Deterministic output
The implementation must emit:

- `startup-inventory.normalized.json`: deterministic ordering and normalized fields across all four surfaces.
- `startup-inventory.jsonl`: structured collection/classification events.
- `machine-metadata.json`: Windows build, device, BIOS, discoverable relevant application versions, power source, and collection timestamp.
- `startup-inventory.sha256`: SHA-256 of the normalized JSON snapshot.

Repeated inventory against unchanged state must reproduce the normalized snapshot hash. Volatile timestamps belong in metadata/log output rather than the normalized snapshot.

## Candidate selection
Select exactly one reversible registration after inventory. Ranking order:

1. priority target with physical first-120-second CPU/disk attribution;
2. priority target with strong executable/product identity but physical attribution pending;
3. other user application with strong identity evidence.

Never infer a performance gain from static inventory. Without physical attribution, candidate performance remains `needs-evidence`.

The four mutation-family experiments already exist: EXP-144 Run/RunOnce, EXP-145 StartupTask, EXP-146 Startup folder, and EXP-147 sign-in scheduled task. Route the selected registration to the matching experiment rather than creating a duplicate product-name-only experiment.

## Physical evidence request
Run the read-only provider on the HP ZBook and retain the complete evidence bundle. When available, attach first-120-second CPU/disk attribution under comparable startup conditions. Physical performance work uses repeated runs, raw trials, medians, and dispersion.

## Safety acceptance criteria
- zero startup mutations;
- all four registration surfaces inventoried or explicitly reported unsupported/unavailable;
- protected entries classified conservatively;
- deterministic normalized snapshot and hash;
- structured JSONL evidence;
- duplicate/cross-surface identities retained;
- candidate selection references an exact inventory identity;
- missing physical evidence recorded as `needs-evidence`;
- no Stable assignment.
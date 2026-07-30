# EXP-058 Validation Protocol

## Candidate boundary

Evaluate removal of exactly one Microsoft 365 desktop-application shortcut from the current user's Startup folder. The eligible shortcut must resolve to OUTLOOK.EXE, WINWORD.EXE, EXCEL.EXE, POWERPNT.EXE, ONENOTE.EXE, or MSACCESS.EXE and must contain no command-line arguments.

This protocol changes no Microsoft 365 installation files, Click-to-Run components, services, scheduled tasks, packages, profiles, credentials, documents, add-ins, Windows security controls, update controls, recovery controls, enterprise-management state, device drivers, or protected remote-access applications.

## Support detection

Record and require:

- Windows 11
- HP or Hewlett-Packard manufacturer identity
- current-user Startup folder resolved through the Windows Known Folder API
- Microsoft 365 Click-to-Run configuration and version
- exactly one eligible shortcut
- resolved shortcut target exists and matches the approved executable allowlist
- empty shortcut arguments
- no domain join, MDM enrollment, PolicyManager device state, or Configuration Manager client

Refuse the candidate when identity is ambiguous, more than one eligible shortcut exists, the target cannot be resolved, the shortcut is outside the current-user Startup folder, or the shortcut references update, servicing, telemetry, protected remote-access, security, recovery, accessibility, credential, or device-driver components.

## Current-state capture

Before mutation, preserve:

- absolute shortcut path and Startup-folder path
- shortcut file bytes encoded for exact restoration
- SHA-256
- file length
- creation and last-write timestamps in UTC
- file attributes
- resolved target path
- arguments
- working directory
- icon location
- description
- window style
- computer name and current-user SID
- Windows build, HP model, BIOS, storage driver, display driver, Microsoft 365 version, power source, and thermal state

Store structured state separately from JSONL execution logs. Reject state from another machine, user SID, experiment identifier, Startup-folder path, or schema version.

## Dry run

The dry-run path performs support detection, enterprise-management refusal checks, shortcut discovery, target resolution, allowlist validation, protected-identity checks, and candidate-count validation. It reports the exact path, target, SHA-256, and intended action while producing zero mutation.

## Application and verification

Delete only the captured shortcut after confirming that its current path, SHA-256, target, arguments, and metadata still match captured state. Verify immediately that the path is absent. A repeated application returns an idempotent result when the captured shortcut remains absent.

After a full reboot, verify that the shortcut remains absent and record the Windows boot timestamp. A recreated or drifted shortcut is retained as adverse evidence and causes verification failure rather than deletion of the new object.

## Exact rollback

Rollback is permitted only when the captured Startup folder still resolves to the same path and the destination shortcut path is absent. Refuse overwrite.

Before restoration, decode the captured bytes and verify their SHA-256. Restore the exact bytes, timestamps, and attributes. Resolve the restored shortcut and verify its file hash, target, arguments, working directory, icon location, description, and window style against captured state.

## Structured logging

Write one JSON object per line with:

- UTC timestamp
- experiment identifier
- requested action
- event name
- result
- machine and user-state identity where relevant
- candidate path and SHA-256 where relevant
- support and enterprise-management signals
- failure exception type and message

Logs must exclude shortcut bytes, credentials, document paths, profile content, tenant identifiers, tokens, and other sensitive user data.

## Pester contract

Tests must cover PowerShell syntax and static mutation scope plus mocked behavior for:

- unsupported operating system or manufacturer
- missing Microsoft 365 Click-to-Run state
- enterprise-management refusal
- zero, one, and multiple candidate handling
- target allowlist and argument refusal
- protected-identity and updater refusal
- state identity validation
- dry-run zero mutation
- exact single-file deletion
- idempotent repeated application
- immediate and reboot-persistence verification
- drift refusal
- rollback overwrite refusal
- captured-byte hash validation
- exact metadata restoration and verification
- structured failure logging

## Integration check

Run inventory and dry-run paths on an HP Windows 11 machine. Snapshot the Startup folder before and after using file names, lengths, SHA-256 values, timestamps, attributes, and resolved shortcut metadata. The snapshots must be identical.

## Physical measurement protocol

Use five matched baseline sign-ins and five treatment sign-ins under controlled AC power and comparable thermal conditions. Alternate baseline and treatment order when practical. Report medians and retain every run.

Measure:

- sign-in to usable desktop
- CPU utilization during the first 120 seconds
- disk activity during the first 120 seconds
- readiness of Omnissa, Windows App, Remote Desktop, and Tailscale
- first manual launch readiness of the affected Microsoft 365 application

Record instrumentation overhead and preserve favorable, adverse, failed, and inconclusive evidence. Missing physical measurements remain needs-evidence. The release state remains Experimental. Stable assignment requires explicit human approval.

# EXP-047 changelog

## 2026-07-30 — compact gray and red startup mark

### Changed

- Restored the compact outlined Lacksan mark with the smaller UX-ROM signature.
- Changed the primary mark to gray and reserved red for UX-ROM and the version.

## 2026-07-30 — one-time UX-ROM startup art

### Changed

- Added separate Lacksan and UX-ROM ASCII marks to the startup path.
- Displayed the banner and product version once per loaded script instead of
  redrawing the full mark whenever the interactive menu returns.

## 2026-07-30 — Layer 12 dependency readiness profile

### Added

- Added a redacted storage-locality inventory for declared workload paths.
- Added repeated, timeout-bounded TCP readiness probes for explicitly declared
  `host:port` dependencies without sending application payloads.
- Added observer calibration, a condition signature, structured JSON evidence,
  Layer 12 catalog integration, full-diagnostic coverage, and focused tests.
- Preserved the completed primary evidence file when an optional JSONL event
  journal is not writable, while reporting the journal failure clearly.

### Evidence state

Observation-only capability validated on the lab ZBook. No file content,
process, service, registry value, policy, driver, firmware, or Windows setting
was changed. The run established a dependency baseline and makes no
performance-improvement claim.

## 2026-07-29 — Windows PowerShell launcher correction

### Fixed

- Prevented native diagnostic tools such as WPR from aborting an analysis only
  because they wrote informational text to the stderr stream. ZBookPerf now
  captures that stream and decides success from the native exit code.
- Removed a Windows PowerShell 5.1 `Invoke-Expression` scope collision while
  preserving the public `-Candidate` parameter name.
- Replaced the interactive menu's command-line-only Tier 2 rejection with one
  clear recovery confirmation. Automated runs retain the explicit
  `-LabTier2Confirmed` contract.
- Clarified that opening the downloaded script in Notepad is optional source
  inspection and not part of execution.
- Stopped the `Invoke-Expression` error path from replacing the real failure
  with an undefined script-level `$PSCmdlet` error.
- Made the explicitly labeled interactive Fast Startup diagnostic selection
  carry diagnostic intent, while preserving `-Diagnostic` for automated runs.
- Added regression coverage for native stderr capture and both the saved-file
  and trusted one-line launch paths, including an error after menu entry.

### Evidence state

Launcher fix validated with observation-only runs. No Windows setting was
changed and no performance improvement is claimed.

## 2026-07-29 — Initial experimental implementation

### Added

- Root `ZBookPerf.ps1` Windows PowerShell 5.1 console application.
- WPR `GeneralProfile` + `CPU` + `DiskIO` capture with explicit counter-only fallback.
- Continuous CPU/core, process CPU/I/O, disk latency/queue, memory, DPC/ISR, and ACPI thermal-zone sampling.
- Console bars, sparklines, top-process tables, conservative findings, and baseline/after comparison.
- Baseline-evidence gate plus an atomic `changes.json` journal, structured JSONL event log, original-state capture, `-WhatIf`, apply verification, idempotence, explicit reboot-persistence handling, automatic rollback attempt, explicit revert, and rollback verification.
- Five individually selected candidates: AC processor policy, MMCSS responsiveness, NTFS last-access policy, documented visual-effect APIs, and Fast Startup diagnostic isolation.
- Pester coverage for parser validity, chart helpers, JSON round-trip, and dry-run safety.

### Corrected or rejected from the source tuning list

- Corrected Fast Startup to `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled`.
- Rejected `SystemResponsiveness = 0`; Microsoft documents that values below 10 are clamped to 20.
- Rejected blanket SSD-based disabling of Windows Search and SysMain.
- Rejected automatic HP Touchpoint Analytics disable because HP documents Windows Update and subscribed Workforce Experience Platform deployment paths that EXP-047 cannot safely distinguish.
- Rejected a magic `Win32PrioritySeparation` value without a current supported contract.
- Rejected an unused custom MMCSS profile; applications must register work with MMCSS for a task profile to matter.
- Rejected global USB selective-suspend disable because Microsoft strongly recommends it remain enabled.
- Excluded changes to Memory Integrity, Defender, Windows Update, BitLocker, Secure Boot, recovery, HP security/update functions, drivers, firmware, minifilters, WFP callouts, component-store contents, and the Windows shell.

### Sources

All sources were retrieved 2026-07-29. See [engineering-report.md](engineering-report.md#primary-sources) for the linked Microsoft and Intel primary-source list.

### Evidence state

Implemented, not applied on the lab machine. No performance improvement is claimed.

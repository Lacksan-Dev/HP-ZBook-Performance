# EXP-047 changelog

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

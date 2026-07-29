# EXP-047 — ZBookPerf trace-first console

Status: Experimental
Issue: [#109](https://github.com/Lacksan-Dev/HP-ZBook-Performance/issues/109)

## Customer problem

A slow workstation invites a long list of registry edits and disabled services. That approach mixes unrelated variables, hides the real bottleneck, and often removes a Windows or HP feature that another workflow needs. EXP-047 makes the measurement the first step and allows only one reversible candidate per enhancement run.

## What the tool does

The root `ZBookPerf.ps1` script provides:

1. A baseline capture using WPR `GeneralProfile`, `CPU`, and `DiskIO` profiles when the Windows Performance Toolkit is installed and the console is elevated.
2. A counter/CIM fallback when WPR is missing, not elevated, or fails to start.
3. Console CPU, memory, disk, DPC/ISR, thermal-zone, and per-process views with ASCII bars and Unicode sparklines.
4. One named enhancement candidate per invocation.
5. A required baseline-evidence gate before application.
6. Exact state capture in `C:\ProgramData\ZBookPerf\changes.json`, structured JSONL events, post-change verification, idempotence, reboot-persistence handling, and rollback verification.
7. A repeated measurement and side-by-side comparison. A single before/after pair is never labeled a proven improvement.

The WPR ETL contains system activity and can be large. Review it before sharing. The JSON environment record deliberately avoids serial numbers, usernames, network addresses, command lines, and customer content.

## Supported candidates

| Candidate | Tier | Exact action | Important boundary | Rollback |
|---|---:|---|---|---|
| `PowerAc` | 2 | If the built-in High performance scheme exists, select it on AC and set minimum/maximum processor state to 100%, boost mode to Aggressive (`2`), and minimum unparked cores to 100%. Expose those four documented attributes. | AC only. Hardware-controlled P-states can ignore or reinterpret legacy policy indices. Heat, fan noise, and energy use can rise. No performance claim is made. | Restore the previous active scheme, every captured AC index, and each registry `Attributes` value. |
| `MmcssResponsiveness` | 2 | Set `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\SystemResponsiveness` to DWORD `10`. | This reserves 10% CPU for low-priority work while MMCSS activity is present. It is not a general scheduler replacement. | Restore exact existence, type, and value. |
| `NtfsLastAccess` | 2 | Run `fsutil behavior set disablelastaccess 1`. | This is a file-system metadata policy experiment; it is not an NTFS rewrite. Reboot persistence and application compatibility are unverified. | Restore the captured numeric state (`0`–`3`). |
| `VisualEffects` | 1 | Use documented `SystemParametersInfo` calls to turn off UI, client-area, menu, tooltip, selection-fade, combo-box, and list smooth-scroll animation. | Per-user. Font smoothing is deliberately untouched. | Restore each captured Boolean through the same API. |
| `FastStartupDiagnostic` | 2 | Select the explicitly labeled diagnostic option in the interactive menu, or pass both `-Diagnostic` and `-LabTier2Confirmed` in a non-interactive run, to set `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled` to DWORD `0`. | Diagnostic isolation for suspected hybrid-shutdown driver/state problems, not a universal speed setting. Reboot required. Hibernation itself is not disabled. | Restore exact existence, type, and value. |

Tier 2 means a disposable Windows image or dedicated test machine with a tested external recovery path. Passing `-LabTier2Confirmed` is a deliberate operator assertion, not a safety guarantee.

## Rejected automatic tweaks

These proposals are preserved instead of silently becoming code:

- **Disable Windows Search or SysMain because storage is an SSD:** rejected. Media type alone does not prove either component is the cause. Microsoft’s current Search troubleshooting guidance expects `WSearch` to be running and Automatic (Delayed Start) on a healthy supported configuration.
- **Disable HP Touchpoint Analytics automatically:** rejected. HP documents that the service is deployed through Windows Update on some commercial PCs and through HP’s cloud distribution for subscribed Workforce Experience Platform devices. EXP-047 cannot reliably prove that a machine is unsubscribed and unmanaged, so it audits process/service activity but does not stop or disable the service.
- **Set `SystemResponsiveness` to `0`:** rejected. Microsoft documents that values below 10 are clamped to 20, so `0` does not mean “reserve nothing.”
- **Set `Win32PrioritySeparation` to a magic hexadecimal value:** rejected. EXP-047 found no current Microsoft contract supporting the proposed value as a universal responsiveness improvement.
- **Create an MMCSS task profile without changing an application:** rejected. A profile has no effect until a program explicitly registers threads with MMCSS.
- **Disable USB selective suspend:** rejected. Microsoft strongly recommends leaving selective suspend enabled.
- **Disable Memory Integrity, Defender, firewall, Windows Update, BitLocker, Secure Boot, recovery, or HP Wolf/Sure security:** excluded. The experiment does not trade away protection or management.
- **Install generic Intel/NVIDIA drivers over HP packages:** excluded. Driver compatibility, signing, hardware IDs, export/recovery, and post-reboot verification need a separate model-specific experiment.
- **Remove minifilters, WFP callouts, Windows components, or shell extensions:** observation-only in EXP-047. Removing a component requires its own dependency evidence and rollback protocol.

## Evidence and acceptance

The tool records raw samples, environment metadata, optional ETL/CSV data, and a summary. Its findings are conservative screening labels, not diagnoses. ACPI thermal-zone data may not equal CPU package temperature. Counter collection and per-process CIM enumeration add overhead.

An enhancement is accepted only after:

- the same customer-visible workflow is defined;
- several baseline and candidate runs use comparable power, temperature, network, and workload conditions;
- raw runs, medians, variability, errors, and side effects are retained;
- reboot persistence is verified when required;
- rollback is tested; and
- the EXP-001 decision rule or an experiment-specific rule supports retention.

No live enhancement was applied while developing EXP-047.

# EXP-023: Windows latency-surface profiler

This is the first engineering step based on the replaceable Windows surfaces
roadmap. It does not turn community tuning claims into automatic changes. It
shows which components are present and gives us a bounded Microsoft WPR trace
to test which component is actually on a slow path.

## Run it

Open Windows PowerShell 5.1 in the repository.

```powershell
# Read-only inventory; administrator rights are not required
.\experiments\EXP-023\Invoke-LatencySurfaceAudit.ps1

# Preview a 30-second trace without starting it
.\experiments\EXP-023\Invoke-LatencySurfaceAudit.ps1 Trace -WhatIf

# Capture a 30-second general responsiveness trace as administrator
.\experiments\EXP-023\Invoke-LatencySurfaceAudit.ps1 Trace

# Capture one focused file-I/O or minifilter trace
.\experiments\EXP-023\Invoke-LatencySurfaceAudit.ps1 Trace -Profile FileIO
.\experiments\EXP-023\Invoke-LatencySurfaceAudit.ps1 Trace -Profile Minifilter
```

While a trace is recording, reproduce one slow action, such as opening a File
Explorer context menu. The script stops automatically and saves an ETL file for
Windows Performance Analyzer.

Evidence is written under:

```text
%LOCALAPPDATA%\Lacksan\EXP-023
```

## What the audit records

- The configured Windows shell and whether the installed edition supports
  Microsoft's Shell Launcher feature.
- Common machine-wide and per-user File Explorer context-menu handlers,
  including the registered COM DLL, publisher metadata, file version, and
  signature status when available.
- Loaded file-system minifilters reported by `fltmc filters`, plus matching
  service and driver-file metadata when the service registration can be
  resolved.
- Available built-in WPR profiles.

The audit intentionally does not call a third-party handler or filter
"unneeded." A registration is only a candidate. The ETW trace, dependency
review, vendor support boundary, and a one-component comparison decide whether
it deserves a separate disable, demand-start, or replacement experiment.

## Important support limits

- Microsoft documents Shell Launcher for Enterprise, Education, and IoT
  Enterprise editions. Editing `Winlogon\Shell` on Windows 11 Pro is not being
  treated as a supported performance tweak.
- The context-menu inventory covers common Explorer registration roots. It is
  not a complete inventory of every packaged or file-type-specific extension.
- Registry results reflect the bitness of the PowerShell process. Use the
  normal 64-bit Windows PowerShell host when auditing 64-bit Explorer.
- A minifilter may implement antivirus, encryption, backup, recovery, or
  storage functionality. EXP-023 never unloads or removes one.
- WPR changes measurement overhead while it records. That overhead remains
  unqualified and trace results are not yet eligible for a performance claim.
- No Windows settings, services, drivers, handlers, filters, tasks, policies,
  or registry values are changed.

## Primary sources

Retrieved 2026-07-28:

- [Microsoft: Creating Shell Extension Handlers](https://learn.microsoft.com/en-us/windows/win32/shell/handlers)
- [Microsoft: Shell Launcher overview and edition requirements](https://learn.microsoft.com/en-us/windows/configuration/shell-launcher/)
- [Microsoft: About file system filter drivers](https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/about-file-system-filter-drivers)
- [Microsoft: Minifilter development and testing tools](https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/development-and-testing-tools)
- [Microsoft: WPR command-line options](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/wpr-command-line-options)
- [Microsoft: Built-in WPR recording profiles](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/built-in-recording-profiles)

## Status

Implemented but not used to change the lab machine. No performance gain is
claimed.

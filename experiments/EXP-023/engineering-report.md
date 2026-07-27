# EXP-023 engineering report

## Customer problem

File Explorer menus and other visible shell actions can feel slow, but a list
of installed software does not show which component caused the delay. Removing
every shell extension or file-system filter can break useful or security-critical
features while hiding the real cause.

## What we built

`Invoke-LatencySurfaceAudit.ps1` is a read-only profiler with two practical
jobs:

1. Save a structured inventory of common Explorer context-menu handlers,
   loaded minifilters, the active shell, and WPR support.
2. Capture one automatically bounded WPR trace using Microsoft's
   `GeneralProfile`, `FileIO`, or `Minifilter` profile.

The default user command is `Audit`. `Trace` requires an administrator
PowerShell window, supports `-WhatIf`, runs for 30 seconds by default, cancels
the WPR session after a failed capture, and verifies that both the ETL and its
metadata exist.

## Documented facts

- Explorer queries registered shell extension handlers when it performs the
  associated shell operation. Many classic handlers are in-process COM DLLs.
- File-system minifilters can observe, change, or prevent file I/O. Antivirus,
  encryption, and backup are common uses.
- Microsoft supplies `fltmc.exe` to enumerate minifilters.
- WPR ships with supported Windows versions and provides built-in general,
  file-I/O, and minifilter profiles.
- Microsoft's supported Shell Launcher feature is limited to Enterprise,
  Education, and IoT Enterprise editions.

## Lab measurements

No latency measurement is claimed by this source change. The runtime audit is
an inventory, and WPR instrumentation overhead has not been qualified.

## Hypothesis

If a shell handler or minifilter contributes measurable time in a repeated slow
workflow trace, one isolated experiment can compare its original state with a
vendor-supported disabled, demand-start, or replacement state.

## Unresolved questions

- Which handler, filter, driver, or shell process appears in the slowest
  customer-visible workflow?
- How much overhead does each WPR profile add on this ZBook?
- Which candidate has a documented support boundary and exact rollback path?
- Does the result reproduce across repeated runs with controlled power and
  thermal state?

## Safety and rollback

The experiment has no apply function because it makes no configuration change.
It never replaces Explorer, disables Search, unloads a minifilter, stops a
service, changes interrupt routing, or exposes hidden power settings. Trace
sessions are bounded and are canceled on failure. There is no persistent
configuration state to roll back.

## Next experiment gate

Select one workflow and capture repeated control traces. Only after one
component is attributed to the delay should the lab create a separate,
reversible modification experiment for that exact component.

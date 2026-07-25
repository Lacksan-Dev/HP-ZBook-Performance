# Lacksan ZBook Performance

Experimental standalone Windows PowerShell 5.1 utility for the validated HP
ZBook Firefly 14 G8 lab computer. The normal actions are Check, Benchmark,
Tune, FullTest, Compare, Undo, and RestartTest.

## Current support lock

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Intel Core i5-1145G7
- Windows 11 Pro build 26200
- BIOS T76 01.24.02

Check and Benchmark are read-only. Check also reports whether the one-time
restart/auto-login workflow is inactive, has only a preserved record, or needs
cleanup with `StopAutoLogin`. It only recommends automatic cleanup when the
resume task's exact state ID has a matching recovery record; externally
configured auto-login is reported but never claimed or changed. Tune refuses
other hardware/build/BIOS
combinations and genuinely managed devices by default. A generic Microsoft
`MDMMaintenenceTask` without domain/Entra join, MDM URL, or enrollment-specific
tasks is not treated as active management.

## Local use

Open Windows PowerShell 5.1 in the repository:

```powershell
# Simple status
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 Check

# Quick benchmark with seven preserved raw runs per metric
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 Benchmark

# Tune; automatically opens an administrator run when needed
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 Tune

# One-command counterbalanced before/after test; leaves Tune active
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 FullTest

# Undo the latest Tune
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 Undo

# Tune, restart, sign in automatically once, verify, benchmark, and remove
# auto-login. The account password is requested once in a masked prompt.
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 RestartTest
```

Run without parameters for a menu. Selecting Tune, Undo, FullTest, or
RestartTest performs the selected action without an extra tool confirmation.
Windows elevation still follows the PC's UAC policy. Legacy `-Mode Audit`,
`-Mode Apply`, and similar version 0.1 commands remain mapped to the new names.
`-WhatIf` on a changing action is redirected to the read-only details view.

The current lab computer has a workplace registration and an elevated-only
generic Microsoft maintenance task, but it is not domain/Entra joined, publishes
no MDM URL, and has no enrollment-specific task. No override flag is required
on this PC. The tool never changes management state.

Backups are stored in:

```text
%ProgramData%\Lacksan\ZBookPerformance\Backups
```

Each contains a typed state manifest, SHA-256 integrity value, registry exports,
active power-plan export, and restore-point result. Logs are JSON Lines under
the corresponding `Logs` folder (or the user's LocalAppData when the
ProgramData log folder cannot be written).

Quick benchmark JSON and comparison files are stored under the adjacent
`Benchmarks` folder. `FullTest` uses both A-B-B-A and B-A-A-B orderings, waits
for low background CPU/disk activity, retains all successful and failed raw
runs, reports medians, and leaves the selected Tune state active. The current
screening metrics are process startup and a fixed CPU burst; they are useful for
iteration but do not replace the nine customer-workflow protocol.

## One-time automatic sign-in

`RestartTest` is explicitly authorized for the personal lab PC. It:

1. captures the original Winlogon values;
2. validates the supplied account password without logging it;
3. stores the password as a Windows LSA secret, never as a plaintext
   `DefaultPassword` value;
4. registers one resume task for the current user;
5. restarts after a 30-second cancel window;
6. verifies tuning and benchmarks after automatic sign-in; and
7. clears the LSA secret, restores the captured Winlogon values, and removes its
   task.

Use `StopAutoLogin` if a prepared restart is canceled. Auto-login means anyone
with physical access can enter the account, and Microsoft notes that a local
administrator can retrieve an LSA secret. Do not use it on shared, stolen-risk,
or organization-managed systems.

## One-line launch

After the repository version is published and reviewed, the interactive
utility can be launched in the WinUtil-style form:

```powershell
irm https://raw.githubusercontent.com/Lacksan-Dev/HP-ZBook-Performance/main/experiments/EXP-001/tool/Lacksan-ZBook-Performance.ps1 | iex
```

The current local file should be used until publishing is confirmed. Remote
execution should be pinned to a reviewed commit for managed/customer use; do
not assume a moving branch is unchanged.

## Important limits

- This is experimental and has no measured performance claim.
- Crossover screening found no consistent general-responsiveness benefit from
  forcing the aggressive AC energy preference, so Tune retains the measured
  balanced value 33.
- Battery/DC settings are not changed.
- System Restore is not a full disk or personal-file backup, can be disabled,
  and Windows rate-limits restore-point creation.
- The script's rollback covers every allow-listed setting and verifies the
  restored values, but no script can promise literal 100% recovery from disk
  failure, firmware failure, or unrelated later changes.
- Stable release requires explicit human approval.

See [the implementation design](../experiment-design.md) and
[validation protocol](../validation-protocol.md).

# Lacksan ZBook Performance

Experimental standalone Windows PowerShell 5.1 utility for the validated HP
ZBook Firefly 14 G8 lab computer. The normal actions are Check, Benchmark,
Tune, FullTest, Compare, Undo, Privacy, UndoPrivacy, and RestartTest.

## Current support lock

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Intel Core i5-1145G7
- Windows 11 Pro build 26200
- BIOS T76 01.24.02

Check and Benchmark are read-only. Check also reports whether the one-time
restart/auto-login workflow is inactive, has only a preserved record, or needs
cleanup with `StopAutoLogin`. It only recommends automatic cleanup when the
resume task's exact state ID has an integrity-valid, identity-matched recovery
record; externally configured auto-login and damaged recovery records are
reported but never claimed or changed. `StopAutoLogin` enforces the same
ownership check even when it is run directly, so an old record cannot be used
to overwrite unrelated Windows auto-login configuration. Cleanup is only
reported as successful after the LSA secret is absent, every captured Winlogon
value matches its original state, and the resume task is gone. Tune refuses
other hardware/build/BIOS
combinations and genuinely managed devices by default. A generic Microsoft
`MDMMaintenenceTask` without domain/Entra join, MDM URL, or enrollment-specific
tasks is not treated as active management.

The interactive menu never asks the user to type `APPLY`. If active management
is detected, changing actions use one numbered gate:

1. continue the selected action once as administrator;
2. undo the latest exact Lacksan backup; or
3. cancel without changes.

This bypasses only the tool's safety refusal for the current run. It does not
disconnect accounts, remove enrollment, delete EnterpriseMgmt tasks, or change
domain, Entra, MDM, security, update, or recovery policy. Noninteractive use
retains the explicit `-AllowManagedDevice` switch, and that authorization is
forwarded through the UAC relaunch.

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

# Hide email address or user-name details on the sign-in screen
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 Privacy

# Restore the exact pre-Privacy policy state
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 UndoPrivacy

# Tune, restart, sign in automatically once, verify, benchmark, and remove
# auto-login. The account password is requested once in a masked prompt.
.\experiments\EXP-001\tool\Lacksan-ZBook-Performance.ps1 RestartTest
```

Run without parameters for a menu. Selecting Tune, Undo, FullTest, RestartTest,
Privacy, or UndoPrivacy performs the selected action without an extra tool
confirmation. Windows elevation still follows the PC's UAC policy. Legacy
`-Mode Audit`, `-Mode Apply`, and similar version 0.1 commands remain mapped to
the new names.

## Low-friction sign-in privacy

`Privacy` enables Microsoft's documented **Block user from showing account
details on sign-in** computer policy. It prevents the sign-in screen from
showing extra details such as an email address or user name. It intentionally
does not enable **Don't display last signed-in**, so the display name and normal
sign-in tile remain visible and normal Windows Hello/passwordless sign-in is
not deliberately removed.

The action is separate from Tune because it is a privacy choice, not a measured
performance optimization. Before writing, it checks the validated model/build
and management state and saves the exact key/value existence, registry type,
and data to an integrity-protected manifest. It verifies the immediate result,
is idempotent, preserves failed apply evidence, and automatically restores and
verifies the captured state if apply verification fails. `UndoPrivacy` restores
the newest verified privacy backup exactly. Use `Privacy -WhatIf` and
`UndoPrivacy -WhatIf` for non-writing previews.

Privacy backups are stored in:

```text
%ProgramData%\Lacksan\ZBookPerformance\PrivacyBackups
```

Sign out or restart to inspect the sign-in screen. Reboot persistence remains
pending until that manual observation is preserved; the implementation has not
been applied on the lab machine.
`-WhatIf` on a changing action is redirected to the read-only details view.

Show configuration is a live profile dashboard. `[OK]` means the current value
matches the selected profile and `[--]` means Tune would change it. The screen
shows current and selected values, qualitative tradeoffs, and the evidence
boundary that no performance gain has been established. It does not claim
unmeasured gains.

The current lab computer has a workplace registration and an elevated-only
generic Microsoft maintenance task, but it is not domain/Entra joined, publishes
no MDM URL, and has no enrollment-specific task. No override flag is required
on this PC. The tool never changes management state.

If the title reports a version earlier than `0.2.2-experimental`, that is an old
copy with the retired text-confirmation and management false-positive behavior.
Run the reviewed current file and confirm that the title reports
`0.2.2-experimental`.

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
runs, reports medians, and leaves the selected Tune state active. Aggregation
derives its pending-setting count from the raw blocks and stops if block state
or counts disagree. The current screening metrics are process startup and a
fixed CPU burst. New raw, aggregate, and comparison JSON records identify
themselves as `PreProtocolScreening` with `FormalBaselineEligible` set to
`false`. They are useful for iteration, but are excluded from the nine-workflow
formal baseline and its medians by the
[approved experiment protocol](../experiment-protocol.md). Aggregate and
comparison commands reject inputs without both markers, so older unclassified
files must not be relabeled as current screening evidence. Automatic Compare
selection skips those incompatible files and uses the newest eligible
untuned/tuned pair. It also excludes the separate `BeforeRestart` and
`AfterRestart` records so restart validation cannot be mistaken for a tuning
comparison. Run a new Benchmark when no classified input exists.

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

## Validation commands

Run both the non-destructive integration suite and the focused Pester suite:

```powershell
.\experiments\EXP-001\tool\tests\Invoke-Tests.ps1
Invoke-Pester .\experiments\EXP-001\tool\tests\Lacksan-ZBook-Performance.Tests.ps1
```

The Pester tests cover the numbered managed-device decisions, hardware-lock
preservation, generic-maintenance-task false-positive regression, UAC argument
forwarding, parsing, and the live configuration dashboard contract.

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

See [the implementation design](../experiment-design.md),
[validation protocol](../validation-protocol.md), and
[approved experiment protocol](../experiment-protocol.md).

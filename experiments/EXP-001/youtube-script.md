# EXP-001 YouTube Customer Update Script

## Production status

- Experimental lab update; not a stable-release announcement
- No performance-gain claim
- Stable release requires explicit human approval

## Suggested title

**A Safer HP ZBook Performance Baseline: What We Built and What Still Needs Testing**

## Script

**[Opening — presenter on camera]**

We have reached the first working checkpoint for our HP ZBook performance
utility. The goal is simple: create a narrow, model-aware Windows baseline that
can be inspected, previewed, applied, verified, and rolled back without turning
the computer into an unsupported “debloat” experiment.

This is still experimental. We are not claiming that it makes Windows faster
yet. Performance claims will come only after repeated, controlled measurements.

**[On screen: “One PowerShell utility — Audit, Preview, Apply, Verify, Rollback”]**

The utility is a standalone PowerShell tool built for the exact HP ZBook
platform currently in the lab. Before applying anything, it checks the computer
model, processor, Windows build, firmware version, and management state. If the
machine falls outside the tested support boundary, the apply operation stops.
Audit and preview remain read-only.

The configuration is intentionally small: 17 allow-listed settings made up of
12 Windows user-experience preferences and five plugged-in power-policy
controls. It does not install or remove applications. It does not disable
services or scheduled tasks, alter Windows Update, weaken security or management
features, create Windows installation media, or apply broad debloat presets.
Battery settings are preserved.

**[On screen: “Backup first”]**

Before the first change, the lab run captured the original state of all 17
settings. It also created registry and power-policy exports, protected the state
manifest with a SHA-256 integrity check, and successfully created a Windows
System Restore point.

That is a strong rollback design for the settings this utility owns, but it is
not a promise of total recovery from every possible failure. System Restore is
not a disk image, and no script can recover unrelated changes, damaged storage,
or firmware failure.

**[On screen: “What happened in the first apply?”]**

On this ZBook, 16 settings already matched the proposed baseline. The utility
changed only one plugged-in processor responsiveness preference. The
corresponding battery preference was left unchanged. Immediate verification
then reported all 17 allow-listed settings compliant.

That result demonstrates correct state detection and an idempotent, narrow
apply path. It does not demonstrate a performance improvement.

**[On screen: “Transactional rollback verified”]**

The elevated rollback test has now completed successfully. The utility verified
the restored state against its protected backup, and a follow-up preview showed
exactly one setting pending—the same plugged-in preference that differed before
the first apply. That confirms exact transactional rollback for this lab run.

The controlled reapply has also completed successfully. It captured a fresh
exact-state backup, created new registry and power-policy exports, passed its
integrity check, and successfully created a restore point. A separate
verification again reported all 17 settings compliant, and the full static and
read-only test suite passed. Verification after a reboot is still required
before this can move toward release.

**[Presenter on camera]**

Since that first engineering checkpoint, we simplified the customer experience.
Instead of technical modes and override flags, the normal commands are now
Check, Benchmark, Tune, FullTest, Compare, Undo, and RestartTest. The personal
lab PC is recognized correctly even though a work account and a generic
Microsoft maintenance task are present.

The new FullTest preserves raw runs and uses both A-B-B-A and B-A-A-B ordering
to reduce position bias. The first crossover screening did not find a
consistent general responsiveness win from forcing the most aggressive
plugged-in processor preference. Process-start results were essentially tied,
while the synthetic CPU burst favored the aggressive value. Because the more
aggressive value also carries heat and energy tradeoffs, the general baseline
now retains the measured balanced value. This is exactly why we benchmark before
turning a popular tweak into a recommendation.

The restart workflow can prepare a one-time automatic sign-in on this personal
lab PC, verify the settings after Windows starts, run another quick benchmark,
and then remove its credential and scheduled resume task. That state-changing
restart test is still pending, and automatic sign-in is not intended for shared
or managed customer computers.

The configuration-focused experience was inspired by the tweaks and
configuration sections of Chris Titus Tech’s WinUtil. We reviewed and credited
that open-source project, while building separate support checks, backup,
verification, logging, and rollback behavior for this specific experiment.

Next, we will execute and verify the persistence workflow after reboot. The lab
still needs the full customer-workflow runs and instrumentation overhead
measurements. All quick benchmark blocks, including misleading ordered results
and mixed crossover results, are preserved rather than presented as a gain.

Until those gates are complete, this remains an experimental engineering build,
not a customer-ready performance release. A stable release will require an
explicit human approval decision.

**[Closing card]**

**EXP-001 status: simplified utility, controlled apply/rollback, quick crossover
screening, and immediate verification are complete; reboot persistence and
customer-workflow performance validation remain pending.**

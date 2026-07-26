# EXP-001 YouTube Customer Update Script

## Production status

- Experimental lab update; not a stable-release announcement
- No performance-gain claim
- Stable release requires explicit human approval

## Suggested title

**A Safer HP ZBook Performance Baseline: What We Built and What Still Needs Testing**

## 2026-07-27 layer 1 update: thermal telemetry is not ready

**[On screen: "Layer 1 - Physical and thermal health"]**

The first hourly performance-layer investigation asked a basic question: can
the ZBook's existing Windows and HP interfaces give us a trustworthy CPU
temperature, fan state, and ambient condition before every startup test?

The answer is not yet. Windows detected seven ACPI thermal-zone devices and the
installed Intel Dynamic Tuning components, but the non-elevated inbox
interfaces did not return an identified CPU-package temperature or fan state.
Microsoft describes an ACPI thermal zone as a firmware-defined abstraction, so
we will not rename an unknown zone as a CPU sensor or invent a temperature
threshold.

**[On screen: "Inconclusive is a result"]**

The standard temperature-probe, fan, and battery-temperature queries returned
no readings. The ACPI temperature query returned access denied without
elevation. PwrTest and HP's Windows diagnostics were not detected. Battery
full-charge capacity and 101 cycles were readable, but design capacity was not,
so we did not calculate a health percentage.

HP documents manual fan diagnostics, including a Fan Thermal Test. That is a
hardware diagnostic, not a low-overhead unattended benchmark sensor. Intel also
warns against disabling Dynamic Tuning Technology, so no DTT component, fan
control, driver, firmware option, service, policy, or power setting was changed.

This layer is preserved as inconclusive. A later instrumentation experiment
must identify the sensor, units, elevation, overhead, fan and ambient evidence,
and a repeatable pre-run band. No performance gain is claimed.

The hourly cursor now moves to layer 2: hardware resources and bottlenecks.

## 2026-07-27 low-friction sign-in privacy update

**[On screen: "Hide account details, keep normal sign-in"]**

The owner selected the low-friction sign-in privacy option for the public-use
ZBook. The experimental PowerShell utility now has a separate `Privacy` command
that enables Microsoft's documented **Block user from showing account details
on sign-in** policy.

The exact policy value is
`HKLM\SOFTWARE\Policies\Microsoft\Windows\System\BlockUserFromShowingAccountDetailsOnSignin`.
When enabled, Windows prevents extra account details such as an email address or
user name from being shown at sign-in.

This is deliberately not the stronger **Don't display last signed-in** policy.
The display name and normal sign-in tile remain visible, preserving the
low-typing Windows Hello or passwordless experience. Customers who need the
name itself hidden require a separate higher-friction security decision.

**[On screen: "Reversible by design"]**

`Privacy -WhatIf` previews the action without writing. A live apply first checks
the exact ZBook model, Windows build, BIOS, and management state. It then saves
the original registry key and value existence, type, and data in an
integrity-protected backup, applies one policy value, verifies it, and records
structured logs. Repeating the command is idempotent. `UndoPrivacy` restores
and verifies the exact captured state.

The implementation passed non-destructive tests but has not been applied on the
lab machine. Sign-out or reboot persistence and a visual sign-in-screen check
remain pending. This is a privacy improvement, not a startup or responsiveness
gain, and the hourly performance-layer cursor was not advanced by this direct
owner choice.

## 2026-07-26 merged-development update

Use this segment after the existing engineering checkpoint when briefing the
merged pull request.

**[On screen: "Screening evidence stays screening"]**

The latest development merge makes the benchmark boundary explicit. Every new
quick benchmark, aggregate, and comparison record says
`PreProtocolScreening` and sets formal-baseline eligibility to false. The tool
will not combine or compare files that lack those markers.

Automatic Compare now skips older unclassified files and the separate
before-restart and after-restart records. That prevents a restart-validation
measurement from being presented as a tuning comparison. These are evidence
handling improvements, not performance gains.

**[On screen: "Cleanup must prove ownership"]**

The one-time sign-in cleanup is stricter too. The active Lacksan resume task,
its embedded state ID, and an integrity-checked recovery record must agree
before cleanup can proceed. Success is reported only after the password secret
is absent, every captured Winlogon value matches its original state, and the
resume task is gone.

No services, security controls, Windows Update components, drivers, firmware,
or HP management features were disabled in this update. The full static and
non-destructive test suite passed after merge. Physical reboot validation,
formal customer-workflow runs, instrumentation overhead, thermal behavior, and
reproducible performance evidence remain open.

The corresponding development report lists the exact 12 registry preferences
and five AC-only power settings, along with their support limits, sources, and
rollback status. It also makes an important distinction: most settings were
already compliant on the lab ZBook, and no service-stop candidate has passed
the support and measurement gates yet.

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

---

## Hourly performance-layer cycle announcement

**[Presenter on camera]**

We are expanding the Lacksan ZBook performance project from a small collection
of Windows settings into a complete, repeatable performance-engineering cycle.

Every hour, the engineering automation will advance by one layer. The twelve
layers cover physical and thermal health, hardware bottlenecks, firmware,
drivers and HP components, the Windows kernel, power management, security
overhead, boot services and startup applications, Group Policy and registry
configuration, the Windows interface, application runtimes, and finally the
workload and its data.

The cycle position is stored in the repository, so an hourly run cannot quietly
skip an inconvenient layer or spend every hour collecting popular registry
tweaks.

**[On screen: "Priority: off to usable"]**

Startup work will not be judged only by a single boot duration. We will
separate firmware time, Windows kernel and session initialization, sign-in,
shell readiness, delayed background work, and the point where the target
application is actually responsive.

Services, scheduled tasks, background permissions, and startup applications
will be treated as required until documentation, dependency analysis, and
preserved boot-trace evidence show that a different startup mode is supported.
This is targeted engineering, not a generic debloat list.

**[On screen: "Drivers: supported paths only"]**

Driver investigations will focus on vendor-supported packages, configuration,
device power behavior, DPC and interrupt latency, and interactions among
Windows, HP, Intel, and other hardware vendors. We will not claim that a
proprietary driver can simply be rebuilt. Source availability, redistribution,
signing, hardware compatibility, and safe recovery would all have to be proven
first.

Group Policy and background-permission research will also preserve
organization management and Windows security. A documented policy will not be
confused with an unofficial registry shortcut.

**[On screen: "Evidence before claims"]**

Each proposed change still needs support detection, original-state capture, a
dry run, application and verification, structured logs, idempotence, exact
rollback, and reboot verification when applicable.

The unattended hourly runs can research and build those controls, but they
cannot silently change the live laptop, stop services, install drivers, reboot,
or weaken security and updates.

This announcement initializes the cycle at layer one: physical and thermal
health. It contains no new benchmark and makes no performance claim. Each
completed layer will receive a technical progress article and an updated
YouTube briefing, including failed and inconclusive findings—not only wins.

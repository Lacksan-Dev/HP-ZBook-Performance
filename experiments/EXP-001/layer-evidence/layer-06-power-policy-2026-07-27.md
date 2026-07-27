# EXP-001 layer 6 evidence: Best performance is already the AC request

- Layer: 6, power management and performance policy
- Investigation date: 2026-07-27
- Source retrieval date: 2026-07-27
- Target: validated HP ZBook Firefly 14 inch G8 lab computer
- Outcome: **inconclusive**
- Evidence state: read-only configuration inventory; not baseline-eligible
- Live Windows changes: none
- Performance claim: none
- Raw observation:
  [layer-06-power-policy-2026-07-27.json](layer-06-power-policy-2026-07-27.json)

## Evidence question

Does the current Windows scheme, user power mode, processor policy, sleep-state,
and Intel platform-policy inventory identify one supported change that improves
startup or responsiveness on the exact ZBook?

## Decision

No. The active base scheme is Balanced, while the Windows 11 user-configured
mode is already Best performance on AC and Best power efficiency on battery.
The processor policy exposes a 5 percent minimum and 100 percent maximum on both
power sources. Those settings define policy bounds; they do not measure current
frequency, sustained performance, readiness, responsiveness, energy, or
temperature.

Do not force a custom or High performance scheme, set the processor minimum to
100 percent, change an unobserved energy-performance preference, disable Intel
Dynamic Tuning, force S3 with a registry workaround, or enable hibernation/Fast
Startup from this inventory. Preserve the result as inconclusive and advance to
layer 7.

## Documented facts

- Microsoft documents `powercfg /getactivescheme`, `/list`, `/query`,
  `/aliases`, and `/a` as supported inventory surfaces for schemes, settings,
  aliases, and available sleep states.
- Windows 11 supports three user-configured power modes: Best power efficiency,
  Balanced, and Best performance. Microsoft documents separate APIs for the AC
  and DC choices and says the requested mode is a user vote that other system
  signals can override.
- Microsoft Support describes Best performance as maximizing performance and
  warns that it increases power use, battery drain, and heat. A selected mode is
  not proof of a faster customer workflow.
- Microsoft documents the Windows processor power-management algorithms as
  balancing performance and energy efficiency through a performance-state
  engine, core parking, and platform-specific controls. Silicon-vendor guidance
  is required for tuning beyond the documented general settings.
- `PROCTHROTTLEMIN` and `PROCTHROTTLEMAX` are supported Windows processor
  policy settings expressed as percentages. A 100 percent minimum biases the
  CPU toward performance; it is not a universal responsiveness recommendation.
- Microsoft documents S0 Low Power Idle as Modern Standby. A platform that
  supports it does not support S1-S3. Windows uses `powercfg /a` to report the
  platform's supported sleep model.
- Microsoft documents Fast Startup as a hybrid shutdown that logs off users and
  stores the kernel session in a hibernation file. It is not a cold boot or a
  Restart. Hibernation-file type and storage cost are part of the configuration.
- Intel describes Dynamic Tuning Technology as platform software that adapts
  power and performance using system temperature and usage mode. Its presence
  is a compatibility dependency, not evidence that disabling it improves speed.

## Lab measurements

The observation was read-only and non-elevated on Windows 11 Pro build 26200,
BIOS T76 01.24.02. Windows reported AC-connected power with 99 percent charge.
No startup, readiness, responsiveness, energy, SleepStudy, system-power,
thermal, or instrumentation-overhead measurement ran.

### Scheme and supported Windows power modes

| Surface | AC | Battery |
| --- | --- | --- |
| Active base scheme | Balanced | Balanced |
| User-configured Windows 11 mode | Best performance | Best power efficiency |
| Processor minimum | 5% | 5% |
| Processor maximum | 100% | 100% |

The mode APIs returned success. This records the user's configured AC/DC votes,
not the effective runtime mode after thermal, firmware, workload, battery, and
other platform signals.

A second plan named `My Custom Plan 1` exists but is inactive. Microsoft notes
that choosing a custom plan can make the Windows power-mode selector
unavailable. Its mere presence is not a reason to delete or activate it.

The public alias inventory exposed the minimum and maximum processor settings.
A `PERFEPP` query returned no setting record even though `powercfg` exited
successfully. No energy-performance-preference value was inferred.

### Sleep, shutdown, and platform policy

`powercfg /a` reported S0 Low Power Idle with network connectivity as the only
available standby state. S1-S3 are unavailable under the platform's Modern
Standby model.

Hibernation is disabled. Consequently, Hibernate, Hybrid Sleep, and Fast
Startup are unavailable. This does not establish that enabling them would
improve an accepted off-to-usable workflow. Fast Startup uses a different
transition from cold boot and Restart and must be measured as a separate
workflow with its hibernation-file storage, driver, update, recovery, and
rollback effects preserved.

The Intel Dynamic Tuning service was running with automatic start. No Intel DTT
configuration, HP firmware power policy, fan state, CPU temperature, effective
runtime power mode, or platform power limit was read.

## Hypotheses

- Best performance on AC may reduce some foreground latency relative to
  Balanced or Best power efficiency, but repeated equivalent workload runs are
  required and no comparison exists.
- Best power efficiency on battery may increase some readiness times while
  reducing energy and heat, but the tradeoff has not been measured.
- Fast Startup could reduce one hybrid-shutdown-to-ready path, but it cannot
  improve Restart and must not be reported as cold-boot improvement.
- Intel DTT or firmware constraints may override a requested Windows mode under
  thermal or power limits, but the effective state and limits were not measured.

## Compatibility, dependency, and rollback limits

- The inventory applies only to the recorded model, SKU, Windows build, BIOS,
  battery/AC observation, schemes, user-configured modes, and current service
  state.
- The user-configured mode is not a verified effective-mode trace. A future
  collector needs the effective mode at every run boundary.
- Any power-mode comparison must separate AC and battery workflows, record
  charge, adapter, thermal readiness, ambient condition, active scheme,
  effective mode, Intel/HP platform state, workload reset, and raw run order.
- Raising the minimum processor state can increase heat and power use and can
  reduce idle headroom. It requires Intel/HP support evidence and thermal/power
  measurement, not a copied performance-guide recommendation.
- Enabling hibernation creates or resizes `hiberfil.sys`, changes available
  sleep and shutdown transitions, and can affect driver and update behavior. A
  future change must capture the original hibernation state, file type/size,
  Fast Startup state, disk capacity, supported transitions, and exact rollback.
- Forcing S3 with undocumented registry workarounds is outside the reported
  firmware support boundary.
- No configuration changed, so rollback is not applicable. Future modification
  still requires support detection, original-state capture, dry run, apply,
  verification, structured logging, idempotence, exact rollback, rollback
  verification, and reboot-persistence testing.
- Security, update, BitLocker, recovery, management, drivers, services, tasks,
  firmware, registry, Modern Standby, hibernation, and power policy were
  untouched.

## Unresolved questions

1. What effective power mode is active at every AC and battery run boundary?
2. Which customer workflows should compare Best performance, Balanced, and Best
   power efficiency, and what is the accepted latency/energy/thermal decision
   rule?
3. What overhead do power, temperature, frequency, and effective-mode
   instruments add?
4. Does the HP/Intel platform publish model-specific DTT, adapter, thermal, and
   power-limit compatibility guidance for this SKU and BIOS?
5. Is hibernation intentionally disabled, and can a reduced hibernation file be
   supported with enough storage and exact rollback?
6. How do cold boot, Fast Startup, Restart, Modern Standby resume, and
   hibernation resume differ across the nine declared workflows?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: powercfg command-line options](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)
- [Microsoft: change Windows power mode](https://support.microsoft.com/en-us/windows/change-the-power-mode-for-your-windows-pc-c2aff038-22c9-f46d-5ca0-78696fdf2de8)
- [Microsoft: PowerGetUserConfiguredACPowerMode](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfiguredacpowermode)
- [Microsoft: PowerGetUserConfiguredDCPowerMode](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfigureddcpowermode)
- [Microsoft: processor power-management options](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options)
- [Microsoft: maximum processor performance](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/options-for-perf-state-engine-maxperformance)
- [Microsoft: system power states and Fast Startup](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)
- [Microsoft: Modern Standby network connectivity](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-network-connectivity)
- [Microsoft: distinguishing Fast Startup from hibernation](https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/distinguishing-fast-startup-from-wake-from-hibernation)
- [Intel: 11th Gen Core vPro platform features](https://software.intel.com/content/dam/www/public/us/en/documents/product-briefs/a1124383-11th-gen-core-vpro-desktop-processor.pdf)

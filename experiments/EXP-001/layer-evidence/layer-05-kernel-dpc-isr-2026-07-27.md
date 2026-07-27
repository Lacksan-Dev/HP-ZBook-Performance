# EXP-001 layer 5 evidence: system counters are not DPC attribution

- Layer: 5, Windows kernel, scheduler, memory, storage, interrupts, and
  DPC/ISR behavior
- Investigation date: 2026-07-27
- Source retrieval date: 2026-07-27
- Target: validated HP ZBook Firefly 14 inch G8 lab computer
- Outcome: **inconclusive**
- Evidence state: pre-protocol screening; not baseline-eligible
- Live Windows changes: none
- Performance claim: none
- Raw observation:
  [layer-05-kernel-dpc-isr-2026-07-27.json](layer-05-kernel-dpc-isr-2026-07-27.json)

## Evidence question

Can three short blocks of inbox Windows counters identify a supported kernel,
scheduler, memory, storage, interrupt, or DPC/ISR change that improves startup
or responsiveness on the exact ZBook?

## Decision

No. The counters are readable and preserve time-stamped system-wide activity,
but they do not attribute DPC or ISR duration to a module, function, device, or
call stack. They were not captured around a declared customer workflow or
readiness endpoint. They therefore cannot select a driver, timer, scheduler,
memory, storage, interrupt-affinity, page-file, power, service, policy, or
registry change.

Do not apply popular HPET, timer, scheduler, interrupt-affinity, page-file, or
boot-configuration recipes on this evidence. Preserve the result as
inconclusive and advance to layer 6.

## Documented facts

- Microsoft documents `Get-Counter` as reading Windows performance-counter
  instrumentation and supporting a selected sample interval and maximum sample
  count. Counter names are localized, so a future reusable collector must
  discover supported paths rather than assume English names.
- Microsoft's Windows Performance Recorder General profile records kernel
  context switches, disk I/O, DPC, hard faults, interrupts, kernel queues,
  memory information, process/thread activity, ready threads, sampled CPU
  profiles, and related events.
- Microsoft documents Windows Performance Analyzer DPC/ISR views by CPU and by
  module and function. Those trace views, with symbols and stacks when
  available, are the supported attribution surface missing from simple
  aggregate counters.
- Microsoft's CPU Analysis guide says to relate DPC/ISR activity to the
  interval of interest, identify high-duration module/function entries, and
  review stacks. The guide also illustrates that DPC/ISR activity can be
  unrelated to a performance problem.
- Microsoft's driver tracing example measures driver DPC/ISR time with kernel
  event tracing, checks lost events, exercises the test driver, and analyzes a
  trace report. A short system-wide percentage is not an equivalent driver
  measurement.

## Lab measurements

The non-elevated, read-only observation ran on Windows 11 Pro build 26200, BIOS
T76 01.24.02, while Windows reported AC-connected power and the Balanced power
scheme. It collected three consecutive blocks of five one-second samples for
eight system-wide counters. No test workload or startup benchmark ran.

Median values for each five-sample block:

| Counter | Block 1 | Block 2 | Block 3 | Median of block medians |
| --- | ---: | ---: | ---: | ---: |
| Processor time (%) | 12.9596 | 7.0698 | 1.9478 | 7.0698 |
| DPC time (%) | 0 | 0 | 0.1926 | 0 |
| Interrupt time (%) | 0 | 0 | 0 | 0 |
| Interrupts/sec | 4135.1839 | 427.9419 | 418.2872 | 427.9419 |
| Processor queue length | 0 | 0 | 0 | 0 |
| Context switches/sec | 7336.9694 | 486.9684 | 468.7190 | 486.9684 |
| Page reads/sec | 0 | 0 | 0 | 0 |
| Current disk queue length | 0 | 0 | 0 | 0 |

These medians describe only the preserved 15-second screening interval. The
raw sample ranges include 0 to 0.1953 percent DPC time, 0 to 0.3883 percent
interrupt time, 311.6000 to 4527.3966 interrupts/sec, and 332.3045 to
8454.5740 context switches/sec. The observed variation is one reason not to
interpret a single block as a normal state.

`wpr.exe` was present in the Windows system directory. `wpa.exe` and
`xperf.exe` were not detected. No ETW recording was started, no toolkit was
installed, and no elevation was attempted.

This is **not** an EXP-001 baseline:

- engineering automation was active;
- no formal idle-settling or workflow reset occurred;
- no customer workflow or readiness endpoint was run;
- layer 1 did not establish a thermal-readiness gate;
- counter overhead was not qualified;
- no ETW module/function or stack attribution exists; and
- no startup, sign-in, shell, network, device, or workload readiness time was
  measured.

## Hypotheses

- A platform driver may produce DPC/ISR work that overlaps a customer-visible
  readiness delay, but only a workflow-scoped trace can test that relationship.
- The early high counter block may reflect active automation or transient
  background work, but the collection contains no process/module attribution
  and cannot identify a cause.
- Storage, memory, or scheduler delay may exist in another workflow even though
  queue and page-read medians were zero in this short interval.

## Compatibility, measurement, and rollback limits

- The observation applies only to the recorded model, SKU, Windows build, BIOS,
  power observation, power scheme, and short collection interval.
- English counter paths happened to be available on this installation.
  Reusable support detection must discover localized counter paths.
- A future ETW protocol must use a Windows-build-compatible Windows Performance
  Toolkit, record collector/tool versions and configuration, check lost events,
  qualify instrumentation overhead, protect sensitive trace data, and preserve
  raw traces and analysis exports.
- DPC/ISR attribution must be scoped to a declared workflow and readiness
  interval. Aggregate percentages alone do not prove a driver problem or a
  customer-visible effect.
- No configuration was changed, so rollback is not applicable. A future
  modification still requires original-state capture, dry run, apply,
  verification, idempotence, exact rollback, rollback verification, and reboot
  persistence testing.
- Defender, firewall, Windows Update, BitLocker, Secure Boot, recovery,
  management, HP support/update functions, drivers, services, tasks, registry,
  page file, power, firmware, and boot configuration were untouched.

## Unresolved questions

1. Which repeatable workflow and readiness interval should bound each DPC/ISR,
   scheduler, memory, and storage trace?
2. Which Windows ADK/WPT build supports Windows build 26200, and what
   collection overhead does its selected profile add?
3. Which modules, functions, and stacks account for DPC/ISR duration inside
   that interval, and are any durations repeatable across raw runs?
4. Are lost ETW events zero in every accepted trace?
5. Does any attributed activity overlap a customer-visible delay, and does a
   documented reversible change improve the accepted median without side
   effects?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Get-Counter](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-counter)
- [Microsoft: recording for basic system diagnosis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-for-basic-system-diagnosis)
- [Microsoft: CPU Analysis](https://learn.microsoft.com/en-au/windows-hardware/test/wpt/cpu-analysis)
- [Microsoft: list of WPA graphs](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/list-of-wpa-graphs)
- [Microsoft: measuring DPC/ISR time](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/example-15--measuring-dpc-isr-time)
- [Microsoft: Xperf actions](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/xperf-actions)

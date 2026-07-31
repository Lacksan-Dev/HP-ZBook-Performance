# EXP-001 layer 5 - kernel-pressure profile

- Cycle trigger: 2026-07-31T11:41:49Z
- Final passive capture: 2026-07-31T11:51:58Z to
  2026-07-31T11:52:13Z
- Layer: 5 - kernel, scheduler, memory, storage, interrupts, and DPC/ISR
  behavior
- Outcome: implemented
- Evidence state: observation-only baseline; no scheduler, interrupt,
  affinity, driver, memory, storage, service, registry, power, trace-session,
  or Windows setting changed
- Implementation commit: `1120154ceeb7ef6141a4a01a29fe3c358d72dbbc`
- Private raw evidence identifier:
  `20260731-115213-373-3400b8dc-kernel-pressure-profile.json`

## Customer-visible interval and engineering responsibility

Layer 5 owns the Windows execution path between runnable work and completed
CPU, interrupt, memory, and storage work. It can affect the delay between an
input or application request and a visible response. Windows owns the closed
kernel scheduler, memory manager, storage stack, interrupt dispatch, inbox
performance counters, and ETW providers. Hardware and signed drivers own the
interrupt sources and their ISR/DPC routines. Applications create runnable,
paging, and I/O demand. UX-ROM owns bounded collection, observer
qualification, redaction, structured evidence, and conservative
interpretation.

This run selected a passive local system-pressure window. Each block begins
before one documented 12-counter `Get-Counter` request and ends when all five
correlated samples return. The capability does not claim that the window is a
customer workflow. Its purpose is to establish a reliable screening baseline
before a later, declared slow interaction is traced and attributed.

Inputs are exact local aggregate counter paths, block count, samples per
block, interval, and calibration count. Outputs are all raw correlated
samples, raw and block-median distributions, block wall time, expected sample
span, combined observer/scheduling excess, sanitized machine conditions, and
WPR/WPA attribution readiness. No process, thread, stack, module, device,
driver, disk, file, path, adapter identity, address, command line, credential,
or customer content is collected.

Failure is contained to an unsupported result when `Get-Counter` is missing,
one of the exact counter paths is unavailable, the provider read fails, or a
block returns fewer samples than requested. English counter paths are
localized Windows resources, so another display language may require a
future localization resolver. The profiler never requests elevation and
never starts, stops, cancels, or exports a WPR session.

## Verified primary sources

Sources retrieved 2026-07-31:

- Microsoft Learn,
  [Get-Counter](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-counter?view=powershell-7.5):
  documents direct local performance-counter collection, `SampleInterval`,
  `MaxSamples`, localized names, and possible administrator requirements for
  protected counter sets.
- Microsoft Learn,
  [Network-related performance counters](https://learn.microsoft.com/en-us/windows-server/networking/technologies/network-subsystem/net-sub-performance-counters):
  documents `Interrupts/sec` and `DPCs Queued/sec`, including that the latter
  is a rate rather than a queue-depth value.
- Microsoft Learn,
  [Troubleshoot issues using Performance Monitor](https://learn.microsoft.com/en-us/troubleshoot/windows-server/support-tools/troubleshoot-issues-performance-monitor):
  documents the processor DPC/interrupt, context-switch, processor-queue,
  memory, and storage counter meanings used for screening.
- Microsoft Learn,
  [CPU analysis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/cpu-analysis):
  identifies the WPA DPC/ISR table and module/function views as the supported
  attribution step after an aggregate symptom is found.
- Microsoft Learn,
  [List of WPA graphs](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/list-of-wpa-graphs):
  documents DPC/ISR duration by module/function and the storage analysis
  graphs.
- Microsoft Learn,
  [Registering and queuing a DpcForIsr routine](https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/registering-and-queuing-a-dpcforisr-routine):
  documents the interrupt-service/DPC relationship and the need for an ISR to
  return quickly.
- Microsoft Learn,
  [Windows Performance Toolkit](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/):
  documents WPR and WPA as the supported trace recording and analysis tools.
- Microsoft Learn,
  [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1):
  documents the monotonic elapsed-time source used for calibration and block
  timing.

No community threshold, undocumented affinity value, scheduler tweak, driver
mutation, registry shortcut, or performance claim is used.

## Candidate scoring and selection

Scores are out of five; higher is better except risk, where lower is better.

| Candidate | Verified evidence | Expected workflow leverage | Reversible | Exact-host support | Measurable | Risk | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Repeated aggregate kernel-pressure blocks with observer qualification | 5 | 4 | 5 | 5 | 5 | 1 | Selected |
| Automatically start WPR and attribute modules | 5 | 5 | 5 | 2 | 5 | 2 | Deferred: WPA Exporter unavailable and no declared slow workflow |
| Change interrupt affinity or MSI registry state | 1 | 4 | 3 | 1 | 4 | 5 | Rejected: no verified device-specific contract or recovery evidence |
| Change MMCSS scheduling policy | 4 | 3 | 4 | 3 | 4 | 4 | Deferred: Tier 2 mutation and not justified by this baseline |
| Change core parking or processor policy | 5 | 3 | 4 | 3 | 4 | 3 | Deferred to Layer 6 ownership |
| Replace or patch the Windows scheduler | 0 | 5 | 0 | 0 | 1 | 5 | Rejected: closed and unsupported kernel boundary |

The selected improvement provides the missing evidence bridge: it can show
whether scheduler, interrupt, paging, or disk pressure overlaps a declared
slow interval without pretending an aggregate counter identifies a driver.

## Pre-registered experiment

- Hypothesis: a bounded, repeated, correlated 12-counter profile with a
  separately measured snapshot cost can screen for Layer 5 pressure more
  reliably than one unqualified point sample.
- Controlled variable: UX-ROM's observation method. No Windows or application
  setting is changed.
- Benchmark: one warmup; three complete-snapshot calibration iterations; then
  three blocks of five samples at a one-second interval.
- Start: immediately before each local `Get-Counter` block.
- Stop: after all five correlated sample sets return.
- Reset: no reset is required because collection is read-only; each block is
  retained independently.
- Timeout/bounds: 3-15 blocks, 3-60 samples per block, 1-10-second intervals,
  and 3-25 calibration iterations. The default nominal inter-sample span is
  12 seconds across three blocks, plus provider/observer work.
- Decision rule: ship only if the parser and full relevant Pester suite pass,
  all 12 exact paths are readable, exactly three blocks and 15 samples are
  retained, snapshot calibration and block excess are recorded, raw and
  block-median distributions are present, no sensitive identities are saved,
  and mutation/trace-start paths are absent.
- Performance rule: this passive baseline cannot prove a user-visible gain.
  A future change requires repeated control/treatment workflow runs and the
  experiment-specific rule before any gain claim.
- Risks: counter observer cost, localized names, unrelated background load,
  and mistaking an aggregate rate for driver attribution.
- Rollback: not applicable. The capability has no state-changing path.

## PowerShell engineering delivered

UX-ROM version `2026.07.31.3` adds the public `KernelProfile` action and routes
Layer 5 plus the single full-diagnostics workflow through it. The capability:

- checks `Get-Counter` and probes every required counter before collection;
- collects aggregate processor utility, DPC time, interrupt time, DPC and
  interrupt rates, context switches, processor queue, page reads, pages
  input, available memory, disk transfer latency, and disk queue length;
- converts disk transfer seconds to milliseconds at the evidence boundary;
- preserves every raw sample, each block distribution, the distribution of
  block medians, expected sample span, wall duration, and excess duration;
- calibrates one complete 12-counter snapshot after a warmup;
- records sanitized Windows, HP model, BIOS, processor, Edge, power, Battery
  Saver, thermal-provider, and network-state conditions;
- detects WPR, WPA, WPA Exporter, and current WPR state without changing that
  state;
- writes a uniquely named structured JSON record and safely tolerates a
  failure of the optional event journal; and
- states `BaselineOnlyNoPerformanceClaim` in the machine-readable result.

`README.md` includes the direct command and interpretation limits. The test
suite covers public parameter bounds, layer routing, raw-sample normalization,
disk-unit conversion, distributions, evidence structure, tool-state
retention, full-diagnostics integration, and absence of kernel/driver/service/
registry/power mutation commands.

## Passive lab result

Environment: HP ZBook Firefly 14 inch G8, Windows 11 Pro build 26200, BIOS T76
01.24.02, 11th Gen Intel Core i5-1145G7, 32 GB RAM, Edge 150.0.4078.99,
Balanced power scheme, AC online, Battery Saver off, one physical adapter up,
and no reported ACPI thermal-zone value. No workload was launched or
controlled.

The run retained three blocks and 15 samples. One complete 12-counter snapshot
cost 1026.9263 ms median and 1030.7171 ms p95 after warmup. Block wall times
were 5060.6016, 5076.8754, and 5068.3365 ms for a nominal 4000 ms inter-sample
span. The corresponding combined observer/scheduling excess values were
1060.6016, 1076.8754, and 1068.3365 ms. Values below are medians across all 15
raw samples unless marked as block medians:

- processor utility: 40.8106 percent;
- DPC time: 0 percent;
- interrupt time: 0.7765 percent;
- DPCs queued rate: 416.127 per second;
- interrupt rate: 52855.9211 per second;
- context-switch rate: 79014.4416 per second;
- processor queue length: 0;
- page reads and pages input: 0 per second;
- available memory: 17867 MB;
- disk transfer latency: 0.801 ms; and
- disk queue length: 0.

Across the three block medians, interrupt time ranged from 0.5764 to 0.9679
percent, interrupt rate from 47273.2617 to 53334.666 per second, context
switches from 75906.3446 to 79712.1788 per second, and disk latency from
0.4776 to 0.8594 ms. These numbers describe this short passive window only.
They are not compared with a control treatment and do not establish a harmful
threshold, responsible driver, customer-visible delay, or gain.

WPR was available and idle. WPA and WPA Exporter were unavailable, so
automated module/function attribution was not ready and UX-ROM did not start a
trace. A future attributed run must declare a specific slow workflow and
install the supported analyzer/export component first.

## Validation, safety, and decision

- Parser: passed.
- Focused UX-ROM suite: 106 passed, 0 failed.
- Full relevant non-destructive suite: 114 passed, 0 failed, 0 skipped in
  40.454 seconds. Nonfatal BitLocker access diagnostics from the unprivileged
  baseline tests did not fail the suite and no security state changed.
- Exact diff: passed `git diff --check` before the implementation commit.
- Live provider support: all 12 required aggregate paths returned.
- Structured output: three blocks, 15 samples, calibration, raw values,
  distributions, sanitized environment, and trace-tool state retained.
- State change: none.
- Rollback and reboot persistence: not applicable to an observation-only
  capability.

Decision: accept the PowerShell engineering improvement as an observation-only
Layer 5 baseline. Do not claim a performance improvement, name a responsible
driver, change affinity or scheduling state, email a validated result, or
publish an immediate result post.

## Next layer starting point

Layer 6 owns power management and performance policy. Begin by mapping the
active Windows power overlay, processor policy support, HP thermal/power
ownership, AC/DC state, and their customer-visible transition interval. Prefer
a reversible supported control or a bounded policy-response profiler. Do not
assume that a missing legacy High performance scheme should be recreated, and
do not change power policy without exact original-state capture, verification,
rollback, and repeated workflow measurements.

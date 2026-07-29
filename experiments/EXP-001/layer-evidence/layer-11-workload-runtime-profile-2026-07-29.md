# EXP-001 layer 11 - application workload runtime profiler

- Cycle timestamp: 2026-07-29T22:23:38Z
- Layer: 11 - application/runtime efficiency and workload profiles
- Outcome: implemented
- Evidence state: observation-only baseline; no process or Windows setting changed
- Implementation commit: `99793eca0bf48d217042919b6e83bbbc759285ef`
- Private final raw evidence identifier: `20260729-223714-workload-profile.json`
- Private rejected-prototype identifier: `20260729-223245-workload-profile.json`

## Customer-visible interval and engineering responsibility

This layer owns the work an application performs after it is running: processor
time, I/O transfer, resident and private memory, threads, handles, and process
lifecycle. The selected interval begins at one monotonic process snapshot and
ends at the next snapshot. Repeated intervals form a bounded steady-state
runtime profile for exact executable names.

Windows owns process accounting, process security, handles, scheduling, memory,
and I/O counters. The application owns its threads, allocation, caching, and
work. ZBookPerf owns exact-name selection, stable identity matching, interval
arithmetic, observer-cost calibration, redaction, aggregation, and evidence.

Inputs are exact executable names, duration, sample interval, current
environment, and the documented process accounting surfaces. Outputs are raw
intervals and distributions for logical-processor CPU, whole-machine CPU, read
and write transfer rates, working set, private memory, handles, threads,
starts/exits, access errors, and instrumentation cost.

Process ID alone is not a valid identity because Windows can reuse it.
ZBookPerf pairs process ID with start time. A start, exit, counter reset, denied
access, or missing target becomes explicit lifecycle or unavailable evidence;
it is never converted into an invented measurement.

## Verified primary sources

Sources retrieved 2026-07-29:

- Microsoft Learn, [Process.WorkingSet64](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.workingset64?view=netframework-4.8.1): documents refreshed physical working-set bytes and the `Process` sampling pattern.
- Microsoft Learn, [Process.GetProcessesByName](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.getprocessesbyname?view=netframework-4.8.1): documents retrieving local processes by executable base name.
- Microsoft Learn, [Process.StartTime](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.starttime?view=netframework-4.8.1), [UserProcessorTime](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.userprocessortime?view=netframework-4.8.1), and [PrivilegedProcessorTime](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.privilegedprocessortime?view=netframework-4.8.1): document the identity and cumulative processor-time values.
- Microsoft Learn, [GetProcessIoCounters](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getprocessiocounters): documents retrieving process I/O accounting through a process handle and its access requirements.
- Microsoft Learn, [IO_COUNTERS](https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-io_counters): documents cumulative read and write transfer byte counters.
- Microsoft Learn, [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1): documents the monotonic high-resolution timing mechanism and frequency.

No undocumented registry value, process injection, priority change, suspension,
termination, or proprietary binary interface is used.

## Candidate scoring and selection

Scores use a 0-5 scale for evidence, expected user-visible relevance,
reversibility, exact-system support, measurability, and engineering leverage.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Exact-name runtime profiler with stable process identity | 5 | 4 | 5 | 5 | 5 | 5 | 29 | Selected |
| Generic all-process counter expansion | 5 | 3 | 5 | 5 | 3 | 2 | 23 | Rejected; duplicates the existing broad sampler |
| Application priority controller | 4 | 3 | 4 | 4 | 3 | 3 | 21 | Deferred; no workload evidence selects a priority policy |
| Application termination or suspension coordinator | 3 | 2 | 3 | 2 | 3 | 2 | 15 | Rejected; functional and data-loss risk without a proven target |

The selected capability creates the missing workload contract needed before a
one-variable application/runtime experiment.

## Experiment design

Hypothesis: direct documented process accounting can produce a lower-overhead,
workload-scoped runtime baseline than the existing broad process sampler while
retaining stable identity and explicit missing-data behavior.

Controlled variable: instrumentation implementation only. The final validation
observed the already-running `explorer.exe` process for five seconds at a
requested 500 ms interval. No target process state was changed.

Decision rule for the engineering capability:

1. all unit and integration tests pass;
2. every final interval either reports a stable measurement or an explicit
   lifecycle/unavailable state;
3. no command line, executable path, window title, content, or network endpoint
   is collected;
4. median final snapshot cost is lower than the rejected CIM prototype; and
5. the run makes no performance-gain claim.

Rollback is source-code reversion. Runtime rollback and reboot testing do not
apply because the profiler only reads process state and writes lab evidence.

## Engineering result

`ZBookPerf.ps1` now exposes `-Action WorkloadProfile`, a `-WorkloadProfile`
switch, menu option 8, exact executable-name selection, bounded duration and
interval parameters, and observer-calibration controls.

The implementation:

1. rejects paths, wildcards, and command lines;
2. enumerates only exact executable base names;
3. calls `Process.Refresh` and reads cumulative CPU, working set, private
   memory, handles, threads, and start time;
4. calls the documented `GetProcessIoCounters` API for transfer bytes;
5. treats denied I/O access as null I/O while retaining accessible CPU and
   memory rather than fabricating zero or dropping the process;
6. pairs PID with start time and rejects counter resets;
7. uses monotonic timestamps for interval arithmetic;
8. calibrates the complete snapshot path separately;
9. preserves raw intervals, lifecycle changes, errors, distributions, p95
   observer budget, and estimated duty cycle; and
10. never launches, terminates, suspends, reprioritizes, or reconfigures a
    target process.

## Rejected implementation preserved

The first prototype used filtered `Win32_Process` CIM queries. On the same
target and duration it recorded a 179.087 ms median query cost, 189.562 ms p95,
and a 2085.182 ms estimated p95 observer budget across the run. At a 500 ms
interval that design consumed too much of the observed window and was rejected.

The final direct `System.Diagnostics.Process` plus `GetProcessIoCounters`
implementation replaced it. This was an instrumentation design improvement,
not a claim that Explorer became faster.

## Final lab validation

Target:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro 10.0.26200
- BIOS T76 01.24.02
- AC line: offline
- Battery Saver: off
- Target process: `explorer.exe`

Final observation:

- PowerShell parser: 0 errors.
- Focused ZBookPerf Pester 5.6.1 suite: 33 passed, 0 failed.
- Combined EXP-001 baseline plus ZBookPerf suite: 41 passed, 0 failed.
- Duration: 5 seconds.
- Requested interval: 500 ms.
- Calibration iterations: 5.
- Stable measured intervals: 10 of 10.
- Maximum observed target processes: 1.
- Median and p95 whole-machine CPU: 0% and 0%.
- Median read/write transfer rates: 0 / 0 bytes per second.
- Median working set: 516,632,576 bytes.
- Median private memory: 357,945,344 bytes.
- Median handles: 6,658.
- Median threads: 84.
- Snapshot median: 19.303 ms.
- Snapshot p95: 21.196 ms.
- Estimated total p95 observer budget: 233.156 ms.
- Estimated observer duty cycle: 4.629%.
- One interval snapshot took 134.159 ms; it is retained rather than removed.

These are descriptive values from one quiet Explorer observation. They are not
a diagnosis, customer performance claim, or before/after result.

## Decision and next layer

Accept the PowerShell profiler as an Experimental observation capability. The
engineering decision rule passed after the high-overhead CIM design was
replaced. Performance decision: baseline only, no optimization claim.

Next cycle: Layer 12 - workload data, storage locality, network dependencies,
and end-to-end reproducibility. Use the runtime profiler to bound application
process work only when Layer 12 separately records data location and dependency
conditions.

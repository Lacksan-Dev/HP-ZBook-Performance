# EXP-001 layer 1 - thermal-envelope profile

- Cycle timestamp: 2026-07-30T02:23:08Z
- Layer: 1 - physical and thermal health
- Outcome: implemented
- Evidence state: observation-only baseline; no workload, process, service,
  registry value, policy, power setting, driver, firmware, or Windows setting
  changed
- Implementation commit: `d422812932b5295e0705f82489e0edd23d9b48eb`
- Private final raw evidence identifier:
  `20260730-023511-800-36b37d85-thermal-envelope-profile.json`
- Private preliminary raw evidence identifier:
  `20260730-023342-059-9bdfe588-thermal-envelope-profile.json`

## Customer-visible interval and engineering responsibility

Layer 1 owns the physical conditions that can make a repeatable software
benchmark lie: power source, thermal policy, cooling response, and processor
performance limits. The selected interval begins immediately before one
passive processor-limit sample series and ends after its final bounded local
counter query.

Windows owns the Processor Information counterset and the ACPI thermal
framework. HP and Intel own the system's firmware, mechanical cooling design,
and OEM Dynamic Tuning policy. UX-ROM owns support detection, sampling bounds,
monotonic scheduling, observer calibration, evidence, and conservative
interpretation. UX-ROM does not replace the thermal manager, disable Intel
Dynamic Tuning Technology, control a fan, or translate an unidentified ACPI
zone into a CPU-package temperature.

Inputs are a declared duration, sample interval, calibration count, the inbox
Processor Information provider, and an optional ACPI-zone source. Outputs are
raw aggregate processor-limit, utility, performance, frequency, optional
anonymous zone readings, distributions, instrumentation cost, and a structured
baseline decision.

The processor counter query and ACPI preflight each have a five-second CIM
operation timeout. The sample interval cannot exceed the requested window.
Failed support detection ends before collection. Evidence names use
millisecond precision plus a random suffix so rapid runs cannot overwrite one
another. Recovery is source-code reversion because the profiler does not
change the observed system. Reboot persistence and setting rollback do not
apply.

## Verified primary sources

Sources retrieved 2026-07-30:

- Microsoft Learn, [Using the PerfLib functions to consume counter data](https://learn.microsoft.com/en-us/windows/win32/perfctrs/using-the-perflib-functions-to-consume-counter-data):
  identifies `% Processor Performance`, `% Processor Utility`,
  `% Performance Limit`, and `Performance Limit Flags` in the Processor
  Information counterset.
- Microsoft Learn, [Windows thermal-management design guide](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/design-guide):
  documents the firmware, sensor, thermal-zone, kernel-manager, and managed
  driver feedback loop. It also explains that a zone applies a thermal
  throttling percentage to its managed devices.
- Microsoft Learn, [CPU usage over 100% if Intel Turbo Boost is active](https://learn.microsoft.com/en-us/troubleshoot/windows-client/performance/cpu-usage-exceeds-100):
  explains why Processor Utility includes performance state and Turbo Boost
  and can exceed 100 percent.
- Microsoft Learn, [_PEP_PPM_QUERY_PERF_CONSTRAINTS](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/pep_x/ns-pep_x-_pep_ppm_query_perf_constraints):
  documents thermal, power, and domain-dependency reasons for a platform
  processor-performance constraint. UX-ROM does not assume the user-mode
  counter flags are a one-to-one decoding of this kernel contract.
- Microsoft Learn, [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1):
  documents the monotonic high-resolution elapsed-time source used for
  scheduling and observer qualification.
- Intel, [Dynamic Tuning Technology overview](https://www.intel.com/content/www/us/en/support/articles/000102775/processors.html):
  describes the OEM-configured coordination of performance, power, acoustics,
  and thermals.

No undocumented registry value, private kernel structure, proprietary binary,
stress workload, sensor driver, or arbitrary temperature threshold is used.

## Candidate scoring and selection

Scores use a 0-5 scale for verified evidence, expected relevance,
reversibility, exact-system support, measurability, and engineering leverage.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Passive Processor Information performance-limit profile | 5 | 5 | 5 | 5 | 5 | 5 | 30 | Selected |
| Treat unidentified ACPI-zone data as CPU-package temperature | 2 | 4 | 5 | 1 | 2 | 2 | 16 | Rejected; identity and access are unproven |
| Run an unattended CPU or fan stress diagnostic | 4 | 4 | 2 | 2 | 4 | 2 | 18 | Rejected; heats the daily-use machine and contaminates the next run |
| Disable or retune Intel DTT or firmware cooling | 3 | 4 | 1 | 1 | 3 | 2 | 14 | Rejected; unsupported Tier 2/3 mutation without disposable hardware and recovery |

The selected capability replaces the earlier guess based on current clock
speed and an arbitrary high ACPI-zone reading with a direct Windows-reported
processor performance-limit signal. It remains a diagnostic signal, not proof
of a thermal cause.

## Pre-registered experiment design

Hypothesis: the documented inbox Processor Information counterset can add an
explicit, repeatable processor performance-limit signal to UX-ROM while
preserving unavailable ACPI-zone evidence and avoiding unsupported thermal
claims or generated load.

Controlled variable: instrumentation implementation only. No workload or
Windows state was changed.

Benchmark:

1. verify the required counter class, `_Total` instance, and properties;
2. probe ACPI-zone availability once and preserve only status or exception
   type if unavailable;
3. warm the complete sample path once and calibrate it three times;
4. collect six passive samples over a declared five-second window at one-second
   intervals;
5. retain raw values plus median, p95, minimum, and maximum distributions;
6. report a limit only when `% Performance Limit` falls below 100 or a
   nonzero raw limit flag appears; and
7. refuse to attribute that signal to temperature without stronger evidence.

Engineering decision rule:

1. the PowerShell parser reports zero errors;
2. the focused and full relevant Pester suites pass;
3. support detection confirms all required Processor Information properties;
4. six of six requested samples complete with five-second CIM operation
   timeouts;
5. calibrated and measured query p95 remain below 500 ms at the one-second
   interval;
6. actual series duration is no more than one second beyond the requested
   window;
7. unavailable ACPI data is preserved without repeated failing queries;
8. no state-changing command is reachable from the profiler; and
9. the result makes no thermal-health or performance-gain claim.

## Engineering result

`ZBookPerf.ps1` now exposes `-Action ThermalProfile`, the equivalent
`-ThermalProfile` switch, calibration bounds, Layer 1 workflow integration, and
full-diagnostics manifest integration. UX-ROM version is `2026.07.30.7`.

The profiler:

1. verifies the required inbox provider, `_Total` instance, and properties;
2. records explicit `% Performance Limit` and raw `Performance Limit Flags`
   beside processor time, utility, performance, and frequency;
3. uses one ACPI preflight and skips the source during the series when it is
   unavailable;
4. applies a five-second timeout to every CIM operation;
5. warms and calibrates its complete sample path;
6. schedules a bounded series with a monotonic stopwatch;
7. stores raw samples, distributions, support state, environment, and observer
   cost in a unique structured JSON file;
8. treats event-journal failure as secondary after primary evidence is safe;
9. contains no load generator or Windows mutation command; and
10. states explicitly that a reported processor limit is not automatically a
    thermal limit.

## Preserved preliminary result

The first complete live run queried the inaccessible ACPI namespace during
every sample. It still produced valid primary evidence, but the repeated
failure was unnecessary. Its sample-query median was 310.616 ms and p95 was
333.858 ms.

The final implementation performs one ACPI preflight and records
`CimException` plus `Unavailable`. It then skips that source during the timed
series. The final sample-query median was 298.9625 ms and p95 was 307.88 ms.
Most remaining wall time belongs to the local formatted Processor Information
provider, so the implementation records rather than hides that cost.

Both runs saved primary JSON successfully. The optional shared event journal
could not be appended because its existing permissions rejected this process;
that secondary failure did not invalidate or erase the evidence.

## Final lab validation

Target and controlled conditions:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro 10.0.26200
- BIOS T76 01.24.02
- Intel Core i5-1145G7, 4 cores / 8 logical processors
- AC online; Battery Saver off; Balanced power scheme
- Intel Dynamic Tuning Manager and participants present at
  `8.7.10802.26924`
- no generated workload, fan test, process control, setting change, or reboot

Final observation:

- PowerShell parser: 0 errors.
- Focused Pester 5.7.1 suite: 78 passed, 0 failed.
- Full relevant Pester 5.7.1 suite: 86 passed, 0 failed.
- Samples: 6 of 6 completed.
- Requested interval/window: 1 second / 5 seconds.
- Actual series duration: 5,329.082 ms.
- Windows `% Performance Limit` minimum: 100 percent.
- Nonzero performance-limit flag samples: 0.
- Median `% Processor Performance`: 141 percent. Turbo Boost can make this
  value exceed 100 percent; it is not CPU utilization.
- Median `% Processor Utility`: 34.5 percent.
- Median Processor Frequency: 2,083 MHz.
- Observer calibration median/p95: 288.438 / 299.492 ms.
- Measured sample-query median/p95: 298.9625 / 307.88 ms.
- ACPI thermal-zone preflight: unavailable, `CimException`.
- Status: `NoProcessorPerformanceLimitObserved`.
- Decision: `BaselineOnlyNoPerformanceClaim`.

This passive five-second window did not observe a Windows processor
performance limit. It does not prove that the cooling system is healthy under
another load, establish ambient temperature or fan state, or validate a
performance improvement.

## Decision and next layer

Accept the PowerShell thermal-envelope profiler as an Experimental Layer 1
diagnostic capability. The engineering decision rule passed. No validated
performance improvement occurred, so this run does not qualify for email,
YouTube, or website publication.

Next cycle: Layer 2 - hardware resources and bottlenecks. Use the new
performance-limit series beside CPU, memory, storage, and hardware-queue
measurements so a hardware bottleneck is not confused with an active platform
limit.

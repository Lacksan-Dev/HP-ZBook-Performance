# EXP-001 layer 7 - protection-preserving security activity profile

- Cycle timestamp: 2026-07-31T15:42:53Z
- Layer: 7 - security and isolation overhead without reducing protection
- Outcome: implemented
- Evidence state: observation-only baseline; no protection, exclusion, firewall
  profile or rule, VBS service, process, service, policy, registry value, reboot
  state, or Windows setting changed
- Implementation commit: `d798022928492d091dd62819c95827f8572387f7`
- Private successful raw evidence identifier:
  `20260731-160037-security-profile.json`

## Customer-visible interval and engineering responsibility

This layer owns the security work that can occur between a user action and its
visible result: antivirus inspection, network inspection, code-integrity
enforcement, and isolation boundaries. Windows and Microsoft Defender own the
protection contracts. Device management may own effective policy. UX-ROM owns
only bounded observation, safe attribution, structured evidence, and the
decision about whether a deeper controlled trace is warranted.

Inputs are selected effective-state signals from Microsoft Defender Antivirus,
active Windows Firewall profiles, `Win32_DeviceGuard`, a fixed catalog of
Microsoft security process names, and documented Windows Process performance
counters. Outputs are a redacted protection-state record, repeated CPU, I/O,
and private-working-set samples, observer-cost qualification, and a
baseline-only decision.

The timing path is user or background work -> security inspection or isolation
boundary -> permitted execution or I/O -> visible result. A process-level
counter can show concurrent security activity, but it cannot prove that the
activity delayed a specific user action. Deeper file-level Defender recording
is a separate elevated experiment because it can expose file paths.

Failure is explicit. The profile stops if the localized Process performance
counter category or every fixed target process is unavailable. Defender,
firewall, and Device Guard state queries may report `Unavailable` independently
without inventing a state. Counter objects are disposed in every exit path.
Recovery and reboot-persistence testing do not apply because nothing is
changed; source-code reversion removes the observer.

## Verified primary sources

Sources retrieved 2026-07-31:

- Microsoft Learn, [Get-MpComputerStatus](https://learn.microsoft.com/en-us/powershell/module/defender/get-mpcomputerstatus):
  documents the read-only Defender antimalware status command.
- Microsoft Learn, [Microsoft Defender Antivirus Performance Analyzer reference](https://learn.microsoft.com/en-us/defender-endpoint/performance-analyzer-reference):
  documents `New-MpPerformanceRecording` and `Get-MpPerformanceReport`, Windows
  10-or-later and Defender platform requirements, the elevation requirement,
  and the warning that exclusions reduce protection. UX-ROM inventories these
  commands but does not start a recording.
- Microsoft Learn, [Get-NetFirewallProfile](https://learn.microsoft.com/en-us/powershell/module/netsecurity/get-netfirewallprofile):
  documents that `-PolicyStore ActiveStore` returns the effective combination
  of applicable firewall policy stores.
- Microsoft Learn, [Credential Guard overview](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/):
  documents that Credential Guard uses virtualization-based security to
  isolate secrets and defines the supported Windows boundary.
- Microsoft Learn, [PerformanceCounter.NextValue](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.performancecounter.nextvalue?view=netframework-4.8.1):
  documents calculated counter reads and the need for two reads with about a
  one-second delay for rate counters. UX-ROM primes each counter, waits one
  second, and then calibrates the warmed session.
- Microsoft Learn, [Collecting performance data](https://learn.microsoft.com/en-us/windows/win32/perfctrs/collecting-performance-data):
  documents that Process `% Processor Time` sums thread activity and can range
  to 100 times the processor count. UX-ROM records that logical-processor value
  and divides by the recorded logical processor count for machine percentage.
- Microsoft Learn, [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1):
  documents the monotonic timer used for scheduling and observer timing.

No community registry value, Defender exclusion, protection disablement,
firewall rule change, undocumented kernel contract, service stop, driver
change, or firmware operation is used.

## Layer design map

| Concern | Contract and owner |
|---|---|
| User input | A foreground or background workflow requests execution, file, or network work. |
| Security input | Defender, firewall, code-integrity, and isolation policy define required checks. |
| Runtime work | Microsoft protection engines and Windows isolation boundaries inspect or constrain the work. |
| Output | Work is permitted, blocked, or delayed; UX-ROM observes only aggregate process activity and selected effective state. |
| Timing path | Work request -> protection/isolation path -> completion -> visible response. |
| Extension point | Documented PowerShell/CIM status providers and Windows performance counters. |
| Failure behavior | Missing providers, permissions, localized counters, target exit, or high observer cost remain explicit. |
| Recovery | Dispose counters; no runtime rollback or reboot is required because the observer mutates nothing. |
| Security boundary | Never enumerate exclusions, threats, firewall rules, paths, command lines, identities, recovery material, or customer content. |

## Candidate scoring and selection

Scores use a 0-5 scale for evidence, expected relevance, reversibility, exact
system support, measurability, and engineering leverage. Risk is 1 for lowest
risk and 5 for highest risk.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Risk | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Protection-state plus warmed security-process counter profile | 5 | 4 | 5 | 5 | 5 | 5 | 1 | Selected |
| Defender performance recording during a synthetic workflow | 5 | 5 | 5 | 4 | 5 | 5 | 3 | Deferred; elevated recording and path-bearing evidence need a separate redaction protocol |
| Disable Defender or add broad exclusions | 5 | 3 | 3 | 0 | 3 | 0 | 5 | Rejected; weakens protection and lacks attributed evidence |
| Disable VBS, Memory Integrity, or Credential Guard | 5 | 3 | 2 | 0 | 3 | 0 | 5 | Rejected; violates the security boundary |
| Change firewall profiles, rules, or services | 5 | 1 | 3 | 0 | 2 | 0 | 5 | Rejected; no network-path evidence and protection would change |
| Patch Windows isolation or security internals | 0 | 4 | 0 | 0 | 1 | 1 | 5 | Rejected; closed and unsupported contract |

The selected capability closes the earlier Layer 7 evidence gap without using
the proposed security-reducing shortcuts.

## Pre-registered experiment design

Hypothesis: selected effective protection state plus repeated, warmed Process
counter samples for a fixed Microsoft security catalog can bound observable
security activity and identify whether a deeper Defender performance recording
is justified, without weakening protection or collecting private paths.

Controlled variable: instrumentation only. No security setting, process,
service, policy, firewall state, registry value, workload, power state, or
reboot state changed.

Benchmark:

1. detect the localized Process counter category and fixed target instances;
2. record exact Windows, HP, BIOS, processor, Edge, power, thermal, and network
   context available to the observer;
3. read selected Defender, ActiveStore firewall, and Device Guard state;
4. create read-only counters for CPU, read I/O, write I/O, and private working
   set for only the observed fixed targets;
5. prime each rate counter, wait one second, and calibrate five warmed reads;
6. collect five samples at 2,000 ms spacing over ten seconds; and
7. retain raw values and query durations without overhead correction.

Engineering decision rule:

1. the PowerShell parser reports zero errors;
2. focused and full relevant non-destructive tests pass;
3. at least one fixed security target is available;
4. at least five measured samples are retained;
5. Defender, active firewall profile, and Device Guard queries report their
   actual state or an explicit unavailable status;
6. setup, warmup, calibration, raw samples, and estimated observer duty are
   retained;
7. no paths, commands, identities, exclusions, firewall rules, or customer
   content are stored;
8. no security or Windows state changes; and
9. the result makes no performance-gain claim.

Stop conditions were every target missing, performance-counter failure, a
security mutation, sensitive-field collection, fewer than five measured
samples, or a failed test. Rollback is source-code reversion only.

## PowerShell engineering result

`ZBookPerf.ps1` now exposes `-Action SecurityProfile`, `-SecurityProfile`, a
bounded sample interval and calibration count, Layer 7 workflow routing, a
direct maintenance-menu entry, and full-diagnostic integration.

The implementation:

1. captures selected effective-state signals without exclusions, rules, paths,
   identities, or recovery material;
2. uses a fixed four-process Microsoft security catalog and records only
   processes present on the target;
3. creates read-only `System.Diagnostics.PerformanceCounter` objects for four
   resource metrics;
4. normalizes Process CPU by the recorded logical processor count while
   retaining the original logical-processor percentage;
5. primes the rate counters once and calibrates the complete warmed query;
6. records bounded raw samples and an estimated p95 observer duty cycle;
7. disposes every counter after success or failure;
8. inventories Defender's deeper analyzer but does not run it;
9. writes unique structured evidence and a bounded event summary; and
10. labels the outcome `BaselineOnlyNoPerformanceClaim`.

Automated tests cover the public contract, layer catalog and routing, fixed
counter normalization, redaction, summary behavior, protection-state
selection, mutation exclusions, direct routing, and full-diagnostic inclusion.

## Lab measurements

Target and controlled conditions:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro build 26200
- BIOS T76 01.24.02
- Intel Core i5-1145G7, 4 cores and 8 logical processors
- Microsoft Edge 150.0.4078.99
- AC online; Battery Saver off
- one physical network adapter up
- passive foreground capture; no workload launched
- five final samples at 2,000 ms spacing over ten seconds
- five observer-calibration iterations after one-second rate-counter warmup
- no UAC elevation, reboot, security change, or Windows mutation

Observed state and measurements:

- Defender status available; real-time protection, tamper protection,
  antimalware service, antivirus, antispyware, behavior monitoring, I/O
  attachment scanning, Network Inspection, and on-access protection reported
  enabled; running mode `Normal`.
- Defender product version `4.18.26060.3008`, engine `1.1.26060.3008`, and
  signature `1.455.436.0`.
- Domain, Private, and Public active firewall profiles reported enabled with
  inbound Block and outbound Allow defaults.
- VBS status reported 2 (running by the `Win32_DeviceGuard` contract);
  security service codes 1 and 2 were running.
- Observed target instances: `MsMpEng` and `NisSrv`.
- Measured samples: 5 of 5.
- Security-process machine CPU median 1.5601%; p95 3.2637%; range
  1.1743-3.2637%.
- Read and write I/O median and p95: 0 bytes/sec during this idle window.
- Private working-set median 240,734,208 bytes; range
  236,445,696-242,036,736 bytes.
- Counter-session initialization: 288.472 ms; one-second rate warmup.
- Warmed observer calibration median 145.987 ms; p95 170.996 ms.
- Estimated total p95 observer budget 854.980 ms, or 8.548% of the measured
  window. Values are not overhead-corrected.
- Focused Pester 5.7.1 suite: 121 passed, 0 failed, 0 skipped.
- Full relevant Pester 5.7.1 suite: 129 passed, 0 failed, 0 skipped.

These measurements describe a short passive window. They do not prove that
security caused 1.5601% of a user-visible delay, that the machine is idle in
all conditions, or that changing protection would improve responsiveness.

## Documented facts, lab measurements, hypothesis, and unknowns

Documented facts:

- Defender exposes read-only antimalware status through
  `Get-MpComputerStatus`;
- ActiveStore represents the effective firewall profile configuration;
- Credential Guard and code integrity use VBS protection boundaries;
- Process `% Processor Time` can exceed 100% and must be interpreted against
  processor count; and
- Defender's deeper performance recording requires elevation and can report
  file paths. Microsoft warns that exclusions reduce protection.

Lab measurements are the exact state and timing distributions above.

Hypothesis: a controlled synthetic workflow that overlaps a repeatable
security CPU or I/O spike may justify a separate redacted Defender recording.

Unknowns:

- which files or workflow caused the observed CPU activity;
- whether the activity changed any defined foreground interval;
- how much observer activity affected the observed processes;
- whether a repeatable workload would produce nonzero security I/O; and
- whether a supported application-level change can reduce duplicate scanning
  without weakening protection.

## Decision and next layer

Accept the security activity profiler as an Experimental observation
capability. All engineering decision gates passed. Performance decision:
baseline only; no optimization claim and no validated-result email.

This is the fourth completed layer since the most recent engineering digest,
so a digest covering Layers 4, 5, 6, and 7 is due after the source merge.

Next cycle: Layer 8 - boot, services, tasks, background permissions, and startup
applications. Define off-to-usable state and ship one bounded readiness or
startup engineering capability before considering any startup mutation.

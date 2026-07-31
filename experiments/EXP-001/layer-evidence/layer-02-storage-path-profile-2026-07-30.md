# EXP-001 layer 2 - storage-path bottleneck profile

- Cycle trigger: 2026-07-30T13:49:57Z
- Final passive capture: 2026-07-31T07:19:53Z to
  2026-07-31T07:19:58Z
- Layer: 2 - hardware resources and bottlenecks
- Outcome: implemented
- Evidence state: observation-only baseline; no synthetic storage load, file
  read, service, registry value, policy, power setting, driver, firmware, or
  Windows setting changed
- Implementation commit: `1b948d23607015a118df7e608f9244ddbfa01b7c`
- Private raw evidence identifier:
  `20260731-071958-776-dcad506d-hardware-storage-path-profile.json`

The trigger timestamp and the lab host's UTC capture timestamp differ by
approximately 17 hours. Both are preserved instead of silently rewriting
either clock. The sampling series itself uses a monotonic stopwatch.

## Customer-visible interval and engineering responsibility

Layer 2 owns the physical resource path behind pauses that can look like a
Windows or application problem. The selected interval begins immediately
before a passive series of per-disk counter reads and ends after its final
bounded query. This run narrows the layer to one engineering question: can
UX-ROM identify the installed storage transport and measure per-disk latency,
queue, throughput, and activity without opening a user file or generating a
benchmark workload?

Windows owns the Storage management provider, formatted PhysicalDisk
counterset, storage class and port drivers, and Plug and Play driver metadata.
HP and the storage vendor own the physical device, firmware qualification, and
platform integration. UX-ROM owns provider detection, field redaction,
bounded sampling, monotonic scheduling, observer calibration, distributions,
structured evidence, and conservative interpretation.

Inputs are a declared duration, sample interval, calibration count, the inbox
formatted PhysicalDisk provider, optional `Get-PhysicalDisk` inventory, and
signed storage-controller driver metadata. Outputs are redacted disk model,
firmware, media and bus class, health state, controller provider/version, raw
per-disk samples, distributions, observer cost, and an explicit baseline-only
decision.

Every CIM call has a five-second operation timeout. The interval cannot exceed
the requested window. No serial number, unique ID, PNP ID, volume label, path,
file, user content, credential, or network destination is collected. Failed
support detection ends before collection. Recovery and reboot-persistence
testing do not apply because the capability does not change Windows.

## Verified primary sources

Sources retrieved 2026-07-30:

- Microsoft Learn, [Get-PhysicalDisk](https://learn.microsoft.com/en-us/powershell/module/storage/get-physicaldisk):
  documents the inbox Storage cmdlet that returns physical disks visible to
  Storage Management Providers.
- Microsoft Learn, [MSFT_PhysicalDisk class](https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/msft-physicaldisk):
  documents read-only model, firmware, media, health, operational status, size,
  and bus-type fields, including SATA and NVMe.
- Microsoft Learn, [Get-Counter](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-counter):
  documents direct access to Windows performance counters and the per-instance
  PhysicalDisk paths.
- Microsoft Learn,
  [Win32_PerfRawData_PerfDisk_PhysicalDisk](https://learn.microsoft.com/en-us/previous-versions/aa394308%28v%3Dvs.85%29):
  documents the corresponding formatted provider and the disk latency and
  queue fields.
- Microsoft Learn,
  [Troubleshoot performance problems in Windows](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/troubleshoot-performance-problems-in-windows):
  explains that physical disk latency must be correlated with process and
  workload evidence and that longer periods matter more than short spikes.
  UX-ROM deliberately does not apply the server guidance as an automatic
  pass/fail threshold to this short Windows 11 client capture.
- Microsoft Learn,
  [Win32_PnPSignedDriver](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/whqlprov/win32-pnpsigneddriver):
  documents the read-only device-class, name, provider, version, and date
  metadata used for storage-controller context.
- Microsoft Learn, [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1):
  documents the monotonic elapsed-time source used for scheduling and observer
  qualification.

No community registry value, undocumented interface, destructive benchmark,
driver change, firmware change, or transport-based performance claim is used.

## Candidate scoring and selection

Scores use a 0-5 scale for verified evidence, expected relevance,
reversibility, exact-system support, measurability, and engineering leverage.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Redacted storage transport plus per-disk counter profile | 5 | 5 | 5 | 5 | 5 | 5 | 30 | Selected |
| Run DiskSpd or WinSAT unattended | 5 | 4 | 3 | 3 | 5 | 3 | 23 | Rejected; generates I/O on the daily-use machine |
| Infer that SATA is the active bottleneck from bus type alone | 2 | 5 | 5 | 5 | 1 | 1 | 19 | Rejected; transport is context, not measured causation |
| Replace the SATA SSD or controller driver | 4 | 5 | 1 | 1 | 4 | 2 | 17 | Rejected; outside unattended Tier 0 and not reversible in software |

## Pre-registered experiment design

Hypothesis: documented inbox Storage and PhysicalDisk providers can give UX-ROM
a bounded, redacted view of the real storage path and passive latency/queue
behavior, making storage bottlenecks easier to diagnose without contaminating
the system with a generated workload.

Controlled variable: instrumentation implementation only. No workload or
Windows state was changed.

Benchmark:

1. verify the formatted PhysicalDisk class, all required properties, and at
   least one non-total disk instance;
2. inventory supported physical-disk fields without identifiers;
3. inventory only storage-controller device class, name, provider, version,
   and date;
4. warm the complete per-disk counter query once and calibrate it three times;
5. collect six passive samples over a declared five-second window at
   one-second intervals;
6. retain raw values plus median, p95, minimum, and maximum distributions; and
7. make no bottleneck or gain decision from transport or an idle sample alone.

Engineering decision rule:

1. the PowerShell parser reports zero errors;
2. the focused and full relevant Pester suites pass;
3. support detection confirms every required per-disk property;
4. six of six samples complete with five-second CIM operation timeouts;
5. observer and measured query p95 remain below the one-second interval;
6. actual series duration is no more than one second beyond the requested
   window;
7. the saved JSON contains no serial, unique, PNP, volume, path, or file field;
8. no workload generator or state-changing command is reachable from the
   profiler; and
9. the result makes no storage-upgrade or performance-gain claim.

## Engineering result

`ZBookPerf.ps1` now exposes `-Action HardwareProfile`, the equivalent
`-HardwareProfile` switch, calibration bounds, Layer 2 workflow routing, and
single full-diagnostics manifest integration. UX-ROM version is
`2026.07.30.8`.

The capability:

1. verifies the exact formatted PhysicalDisk fields and a per-disk instance;
2. records redacted Storage provider inventory when available;
3. records only storage-controller driver metadata needed for compatibility
   context;
4. reads transfer/read/write latency, current and average queue, throughput,
   transfers, disk time, and idle time per physical-disk instance;
5. warms and calibrates its complete timed query;
6. schedules a bounded series with a monotonic stopwatch;
7. stores raw samples and distributions in a unique structured JSON file;
8. preserves the primary evidence if the optional event journal fails; and
9. states that transport type alone does not prove a bottleneck and an idle
   window is not a benchmark.

## Final lab validation

Target and controlled conditions:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro build 26200
- BIOS T76 01.24.02
- Intel Core i5-1145G7, 4 cores / 8 logical processors
- AC online; Battery Saver off; Balanced power scheme
- SK hynix HFS256G39TNF-N3A0A, firmware 70000P10
- 256,060,514,304-byte SSD reported as SATA and Healthy
- Microsoft Standard SATA AHCI Controller 10.0.26100.8521
- Intel RST VMD Controller 9A0B 18.7.6.1010 also present in the signed-driver
  inventory; presence alone does not prove it owns the observed disk path
- no generated I/O, file access, process control, setting change, or reboot

Final observation:

- PowerShell parser: 0 errors.
- Focused Pester 5.7.1 suite: 85 passed, 0 failed.
- Full repository-required EXP-001 Pester suite: 93 passed, 0 failed.
- Samples: 6 of 6 completed.
- Requested interval/window: 1 second / 5 seconds.
- Actual series duration: 5,310.46 ms.
- Observer calibration median/p95: 279.74 / 281.16 ms.
- Measured query median/p95: 293.7735 / 307.705 ms.
- Physical-disk inventory: Read.
- Storage-controller inventory: Read.
- Observed physical-disk instances: 1.
- Median transfer/read/write latency: 0 / 0 / 0 ms in this idle window.
- Median current queue: 0.
- Median throughput: 160,211.5 bytes/second.
- Status: installed transport observed as SATA.
- Decision: `BaselineOnlyNoPerformanceClaim`.

This five-second passive window confirms the hardware and measurement path. It
does not prove the SATA device is limiting a customer workflow, compare it with
NVMe, establish peak capability, or validate a performance improvement.

One broader exploratory invocation also included the separate legacy
`experiments/EXP-001/tool/tests` Pester file. It reported 15 failures because
that file uses legacy `Should` syntax and expects functions loaded by its own
runner. This is not the repository-required workflow suite and none of those
tests exercise the changed root `ZBookPerf.ps1`. The failed invocation is
preserved here rather than represented as a product pass. The exact
repository-required paths from
`.github/workflows/exp001-baseline-pester.yml` passed 93 of 93.

## Decision and next layer

Accept the PowerShell storage-path profiler as an Experimental Layer 2
diagnostic capability. The engineering decision rule passed for the live
profile and the local repository-required suite; GitHub checks remain the
merge gate recorded by the pull request.

No validated performance improvement occurred, so this run does not qualify
for email, YouTube, or website publication.

Next cycle: Layer 3 - BIOS, UEFI, embedded-controller, and firmware
interactions. Start with a supported, redacted firmware/boot-path inventory and
measurement boundary before proposing any firmware mutation.

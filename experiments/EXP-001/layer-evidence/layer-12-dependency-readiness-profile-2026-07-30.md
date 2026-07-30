# EXP-001 layer 12 - dependency readiness profile

- Cycle timestamp: 2026-07-30T00:23:36Z
- Layer: 12 - workload data, storage locality, network dependencies, and end-to-end reproducibility
- Outcome: implemented
- Evidence state: observation-only baseline; no file content, process, service, registry value, policy, driver, firmware, or Windows setting changed
- Implementation commit: `7a81ed6399e82e6cfe664a5e80f868bb15f70a6e`
- Private successful raw evidence identifier: `20260730-003732-dependency-profile.json`
- Private preserved failed-run identifier: `20260730-003620-dependency-profile.json`

## Customer-visible interval and engineering responsibility

This layer owns the conditions between an application's request for workload
data and the point where required storage and network dependencies are ready.
The selected path interval is one bounded metadata inventory. The selected
network interval begins before a documented asynchronous TCP connection request
and ends at connection readiness, an explicit failure, or a declared timeout.

Windows owns path parsing, drive classification, file attributes, cloud-file
metadata, name resolution, sockets, and storage/network drivers. Storage and
cloud providers own reparse or placeholder behavior. Applications own which
paths, endpoints, protocols, and readiness semantics their workflow requires.
UX-ROM owns declared dependency selection, safe bounds, redaction, monotonic
timing, repeated probes, observer qualification, evidence, and comparison.

Inputs are declared paths, optional `host:port` endpoints, probe count, timeout,
the current machine environment, and documented .NET/Windows interfaces.
Outputs are redacted path identities, locality and file-system conditions,
endpoint readiness distributions, a deterministic condition signature, and
structured raw evidence.

A network share can block an ordinary existence query when unavailable. UX-ROM
therefore classifies UNC and mapped-network paths without opening them. It does
not enumerate directories or read files. An endpoint probe opens and closes a
TCP connection but sends no application payload. That proves only connection
readiness; it does not prove application authentication, protocol health,
throughput, or end-to-end workload readiness.

Failure behavior is explicit: invalid declarations fail before probing; every
endpoint probe is timeout-bounded; path metadata errors retain only the
exception type; completed evidence remains usable if the optional JSONL event
journal is not writable. Recovery is source-code reversion because the
capability changes no observed state. Reboot-persistence and state rollback do
not apply.

## Verified primary sources

Sources retrieved 2026-07-30:

- Microsoft Learn, [DriveInfo class](https://learn.microsoft.com/en-us/dotnet/api/system.io.driveinfo?view=netframework-4.8.1): documents querying drive type, readiness, file-system format, capacity, and available space.
- Microsoft Learn, [DriveType enumeration](https://learn.microsoft.com/en-us/dotnet/api/system.io.drivetype?view=netframework-4.8.1): defines fixed, removable, network, optical, RAM, unknown, and missing-root drive classes.
- Microsoft Learn, [File attribute constants](https://learn.microsoft.com/en-us/windows/win32/fileio/file-attribute-constants): documents reparse-point, offline, pinned, unpinned, and recall-on-data-access metadata and explains that recall-on-data-access indicates content that is not fully present locally.
- Microsoft Learn, [DirectoryInfo class](https://learn.microsoft.com/en-us/dotnet/api/system.io.directoryinfo?view=netframework-4.8.1): documents local, relative, and UNC path forms accepted by the .NET file-system surface.
- Microsoft Learn, [TcpClient.BeginConnect](https://learn.microsoft.com/en-us/dotnet/api/system.net.sockets.tcpclient.beginconnect?view=netframework-4.8.1): documents the non-blocking asynchronous TCP connection request and the requirement to complete it with `EndConnect`.
- Microsoft Learn, [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1): documents the high-resolution monotonic timer used for observer and probe intervals.
- Microsoft Learn, [SHA256](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.sha256?view=netframework-4.8.1): documents the hash algorithm used to replace raw dependency identities in evidence.

No undocumented registry value, private Windows contract, proprietary binary,
packet injection, file recall, directory enumeration, or file-content read is
used.

## Candidate scoring and selection

Scores use a 0-5 scale for verified evidence, expected relevance,
reversibility, exact-system support, measurability, and engineering leverage.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Redacted storage-locality plus bounded declared-endpoint readiness profile | 5 | 5 | 5 | 5 | 5 | 5 | 30 | Selected |
| Destructive disk or network throughput benchmark | 4 | 4 | 2 | 3 | 5 | 3 | 21 | Rejected; unsafe and poorly representative unattended |
| Automatic cloud-placeholder recall before workloads | 4 | 4 | 2 | 2 | 3 | 2 | 17 | Rejected; can transfer customer data and consume storage/network |
| Disable cloud sync or remove network dependencies | 2 | 3 | 2 | 1 | 2 | 1 | 11 | Rejected; breaks the workload contract instead of measuring it |

The selected profiler creates the missing reproducibility contract needed
before claiming that an application, storage, or network change caused an
end-to-end improvement.

## Pre-registered experiment design

Hypothesis: documented file-system metadata and timeout-bounded TCP connection
attempts can capture workload dependency conditions with redacted identities
and low path-inventory overhead, making separate performance runs easier to
reproduce without recalling or reading workload data.

Controlled variable: instrumentation implementation only. The final lab
validation observed one declared repository root and the public GitHub HTTPS
endpoint. No workload or Windows state was changed.

Benchmark:

1. inventory the declared path without enumeration or content access;
2. calibrate that complete path-inventory call five times after one warmup;
3. make five TCP readiness probes with a 1,500 ms per-probe timeout;
4. retain raw status/duration values and their median/p95;
5. verify that the evidence contains neither the raw repository path nor host;
6. repeat the same declarations and compare the condition signature.

Engineering decision rule:

1. the PowerShell parser reports zero errors;
2. all focused automated tests pass;
3. every endpoint attempt ends as ready, failed, or timeout within the declared
   budget;
4. raw paths, host names, IP addresses, directory entries, and file content are
   absent from evidence;
5. path-inventory p95 is no more than 10 ms for the one-path lab baseline;
6. unchanged structural conditions produce the same signature even when probe
   duration changes; and
7. the result makes no performance-gain claim.

Rollback is source-code reversion. Runtime rollback and reboot testing do not
apply because the profiler reads metadata, opens bounded TCP connections, and
writes only lab evidence.

## Engineering result

`ZBookPerf.ps1` now exposes `-Action DependencyProfile`,
`-DependencyProfile`, declared path and endpoint parameters, repeated-probe and
timeout bounds, calibration control, maintenance-menu option 9, Layer 12 catalog
coverage, and full-diagnostic integration.

The implementation:

1. validates `host:port` declarations before network activity;
2. hashes normalized path and endpoint identities with SHA-256;
3. classifies fixed, removable, mapped-network, UNC, and known OneDrive-root
   locations;
4. records drive readiness, format, capacity conditions, and documented
   reparse/offline/pin/recall metadata;
5. skips unbounded network-path existence and metadata calls;
6. enumerates no directory and reads no file content;
7. bounds every `TcpClient.BeginConnect` call, completes successful operations
   with `EndConnect`, sends no payload, and closes the client;
8. calibrates complete path-inventory overhead;
9. records raw readiness status/duration and aggregate distributions;
10. builds a stable condition signature that excludes timing;
11. gives every evidence filename millisecond precision plus a random suffix so
    rapid runs cannot overwrite each other; and
12. keeps completed primary evidence when the optional event journal is not
    writable.

## Preserved failed result

The first live validation wrote a complete redacted profile but then returned a
permission error because an older administrator-owned
`C:\ProgramData\ZBookPerf\events.jsonl` could not be appended by the current
process. The main evidence was already durable. Treating an optional secondary
journal failure as failure of the completed observer was rejected.

The final implementation catches only that post-evidence logging boundary,
reports the journal exception type, returns the completed profile, and exits
successfully. It does not hide failures in path collection, endpoint validation,
network probing, or primary evidence writing.

## Final lab validation

Target and controlled conditions:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro 10.0.26200
- BIOS T76 01.24.02
- Intel Core i5-1145G7, 4 cores / 8 logical processors
- AC online; Battery Saver off; Balanced power scheme
- Local SATA SSD reported healthy; declared path on NTFS
- Declared storage locality: known OneDrive synchronization root
- Declared endpoint: GitHub HTTPS, identity redacted in raw evidence
- No directory enumeration, file read, application payload, or Windows mutation

Final observation:

- PowerShell parser: 0 errors.
- Focused EXP-047 Pester 5.6.1 suite: 70 passed, 0 failed.
- Path inventory calibration: 5 iterations after one warmup.
- Path inventory median: 1.075 ms.
- Path inventory p95: 5.052 ms.
- Path state: fixed NTFS, ready and present; no reparse, offline,
  recall-on-data-access, pinned, or unpinned flag on the declared root.
- Endpoint probes: 5 of 5 ready.
- Endpoint median: 9.695 ms.
- Endpoint p95: 37.518 ms.
- Endpoint timeout: 1,500 ms per probe.
- Raw repository path present: no.
- Raw host present: no.
- Final condition signature:
  `336270e8c4e9f8b822512710aad0b57eca9b98c982296604821a8a8a168ec2ba`.
- The earlier and final live runs produced the same signature under unchanged
  structural conditions despite different duration measurements.
- Optional event-journal update: unavailable due to existing file permissions;
  primary profile preserved and returned successfully.

These figures describe one connectivity and metadata baseline. A successful
TCP connection is not a throughput or application-readiness claim.

## Decision and next layer

Accept the PowerShell dependency profiler as an Experimental observation
capability. The engineering decision rule passed. Performance decision:
baseline only, no optimization claim.

Next cycle: Layer 1 - physical and thermal health. Use the dependency condition
signature beside later workload runs so storage/network changes are not
mistaken for thermal or software effects.

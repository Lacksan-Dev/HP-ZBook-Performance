# EXP-001 layer 4 - driver and OEM ownership profile

- Cycle trigger: 2026-07-31T09:41:46Z
- Final passive capture: 2026-07-31T09:58:57Z to
  2026-07-31T09:59:16Z
- Layer: 4 - platform drivers and OEM components
- Outcome: implemented
- Evidence state: observation-only baseline; no driver package, service,
  device, OEM component, registry value, policy, task, power setting, or
  Windows setting changed
- Implementation commit: `5d2ee8d8fc1d138f8793fbb8d9b3fbc9362b15de`
- Private raw evidence identifier:
  `20260731-095916-618-0fdee381-driver-oem-ownership-profile.json`

## Customer-visible interval and engineering responsibility

Layer 4 owns the supported software boundary between Windows Plug and Play,
vendor driver packages, device services, and OEM management components. A slow
launch, dock transition, file transfer, or visible interaction can involve one
of these components, but an installed package list cannot measure its runtime
cost.

The selected interval begins before two bounded local CIM queries and ends
after exact Service Control Manager lookups, identifier redaction, and package
aggregation finish. Microsoft owns the inbox Plug and Play providers and
Service Controller contract. HP, Intel, Microsoft, Realtek, Synaptics, and
other package vendors own their signed packages and support boundaries.
UX-ROM owns provider detection, query bounds, joins, redaction, observer-cost
measurement, structured evidence, and conservative interpretation.

Inputs are documented `Win32_PnPSignedDriver` package fields,
`Win32_PnPEntity` health and service fields, and exact `Get-Service` lookups.
Outputs are package provider, INF name, version, date, device class, signature
state, PnP error code, PnP status, declared driver-service name, service state,
and start type. Raw device and hardware identifiers become capture-local
salted SHA-256 keys. The salt is discarded. Device names, descriptions,
locations, paths, serials, command lines, and customer content are excluded.

Provider or service lookup failure becomes explicit unavailable evidence. A
device set above the configured limit fails safely rather than being silently
truncated. The capability has no driver, device, service, or package write
path, so rollback and reboot-persistence testing do not apply.

## Verified primary sources

Sources retrieved 2026-07-31:

- Microsoft Learn,
  [Win32_PnPSignedDriver](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/whqlprov/win32-pnpsigneddriver):
  documents the signed-package identity, provider, version, date, INF,
  device-class, signature, and signer fields used by the inventory.
- Microsoft Learn,
  [Win32_PnPEntity](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-pnpentity):
  documents Plug and Play status, service ownership, PnP class, and
  `ConfigManagerErrorCode`; zero is the documented working-state code.
- Microsoft Learn,
  [Get-Service](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-service?view=powershell-5.1):
  documents exact service-name lookup and that device-driver services can be
  returned through the Service Controller interface.
- Microsoft Learn,
  [ServiceController.StartType](https://learn.microsoft.com/en-us/dotnet/api/system.serviceprocess.servicecontroller.starttype?view=netframework-4.8.1):
  documents the read-only start-type property recorded for a matched service.
- Microsoft Learn,
  [INF AddService directive](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/inf-addservice-directive):
  documents boot, system, automatic, and demand start types. UX-ROM does not
  classify a demand-start or currently stopped driver as a fault.
- HP,
  [HP Image Assistant](https://support.hp.com/us-en/document/ish_7636709-7636753-16):
  documents HP's model-and-OS-specific driver and BIOS recommendation path.
  This inventory does not replace HPIA or infer update availability.
- HP,
  [HP Support Assistant](https://support.hp.com/us-en/help/hp-support-assistant):
  documents HP's supported update ownership. UX-ROM neither disables HP
  update support nor installs a package.
- Microsoft Learn,
  [Stopwatch](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.stopwatch?view=netframework-4.8.1):
  documents the elapsed-time source used for observer qualification.

No community registry value, proprietary-binary modification, direct vendor
download, driver install, service change, or performance claim is used.

## Candidate scoring and selection

Scores use a 0-5 scale for verified evidence, expected relevance,
reversibility, exact-system support, measurability, and engineering leverage.

| Candidate | Evidence | Relevance | Reversible | Support | Measurable | Leverage | Total | Decision |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Redacted PnP/package/service ownership profiler | 5 | 5 | 5 | 5 | 5 | 5 | 30 | Selected |
| Join every `Win32_SystemDriver` instance | 4 | 4 | 5 | 5 | 2 | 3 | 23 | Rejected; exploratory query took about 42.2 seconds and added no needed ownership field |
| Recommend updates from driver date alone | 2 | 4 | 5 | 2 | 1 | 2 | 16 | Rejected; date does not establish compatibility or current support |
| Run HPIA and install packages unattended | 4 | 5 | 1 | 2 | 3 | 3 | 18 | Rejected; exact package, recovery, and Tier 2 gates were absent |
| Capture WPR DPC/ISR trace in this run | 5 | 5 | 5 | 5 | 4 | 4 | 28 | Deferred to Layer 5, which owns runtime interrupt and DPC behavior |

## Pre-registered experiment design

Hypothesis: supported read-only CIM and Service Controller interfaces can give
UX-ROM a bounded, redacted map of installed driver-package ownership, PnP
health, and linked service state, making later driver-specific traces and
supported package decisions safer without changing a driver.

Controlled variable: instrumentation implementation only. Driver packages,
devices, services, Windows, and workload state remain unchanged.

Benchmark:

1. verify every required property on both CIM providers;
2. query only the declared fields with a 20-second operation timeout;
3. refuse more than 512 signed-driver records in the default run;
4. join raw device IDs only in memory, then replace them with capture-local
   salted SHA-256 keys;
5. perform exact service-name reads without enumerating the full system-driver
   provider;
6. warm the complete observer once and time three measured inventories;
7. retain the final measured snapshot instead of issuing another inventory;
8. save unique structured evidence; and
9. make no update recommendation or performance decision from static state.

Engineering decision rule:

1. the PowerShell parser reports zero errors;
2. focused and full required Pester suites pass;
3. all required provider properties exist;
4. observer p95 is below 15 seconds;
5. the record count stays within the declared bound;
6. evidence contains no raw device ID, hardware ID, device name, location,
   path, serial, command line, or customer content;
7. source and tests contain no reachable driver, package, service, device, or
   registry mutation command; and
8. the result makes no performance-gain or package-update claim.

Risks are slow WMI providers, installed-but-not-present package records,
unavailable service lookups, and false conclusions from driver dates or
start types. Timeouts, record bounds, explicit unavailable states, observer
calibration, and a baseline-only decision bound those risks.

## Engineering result

`ZBookPerf.ps1` now exposes `-Action DriverProfile`, the equivalent
`-DriverProfile` switch, three-or-more calibration iterations, a configurable
64-to-2048 device bound, Layer 4 workflow routing, and single
full-diagnostics integration. UX-ROM version is `2026.07.31.2`.

The capability:

1. checks the exact provider schema before collection;
2. projects only documented package and PnP fields;
3. joins package, device-health, and driver-service ownership;
4. performs exact service lookups instead of the rejected full
   `Win32_SystemDriver` scan;
5. hashes each raw device identity with a discarded capture-local salt;
6. groups package, provider, and device-class counts;
7. warms and calibrates the complete observer;
8. fails instead of truncating an oversized inventory;
9. writes unique structured JSON while preserving primary evidence if the
   optional event journal fails; and
10. explicitly states that static inventory does not measure driver execution
    cost or establish an update need.

## Documented facts

- The two providers expose the required package, signature, PnP health, class,
  and service fields on this Windows build.
- `Get-Service` can return driver services through the documented Service
  Controller interface.
- Driver start type describes loading behavior; demand start is not itself a
  malfunction.
- HP's supported update tools make recommendations for the detected model and
  operating system. UX-ROM's inventory is not that recommendation service.

## Lab measurements

Controlled target and conditions:

- HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Windows 11 Pro build 26200
- BIOS T76 01.24.02
- Intel Core i5-1145G7, 4 cores / 8 logical processors
- battery power during the final capture; Balanced power scheme
- thermal-zone data unavailable in the general environment provider
- no package install, removal, export, service change, device change,
  elevation request, reboot, or Windows mutation

Final observation:

- PowerShell parser: 0 errors.
- Focused Pester 5.7.1 suite: 99 passed, 0 failed.
- Full repository-required EXP-001 Pester suite: 107 passed, 0 failed.
- Signed-driver provider records: 250, within the default 512-record bound.
- Grouped package identities: 126.
- Provider labels: 17, including one blank provider field preserved as source
  data rather than guessed.
- PnP records with nonzero `ConfigManagerErrorCode`: 0.
- Records whose provider reported `IsSigned` false: 17. This does not identify
  a package as unsafe or unsupported by itself.
- Unique declared driver-service names: 90; 89 exact lookups succeeded and one
  was unavailable. Across device records, 143 linked to a readable service
  state and 106 declared no service name.
- Observer calibration: 3 iterations; 8205.287 ms median, 8920.123 ms p95,
  7897.265 ms minimum, and 8920.123 ms maximum.
- Raw device-ID pattern found in saved JSON: false.
- Device-name, friendly-name, interface-description, location, hardware-ID,
  or serial-number property found in saved JSON: false.
- Decision: `BaselineOnlyNoPerformanceClaim`.

The earlier exploratory full `Win32_SystemDriver` query took about 42.2
seconds on this system. It was rejected and removed from the design. The
selected exact service lookup added the service state needed for ownership
mapping without retaining that provider-wide cost.

The normal baseline security suite emitted expected non-elevated BitLocker
access diagnostics while all tests passed. The Layer 4 profiler did not query
BitLocker or request elevation.

## Hypotheses

- A later Layer 5 trace may connect one of these package/service owners to a
  measured DPC, ISR, storage, network, or graphics delay.
- A later controlled package comparison may show a meaningful change only if
  HP or the component vendor supports both exact package states for this model
  and build.

Neither hypothesis was tested in this run.

## Unresolved questions

- Which exact driver owns a repeatable customer-visible latency interval under
  an ETW trace?
- Do any of the 17 false `IsSigned` records represent an expected inbox or
  virtual-device state, stale package metadata, or a package needing separate
  signature verification?
- Why was one declared service name unavailable to the exact Service
  Controller lookup?
- Which HP Image Assistant recommendations, if any, apply to this exact model,
  build, and current package set?

The redacted inventory alone cannot answer these questions.

## Decision and next layer

Accept the observation-only driver/OEM ownership profiler as an Experimental
Layer 4 capability, subject to the GitHub merge gates.

No user-visible performance improvement was measured, so this run does not
qualify for immediate email or website publication. Layer 4 is the first
unpublished completion after the last four-layer digest; three more completed
layers are required for the next routine digest.

Next cycle: Layer 5 - kernel, scheduler, memory, storage, interrupts, and
DPC/ISR behavior. Use the Layer 4 ownership map to keep any runtime trace
bounded to a declared user-visible interval and avoid guessing from static
driver metadata.

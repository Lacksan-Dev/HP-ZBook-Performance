# EXP-001 progress report: capacity is not a bottleneck diagnosis

- Date: 2026-07-27
- Cycle layer: 2, hardware resources and bottlenecks
- Evidence state: inconclusive
- Live Windows changes: none
- Performance claim: none
- Next layer: 3, BIOS, UEFI, embedded-controller, and firmware interactions

## What was investigated

The lab recorded the ZBook's CPU, memory topology, storage capacity, and ten
seconds of inbox Windows CPU/memory/disk counters. The question was whether that
screening evidence could identify a hardware bottleneck or justify an upgrade.

It cannot. Capacity inventory is necessary context, but bottlenecks are
workload- and time-dependent. The short block ran while the engineering
automation was active and without the project's formal idle, thermal, reset, or
instrumentation-overhead controls.

## Exact findings

- Intel Core i5-1145G7: 4 cores and 8 logical processors.
- 32 GB memory: two matching Samsung 16 GB DDR4-3200 SODIMMs, each reported at
  3200 MT/s under separate controller paths.
- System SSD: 237.435 GiB Windows volume with 62.221 GiB free (26.206%).
- `Get-PhysicalDisk` reported `Healthy` and `OK`; the detailed storage
  reliability query returned access denied.
- Ten one-second samples had descriptive medians of 8.834% total processor
  time, 23,586 MiB available memory, 18.643% committed bytes, 0.365% disk time,
  zero disk queue, and 121,489 disk bytes per second.

Those ten samples are preserved as a convenience block, not as a formal idle
baseline or proof of performance.

## Supported limits and safety

Intel documents two memory channels, DDR4-3200, and a 64 GB processor limit for
the i5-1145G7. HP says the exact upgrade ceiling must be verified in BIOS and
the model maintenance guide. A firmware-reported 32 GB array maximum differs
from the processor ceiling, while HP's compatible 32 GB module listing does not
establish the platform's total maximum. The project therefore does not use the
WMI value to recommend or reject an upgrade.

No memory, SSD, page-file, firmware, driver, service, task, policy, registry,
power, security, update, or management setting was changed. No storage write
test or HP diagnostic ran.

## Evidence ledger

### Documented facts

- Windows exposes installed-memory and OS-visible-memory inventory separately.
- Windows performance counters support explicit intervals and sample counts.
- Supported storage reliability fields can include temperature, errors, wear,
  and time in use when the storage stack and access permit.
- HP requires model-specific BIOS/guide verification before a memory upgrade.

### Lab measurements

One static inventory and one unqualified ten-second counter block were captured.
No startup run, customer workflow, repeated block, instrumentation-overhead
test, or hardware diagnostic was performed.

### Hypotheses

The matching modules may be operating in dual-channel mode, and workload traces
may expose pressure or latency that this short total-counter block cannot see.
Neither hypothesis is verified.

### Unresolved questions

- What exact memory ceiling does BIOS/HP documentation give for this SKU?
- Which supported surface verifies active channel/interleaving mode?
- What resource distributions appear in repeated, controlled workflows?
- Can detailed storage reliability be collected through a bounded supported
  elevation path?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Win32_PhysicalMemory](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-physicalmemory)
- [Microsoft: Get-Counter](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-counter)
- [Microsoft: Get-StorageReliabilityCounter](https://learn.microsoft.com/en-us/powershell/module/storage/get-storagereliabilitycounter)
- [HP: Storage and memory verification](https://support.hp.com/gb-en/document/ish_9756213-9756262-16)
- [HP: Upgrading memory](https://support.hp.com/gb-en/document/ish_4480537-4480618-16)
- [HP: 32 GB DDR4-3200 memory data sheet](https://h20195.www2.hp.com/v2/getpdf.aspx/4AA8-0366ENW.pdf)
- [Intel: 11th-generation processor brief](https://download.intel.com/newsroom/2021/client-computing/tiger-lake-u-h-processor-brief.pdf)

# EXP-001 layer 2 evidence: capacity is not a bottleneck diagnosis

- Layer: 2, hardware resources and bottlenecks
- Investigation date: 2026-07-27
- Source retrieval date: 2026-07-27
- Target: validated HP ZBook Firefly 14 inch G8 lab computer
- Outcome: **inconclusive**
- Live Windows changes: none
- Performance claim: none
- Raw observation:
  [layer-02-hardware-resources-2026-07-27.json](layer-02-hardware-resources-2026-07-27.json)

## Evidence question

Can inbox Windows inventory plus a short CPU, memory, and storage counter block
identify a hardware resource bottleneck or justify a memory/storage upgrade on
the current ZBook?

## Decision

No. The inventory establishes the installed topology and the short counter block
proves that the selected inbox counters are available. It does not identify a
capacity, bandwidth, latency, or contention bottleneck.

Do not recommend a RAM or storage upgrade, alter the page file, run a write-heavy
storage test, or infer active dual-channel mode from two populated controller
paths. The layer is preserved as inconclusive and advances to layer 3.

## Documented facts

- Microsoft documents `Win32_PhysicalMemory` as representing physical memory
  devices available to Windows; it exposes capacity, configured clock speed,
  device locator, width, manufacturer, and part number.
- Microsoft says `Win32_OperatingSystem.TotalVisibleMemorySize` is the physical
  memory visible to the operating system and does not necessarily equal the
  system's true physical-memory total.
- Microsoft documents `Get-Counter` as reading Windows performance-monitoring
  instrumentation and allows an explicit sample interval and maximum sample
  count.
- Microsoft documents `Get-StorageReliabilityCounter` as the interface for
  supported device temperature, error, wear, and time-in-use fields. Availability
  depends on the storage stack and access.
- Intel's 11th-generation mobile processor brief lists the i5-1145G7 with two
  memory channels, DDR4-3200 support, and a processor maximum of 64 GB. That is a
  processor limit, not proof of the HP platform or exact SKU limit.
- HP tells customers to verify the exact memory configuration and additional
  capacity in BIOS and the model maintenance guide before upgrading. HP also
  publishes a 32 GB DDR4-3200 SODIMM accessory as compatible with the ZBook
  Firefly 14 G8, but that compatibility listing alone does not establish a
  two-module maximum for this exact SKU.
- HP treats its UEFI storage and memory checks as explicit diagnostics. HP warns
  that an SSD extensive test includes writes that can shorten SSD life.

## Lab measurements

The observation was read-only and non-elevated.

### Static inventory

- Processor: Intel Core i5-1145G7, 4 cores and 8 logical processors.
- Windows reported 32 GB installed as two matching Samsung 16 GB SODIMMs.
  Both reported 3200 MT/s configured speed and appear under separate controller
  paths.
- This topology is consistent with a balanced two-module configuration, but the
  observation does not directly prove that active dual-channel interleaving is
  enabled.
- `Win32_PhysicalMemoryArray` reported two devices and a 32 GB maximum. That
  firmware/WMI value differs from the Intel processor ceiling, while HP's
  compatible 32 GB module listing does not establish the platform's total
  maximum. The WMI value is therefore not used as an upgrade ceiling.
- The system SSD reported `Healthy`/`OK` through `Get-PhysicalDisk`. The system
  volume was 237.435 GiB with 62.221 GiB free (26.206%).
- Storage reliability counters returned access denied. No wear, temperature,
  error, or power-on-hour conclusion was made.
- Windows reported the disk bus as SATA and another inventory path reported an
  IDE interface. These storage-stack labels are not used to assert the drive's
  physical link type.

### Ten-second convenience counter block

Ten one-second samples were captured while the engineering automation was
active. There was no formal idle settling, thermal readiness gate, workload
reset, or instrumentation-overhead qualification.

| Counter | Minimum | Median | Maximum |
| --- | ---: | ---: | ---: |
| Total processor time | 0% | 8.834% | 14.343% |
| Available memory | 23,553 MiB | 23,586 MiB | 23,597 MiB |
| Committed bytes in use | 18.594% | 18.643% | 18.771% |
| Physical-disk time | 0% | 0.365% | 1.982% |
| Current disk queue | 0 | 0 | 0 |
| Disk bytes per second | 0 | 121,489 | 683,293 |

These values describe only the preserved convenience block. They are not an
idle baseline, repeated raw runs, a customer workflow, or evidence that a
resource is or is not a bottleneck.

## Hypotheses

- Repeated workflow traces may show short CPU, memory-pressure, storage-latency,
  or queue-depth events that a ten-second total-counter block cannot reveal.
- The matching memory modules may be operating in dual-channel mode, but a
  supported direct indicator or controlled bandwidth experiment is required.
- Storage capacity or locality may affect some workflows even though this short
  block showed no sustained queue.

## Compatibility limits and risks

- Inventory applies only to the recorded ZBook, Windows build, BIOS, memory
  modules, firmware, storage stack, and foreground conditions.
- Performance-counter names can be localized, and counter collection has
  unqualified overhead.
- A storage-stack `Healthy` value is not a substitute for HP diagnostics or
  vendor reliability fields.
- Memory replacement requires model-specific compatibility, electrostatic and
  service precautions, warranty review, original-module preservation, and a
  rollback/diagnostic plan.
- No HP diagnostic, memory test, storage benchmark, firmware test, restart, or
  hardware change ran in this iteration.

## Unresolved questions

1. What maximum memory does BIOS and the exact HP maintenance guide report for
   SKU `4P803UT#ABA`?
2. Which supported surface can verify active memory-channel/interleaving mode?
3. What CPU, memory, storage-latency, and queue distributions occur during each
   defined customer workflow after the required readiness/reset protocol?
4. What overhead does the proposed counter/ETW instrumentation add?
5. Can storage reliability fields be collected through a bounded supported
   elevation path without changing the system?
6. Which controller/interface path explains the differing Windows bus labels?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Win32_PhysicalMemory](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-physicalmemory)
- [Microsoft: Win32_OperatingSystem](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem)
- [Microsoft: Get-Counter](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-counter)
- [Microsoft: Get-StorageReliabilityCounter](https://learn.microsoft.com/en-us/powershell/module/storage/get-storagereliabilitycounter)
- [HP: Storage and memory verification](https://support.hp.com/gb-en/document/ish_9756213-9756262-16)
- [HP: Upgrading memory](https://support.hp.com/gb-en/document/ish_4480537-4480618-16)
- [HP: 32 GB DDR4-3200 memory data sheet](https://h20195.www2.hp.com/v2/getpdf.aspx/4AA8-0366ENW.pdf)
- [HP: ZBook Firefly 14 G8 support](https://support.hp.com/us-en/product/setup-user-guides/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/2100000206)
- [HP: Hardware diagnostics](https://support.hp.com/us-en/document/ish_2854458-2733239-16)
- [Intel: 11th-generation processor brief](https://download.intel.com/newsroom/2021/client-computing/tiger-lake-u-h-processor-brief.pdf)

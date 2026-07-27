# Layer 5: system counters are not driver attribution

- Date: 2026-07-27
- Layer: Windows kernel, scheduler, memory, storage, interrupts, and DPC/ISR
  behavior
- Evidence state: **inconclusive**
- Live status: measured read-only counters; no setting was applied
- Performance claim: none

## What was investigated

The lab recorded three short blocks of five one-second Windows performance
counter samples. The counters covered total processor, DPC and interrupt time,
interrupt and context-switch rate, processor queue length, memory page reads,
and physical-disk queue length.

The goal was to test whether inbox counters alone could identify a supported
Layer 5 optimization. They cannot. Their values are system-wide; they do not
name a driver, device, module, function, stack, or customer-visible delay.

The median DPC-time percentages for the three blocks were 0, 0, and 0.1926.
Interrupt-time medians were all 0. Interrupt-rate medians varied from 418.2872
to 4135.1839 per second, and context-switch medians varied from 468.7190 to
7336.9694 per second. These are preserved screening measurements, not a
performance baseline or a statement that any value is good or bad.

## Documented basis

Microsoft documents that the WPR General profile records DPC, interrupt,
context-switch, disk, memory, scheduling, and related kernel events. Microsoft
also documents WPA views that attribute DPC/ISR duration by module and function
and recommends reviewing activity in the interval of interest with stacks.

`wpr.exe` is present on the lab computer, but WPA and xperf were not detected.
No trace was started and no analysis toolkit was installed during this
unattended run.

## Supported system and limits

The observation applies to the HP ZBook Firefly 14 inch G8 SKU recorded in
EXP-001, running Windows 11 Pro build 26200 and BIOS T76 01.24.02, on
AC-connected Balanced power.

It was collected while automation was active, without a formal idle reset,
thermal-readiness gate, declared workflow, startup/readiness endpoint, or
instrumentation-overhead qualification. It cannot support a change or a
performance-gain claim.

## Change and rollback status

No driver, timer, HPET, scheduler, memory, storage, interrupt-affinity, page-
file, boot, registry, policy, service, task, power, security, update, recovery,
management, firmware, or HP OEM setting was changed. Rollback is not applicable.

## Next evidence

Layer 6 examines supported power-management and performance-policy surfaces.
The later Layer 5 follow-up needs a compatible Windows Performance Toolkit,
overhead qualification, and repeated workflow-scoped traces with module,
function, and stack attribution.

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Get-Counter](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-counter)
- [Microsoft: WPR basic system diagnosis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-for-basic-system-diagnosis)
- [Microsoft: CPU Analysis](https://learn.microsoft.com/en-au/windows-hardware/test/wpt/cpu-analysis)
- [Microsoft: WPA graph list](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/list-of-wpa-graphs)
- [Microsoft: measuring DPC/ISR time](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/example-15--measuring-dpc-isr-time)

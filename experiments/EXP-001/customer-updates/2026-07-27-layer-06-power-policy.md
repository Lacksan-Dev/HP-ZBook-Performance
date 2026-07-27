# Layer 6: Best performance is already the AC request

- Date: 2026-07-27
- Layer: power management and performance policy
- Evidence state: **inconclusive**
- Live status: read-only configuration inventory; no setting was applied
- Performance claim: none

## What was investigated

The lab read the supported Windows power-plan, user-mode, processor-policy, and
sleep-state surfaces. Balanced is the active base plan. The Windows 11
user-configured AC mode is Best performance, while the battery mode is Best
power efficiency. Minimum/maximum processor policy is 5/100 percent on both
power sources.

These are configuration bounds, not workload results. Microsoft documents the
user-configured mode as a vote that thermal, firmware, battery, and other system
signals can override. The effective runtime mode was not traced.

## Shutdown and platform findings

The platform reports Modern Standby S0 Low Power Idle with network
connectivity. S1-S3 are unavailable. Hibernation is disabled, which also makes
Fast Startup and Hybrid Sleep unavailable.

Fast Startup is a hybrid shutdown that preserves the kernel session in a
hibernation file. It is not a cold boot or Restart, so enabling it cannot be
claimed as a general boot improvement without separately defined and repeated
workflows.

Intel Dynamic Tuning was running automatically. Its configuration, the HP
firmware power policy, effective mode, temperature, fan state, and platform
power limits were not measured.

## Supported system and limits

The observation applies to the HP ZBook Firefly 14 inch G8 SKU recorded in
EXP-001, running Windows 11 Pro build 26200 and BIOS T76 01.24.02.

No startup/readiness benchmark, thermal gate, energy measurement, effective-
mode trace, or instrumentation-overhead qualification ran. The evidence cannot
support a performance-gain claim or a power change.

## Change and rollback status

No custom/High performance plan, processor minimum, hidden processor setting,
energy-performance preference, Modern Standby state, hibernation/Fast Startup,
Intel DTT, HP firmware, service, driver, task, policy, registry, security,
update, recovery, or management setting changed. Rollback is not applicable.

## Next evidence

Layer 7 examines security and isolation overhead without reducing protection.
A future power experiment must compare one supported reversible mode at a time
under repeated AC or battery workflows with effective-mode, energy, thermal,
readiness, and rollback evidence.

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: powercfg](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options)
- [Microsoft: change Windows power mode](https://support.microsoft.com/en-us/windows/change-the-power-mode-for-your-windows-pc-c2aff038-22c9-f46d-5ca0-78696fdf2de8)
- [Microsoft: AC power-mode API](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfiguredacpowermode)
- [Microsoft: DC power-mode API](https://learn.microsoft.com/en-us/windows/win32/api/powrprof/nf-powrprof-powergetuserconfigureddcpowermode)
- [Microsoft: processor power-management options](https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/configure-processor-power-management-options)
- [Microsoft: system power states and Fast Startup](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)
- [Microsoft: Modern Standby connectivity](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-network-connectivity)
- [Intel: 11th Gen Core vPro platform features](https://software.intel.com/content/dam/www/public/us/en/documents/product-briefs/a1124383-11th-gen-core-vpro-desktop-processor.pdf)

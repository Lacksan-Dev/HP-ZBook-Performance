# EXP-001 hourly performance-layer cycle

- Date: 2026-07-26
- Evidence state: process initialized; no live Windows change
- Supported lab target: HP ZBook Firefly 14 inch G8 Mobile Workstation PC
- Current cycle position: layer 1, physical and thermal health
- Next publication trigger: the first committed layer investigation

## What changed

The EXP-001 hourly engineering automation now advances through a durable
twelve-layer Windows laptop performance cycle. Each hourly run handles at most
one evidence-backed improvement or one research, rejected, inconclusive, or
blocked result. The checked-in `hourly-layer-cycle.json` file prevents the
automation from silently favoring popular registry tweaks while ignoring
hardware, firmware, drivers, boot behavior, applications, or workload
conditions.

The cycle is:

1. physical and thermal health;
2. hardware resources and bottlenecks;
3. BIOS, UEFI, embedded-controller, and firmware interactions;
4. platform drivers and OEM components;
5. the Windows kernel, scheduler, memory, storage, interrupts, and DPC/ISR behavior;
6. power management and performance policy;
7. security and isolation overhead without reducing protection;
8. the boot path, services, tasks, background permissions, and startup applications;
9. Group Policy, MDM-aware policy, registry, and system configuration;
10. the Windows shell, GUI, capture, notifications, and perceived responsiveness;
11. application/runtime efficiency and workload profiles; and
12. workload data, storage locality, network dependencies, and reproducibility.

## Priority investigations

Driver work will focus on supported package versions, installation and
configuration, device power behavior, DPC/ISR evidence, and HP/vendor
interactions. It will not modify or rebuild proprietary driver binaries unless
source code, build instructions, redistribution rights, signing, hardware
support, and a verified recovery path are all available.

Boot investigations will measure separate firmware, kernel/session, sign-in,
shell-ready, delayed-background-work, and application-ready intervals.
Services, scheduled tasks, background permissions, and startup applications
remain enabled until documentation, dependency analysis, and boot-trace
evidence support a safe delayed, triggered, disabled, or removed state.

Group Policy and registry findings must distinguish a documented policy from a
registry implementation detail. Organization-managed policy remains out of
scope for alteration.

## Safety and rollback

Every proposed modification still requires:

- support detection;
- original-state capture;
- a read-only dry run;
- apply and verification functions;
- structured logging;
- idempotence;
- exact rollback and rollback verification; and
- reboot-persistence testing when applicable.

Hourly unattended runs may implement and test these mechanisms, but may not
change live Windows settings, stop services, alter tasks or startup entries,
install drivers, enable automatic sign-in, bypass UAC, reboot, or weaken
security, update, recovery, or management controls.

## Documented facts

- The repository workflow requires support detection, original-state capture,
  dry-run, apply, verification, structured logging, idempotence, rollback, and
  reboot-persistence testing where applicable.
- The EXP-001 protocol does not accept a performance conclusion without
  repeated raw runs, medians, controlled conditions, instrumentation-overhead
  qualification, and its decision rule.
- The automation configuration itself does not alter Windows.

## Lab measurements

No startup or responsiveness measurement was made for this process update.
There is no performance claim.

## Hypotheses

- Separating boot phases may identify foreground-readiness delays that a single
  total boot duration hides.
- Vendor-supported driver configuration and dependency-aware startup changes
  may improve responsiveness without removing required Windows functions.

These are hypotheses awaiting controlled evidence.

## Unresolved questions

- Which event and trace markers most reliably define shell-ready and
  application-ready states on this ZBook?
- What is the instrumentation overhead of the selected boot trace?
- Which startup components are actually on the critical path?
- Which driver versions and OEM components are supported for controlled
  comparison on the current BIOS and Windows build?

## Customer status

The cycle is initialized at layer 1. No service, task, startup application,
driver, policy, registry value, firmware setting, or Windows setting was
changed by this update.

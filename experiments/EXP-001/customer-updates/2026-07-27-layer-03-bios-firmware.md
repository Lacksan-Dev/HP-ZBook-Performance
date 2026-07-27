# EXP-001 progress report: firmware inventory is not a startup tweak

- Date: 2026-07-27
- Cycle layer: 3, BIOS, UEFI, embedded-controller, and firmware interactions
- Evidence state: inconclusive
- Live Windows or firmware changes: none
- Performance claim: none
- Next layer: 4, platform drivers and OEM components

## What was investigated

The lab used non-elevated Windows and HP inventory surfaces to ask whether the
ZBook's current BIOS, embedded-controller, or firmware configuration supports a
specific startup-performance change.

It does not. The observations identify the installed firmware components, but
there is no firmware-time measurement and the access-controlled HP setting
instances were not available to the unattended run.

## Exact findings

- HP ZBook Firefly 14 inch G8, SKU `4P803UT#ABA`, board `880D`.
- UEFI boot mode with a GPT boot/system disk.
- HP BIOS `T76 Ver. 01.24.02`, dated 2026-05-04, SMBIOS 3.3.
- Embedded-controller values 48/87 and board KBC `30.57.00`.
- Windows reports `HP T76 System Firmware` as `OK`, provider HP, version
  `1.24.2.0`, dated 2026-05-04.
- HP's Instrumented BIOS namespace and setting classes are present. Non-elevated
  instance reads returned access denied.
- The non-elevated Secure Boot query also returned access denied, so Secure Boot
  state remains unknown.

Version agreement across inventory paths is useful configuration evidence. It
is not proof that firmware is current or that it improves startup.

## Supported limits, dependencies, and rollback

HP documents supported interfaces for reading and changing platform-specific
BIOS settings, including allowed values, prerequisites, read-only state, and
physical-presence requirements. Those exact fields must be captured before a
setting can enter an experiment.

HP requires model-compatible BIOS packages, external power, and management
compatibility. Recovery support is model-dependent, and HP has published a
no-rollback T76-family firmware release for this ZBook family. Exact rollback
therefore cannot be assumed.

No Fast Boot, boot-order, Secure Boot, thermal, fan, power, firmware, driver,
service, task, policy, registry, security, update, recovery, or management
setting was changed.

## Evidence ledger

### Documented facts

Windows exposes BIOS inventory and supports OEM firmware packages through its
UEFI firmware-update platform. HP exposes model-specific BIOS settings through
its Instrumented BIOS provider and client-management tooling. Both require
exact platform and package support; neither promises a performance benefit.

### Lab measurements

One static, read-only inventory was captured. No startup run, firmware-time
split, trace, repeated run, control run, or instrumentation-overhead test was
performed.

### Hypotheses

Firmware time or a supported platform setting may affect startup, but that must
be tested with an accepted usable-state definition and repeated measurements.

### Unresolved questions

- What exact HP package and release notes cover installed T76 01.24.02?
- Which BIOS settings and prerequisites are exposed in an approved elevated
  inventory?
- Is Secure Boot enabled, and what recovery preparation would be required?
- What repeated firmware-time measurement can be captured without excessive
  observer overhead?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Win32_BIOS](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-bios)
- [Microsoft: Confirm-SecureBootUEFI](https://learn.microsoft.com/en-us/powershell/module/secureboot/confirm-securebootuefi?view=windowsserver2025-ps)
- [Microsoft: Windows UEFI firmware update platform](https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/windows-uefi-firmware-update-platform)
- [HP: BIOS and Device management](https://developers.hp.com/hp-client-management/doc/bios-and-device)
- [HP: Understanding HP BIOS settings](https://developers.hp.com/hp-client-management/doc/understanding-hp-bios-settings)
- [HP: Business notebook BIOS update guidance](https://support.hp.com/emea_africa-en/document/ish_4208192-2358829-16)
- [HP: Notebook BIOS recovery guidance](https://support.hp.com/us-en/document/ish_3932413-2337994-16)
- [HP: ZBook Firefly 14 G8 support](https://support.hp.com/us-en/product/setup-user-guides/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/2100000206)
- [HP: September 2021 BIOS release - no rollback](https://support.hp.com/gb-en/document/ish_4784771-4784815-16)
- [HP: March 2024 T76 BIOS refresh](https://support.hp.com/us-en/document/ish_10322031-10322082-16)

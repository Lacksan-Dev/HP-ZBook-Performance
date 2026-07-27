# EXP-001 progress report: signed does not mean optimized

- Date: 2026-07-27
- Cycle layer: 4, platform drivers and OEM components
- Evidence state: inconclusive
- Live Windows or driver changes: none
- Performance claim: none
- Next layer: 5, Windows kernel, scheduler, memory, storage, interrupts, and
  DPC/ISR behavior

## What was investigated

The lab recorded selected HP, Intel, Realtek, and Synaptics driver identities,
present-device health, current-user companion packages, and driver-related
service state. The question was whether that inventory identifies a supported
startup or responsiveness improvement.

It does not. Signed packages and clean Device Manager status are useful health
metadata, but they do not establish package currency, latency, startup cost,
dependencies, or relative performance.

## Exact findings

- All 17 selected graphics, Wi-Fi, Bluetooth, storage, Dynamic Tuning,
  Management Engine, Serial IO, Smart Sound, Thunderbolt, audio, camera, HP
  application/hotkey, fingerprint, and pointing-device entries reported signed
  status.
- No present device returned a non-OK status or nonzero Device Manager problem
  code.
- Current-user companion packages included HP System Information, Intel
  Graphics/Arc Software, Intel Optane Memory and Storage Management, HP Audio
  Control, and a Synaptics pointing-device app.
- Running automatic service surfaces included Intel Dynamic Tuning, HP Hotkey,
  HP support capabilities, HP Insights Analytics, HP LAN/WLAN switching, Intel
  graphics/management/storage, Realtek audio, and Thunderbolt support.
- HPIA, HP CMSL, and HP Performance Advisor commands were not detected. No tool
  was installed and no HP reference-image comparison ran.

The complete customer-safe inventory lists versions and INF package names. It
omits hardware and device-instance identifiers.

## Supported limits, dependencies, and rollback

HP Image Assistant is the supported HP comparison surface for target/reference
image recommendations. HP lists HPIA 5.3.6 for Windows 10 and 11, but the lab
did not verify an exact reference-image match for SKU `4P803UT#ABA` on Windows
build 26200.

Intel warns that a generic graphics driver can remove OEM customizations and can
cause instability or lost functionality. Driver date alone is not an ordering
rule.

A future package experiment needs exact HP/OS/hardware applicability,
dependencies, package export or vendor recovery media, signature validation,
application result, device/workflow verification, and post-reboot rollback
proof. A service experiment separately needs vendor purpose, dependencies,
triggers, default/support state, failure behavior, boot-trace evidence, and
exact restoration.

No driver, device, app, service, Windows Update component, HP support function,
security control, management control, registry value, or power setting changed.

## Evidence ledger

### Documented facts

Windows exposes signed-driver provider/version/INF metadata and Device Manager
problem codes. HPIA can compare an HP target image with a reference image.
Windows performance traces can attribute DPC/ISR duration by module and
function. None of those facts make a static package list a performance result.

### Lab measurements

One read-only inventory was captured on AC power with Balanced active. No
startup run, customer workflow, DPC/ISR trace, device-power trace, repeated run,
control run, or instrumentation-overhead test was performed.

### Hypotheses

A platform driver may contribute DPC/ISR or device-readiness delay, and a
companion service may do work near sign-in. Neither is verified.

### Unresolved questions

- Does HPIA have an exact reference image for this build?
- Which HP SoftPaq and dependency graph corresponds to each INF?
- Which modules contribute DPC/ISR duration during defined workflows?
- Which OEM services perform measurable work before usable state?
- Can an exact export/recovery and post-reboot rollback path be demonstrated?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Win32_PnPSignedDriver](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/whqlprov/win32-pnpsigneddriver)
- [Microsoft: installed driver inventory](https://learn.microsoft.com/en-us/windows-hardware/drivers/driversecurity/create-a-driver-inventory)
- [Microsoft: Device Manager problem codes](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/device-manager-problem-codes)
- [Microsoft: WPR basic system diagnosis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-for-basic-system-diagnosis)
- [Microsoft: WPA graphs](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/list-of-wpa-graphs)
- [HP: Image Assistant](https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html)
- [HP: ZBook Firefly 14 G8 drivers](https://support.hp.com/us-en/drivers/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/2100000206)
- [Intel: OEM graphics-driver warning](https://www.intel.com/content/www/us/en/support/articles/000005469/graphics.html)

# EXP-001 layer 4 evidence: signed does not mean optimized

- Layer: 4, platform drivers and OEM components
- Investigation date: 2026-07-27
- Source retrieval date: 2026-07-27
- Target: validated HP ZBook Firefly 14 inch G8 lab computer
- Outcome: **inconclusive**
- Live Windows or driver changes: none
- Performance claim: none
- Raw observation:
  [layer-04-drivers-oem-2026-07-27.json](layer-04-drivers-oem-2026-07-27.json)

## Evidence question

Can inbox signed-driver, present-device, companion-package, and service
inventory identify a supported platform-driver or HP OEM change that improves
startup or responsiveness on the exact ZBook?

## Decision

No. The inventory establishes package identity for selected platform devices,
reports no current Device Manager problem code, and maps several driver-related
companion packages and services. It does not establish update applicability,
package dependencies, startup cost, device-power behavior, or DPC/ISR latency.

Do not replace HP/OEM packages with generic drivers, remove a driver-store
package, rebuild proprietary binaries, or delay/stop a related service. The
layer is preserved as inconclusive and advances to layer 5.

## Documented facts

- Microsoft documents `Win32_PnPSignedDriver` as exposing provider, version,
  date, INF name, signer, and signed status. Signed status validates neither
  workload behavior nor relative performance.
- Microsoft documents PnP problem codes for device-node failures such as failed
  start, missing/reinstall-required driver, disabled device, and failed add.
  Absence of a problem code is not a latency test.
- Microsoft recommends inbox PnPUtil for driver-store inventory. Its structured
  XML/CSV formats should be used instead of parsing localized text. Package
  export is a separate operation needed before a controlled replacement.
- HP Image Assistant compares an HP target image with a reference image and can
  report driver, firmware, and software recommendations. HP lists HPIA 5.3.6,
  dated 2026-06-09, for Windows 10 and 11. HPIA also reports when only a generic
  OS reference is available, so product family alone does not establish an
  exact reference-image match.
- HP's model download page requires both operating system and version before it
  presents packages. A version date in Windows inventory is therefore not proof
  that an HP-supported replacement exists for Windows build 26200.
- Intel warns that installing a generic graphics driver can remove OEM
  customizations and can introduce instability or lost functionality. Generic
  replacement is not a neutral performance baseline.
- Windows Performance Recorder's general profile can record DPC and interrupt
  events, and Windows Performance Analyzer exposes DPC/ISR duration by module
  and function. A package list cannot attribute DPC/ISR cost.
- Microsoft says an ISR should do minimal work and queue lower-priority DPC work
  promptly. That design guidance is not evidence that any installed driver
  violates the rule.

## Lab measurements

The observation was read-only and non-elevated on Windows 11 Pro build 26200,
BIOS T76 01.24.02, while Windows reported AC-connected power and the Balanced
scheme. No workload or startup benchmark ran.

### Selected driver stack

All 17 selected entries reported `IsSigned = true` and signer `Microsoft Windows
Hardware Compatibility Publisher`.

| Component | Provider | Version | INF |
| --- | --- | --- | --- |
| Intel Iris Xe Graphics | Intel | 32.0.101.7085 | `oem116.inf` |
| Intel Wi-Fi 6 AX201 | Intel | 23.140.0.3 | `oem68.inf` |
| Intel Wireless Bluetooth | Intel | 23.140.0.5 | `oem49.inf` |
| Intel RST VMD Controller 9A0B | Intel | 18.7.6.1010 | `oem66.inf` |
| Intel Dynamic Tuning Manager | Intel | 8.7.10802.26924 | `oem60.inf` |
| Intel Management Engine Interface | Intel | 2540.8.7.0 | `oem15.inf` |
| Intel Serial IO I2C | Intel | 30.100.2129.8 | `oem71.inf` |
| Intel Smart Sound Technology BUS | Intel | 10.29.0.9947 | `oem5.inf` |
| Thunderbolt Controller 9A1B | Intel | 1.41.1423.0 | `oem57.inf` |
| Realtek High Definition Audio | Realtek | 6.0.9929.1 | `oem56.inf` |
| HP Universal Camera Driver | Realtek | 10.0.22000.20390 | `oem45.inf` |
| HP Application Driver | HP | 1.66.3710.0 | `oem42.inf` |
| HP Application Driver Component | HP | 1.83.4311.0 | `oem55.inf` |
| HP Wireless Button Driver | HP | 2.1.17.7 | `oem54.inf` |
| HP Hotkey Support keyboard package | HP | 8.10.52.464 | `oem107.inf` |
| Synaptics fingerprint sensor | Synaptics | 6.0.130.1110 | `oem63.inf` |
| Synaptics HID device | Synaptics | 19.6.1.26 | `oem93.inf` |

No present device returned a non-OK status or nonzero problem code in the
collection. That is a current device-node observation, not proof of performance
or package currency.

### Companion and service surfaces

The current user had HP System Information, Intel Graphics/Arc Software, Intel
Optane Memory and Storage Management, HP Audio Control, and a Synaptics
commercial pointing-device companion package.

The service inventory observed running automatic services for Intel Dynamic
Tuning, HP Hotkey, HP Support Assistant capabilities, HP audio/diagnostics/
network/system information, HP Insights Analytics, Intel graphics and
management, HP LAN/WLAN switching, Intel storage middleware, Realtek audio, and
Thunderbolt peer-to-peer support. These are current states, not documented
defaults or stop candidates. Dependency, trigger, boot-trace, workflow, and
failure evidence was not collected.

HPIA, HP Client Management Script Library, and HP Performance Advisor commands
were not detected. No tool was installed and no reference-image analysis ran.

## Hypotheses

- One or more platform drivers may contribute measurable DPC/ISR duration or
  device-readiness delay during a defined workflow, but an ETW trace with module
  and call-stack attribution is required.
- An HP reference-image comparison may identify applicable packages or
  dependencies, but a recommendation still would not prove a performance gain.
- Some companion service may start work near sign-in, but current `Auto`/running
  state does not establish boot criticality, duration, or safe delayed start.

## Compatibility, dependency, and rollback limits

- Inventory applies only to the recorded model, SKU, Windows build, BIOS, power
  observation, connected devices, and current-user package registration.
- Driver date is not a supported ordering rule. An older OEM package can carry
  platform customizations and dependencies absent from a generic package.
- A future driver experiment must capture provider, version, INF, signer,
  hardware IDs, associated files, service/filter bindings, package source,
  exact HP/OS applicability, dependency graph, current device state, driver-
  store export or vendor recovery package, installation result, and post-reboot
  verification.
- A service experiment must separately document its vendor purpose,
  dependencies, triggers, supported/default start state, failure behavior, boot
  trace, operational impact, original state, and exact restoration.
- No proprietary source, redistribution right, build instructions, signing
  authority, hardware validation matrix, or recovery proof was found. Rebuilding
  the detected proprietary drivers is outside the support boundary.
- No driver, device, companion package, service, Windows Update, HP support
  function, security, management, or power configuration was changed.

## Unresolved questions

1. Does HPIA 5.3.6 have an exact reference image for this SKU and Windows build,
   and which packages/dependencies would its analysis-only report identify?
2. Which HP SoftPaq, release notes, hardware IDs, and OS build ranges correspond
   to each selected installed INF?
3. Which modules contribute DPC/ISR duration during each defined workflow, and
   what is the trace overhead?
4. Which device-power transitions or readiness delays occur during startup,
   sign-in, dock, network, audio, camera, and resume workflows?
5. Which observed OEM services do measurable work before the declared usable
   state, and what documented triggers/dependencies prohibit or allow a narrower
   start mode?
6. Can a controlled package change provide exact export/recovery and post-reboot
   validation without losing OEM functionality?

## Primary sources

Retrieved 2026-07-27:

- [Microsoft: Win32_PnPSignedDriver](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/whqlprov/win32-pnpsigneddriver)
- [Microsoft: installed driver-package inventory](https://learn.microsoft.com/en-us/windows-hardware/drivers/driversecurity/create-a-driver-inventory)
- [Microsoft: PnPUtil syntax](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax)
- [Microsoft: Device Manager problem codes](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/device-manager-problem-codes)
- [Microsoft: WPR basic system diagnosis](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/recording-for-basic-system-diagnosis)
- [Microsoft: WPA graph list](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/list-of-wpa-graphs)
- [Microsoft: writing an ISR](https://learn.microsoft.com/en-us/windows-hardware/drivers/kernel/writing-an-isr)
- [HP: Image Assistant](https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html)
- [HP: ZBook Firefly 14 G8 drivers](https://support.hp.com/us-en/drivers/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/2100000206)
- [HP: ZBook Firefly 14 G8 support](https://support.hp.com/us-en/product/setup-user-guides/hp-zbook-firefly-14-inch-g8-mobile-workstation-pc/2100000206)
- [Intel: OEM graphics-driver warning](https://www.intel.com/content/www/us/en/support/articles/000005469/graphics.html)

# EXP-120: HP Hotkey UWP delayed-start research gate

Status: Experimental
Evidence: needs-evidence

## Candidate

Change exactly one verified `HotKeyServiceUWP` service from Automatic to Automatic (Delayed Start) while preserving its current running state. No service stop, package removal, driver change, firmware change, or device mutation belongs to this experiment.

## Security gate

HP Security Bulletin HPSBHF04102 Rev. 2, released 2026-03-13 and updated 2026-04-16, documents CVE-2026-4000 in HP Hotkey UWP Service and directs affected systems to remediated HP Hotkey Support SoftPaqs. The bulletin lists minimum version `8.10.50.393` for the affected business-notebook rows surfaced in the current bulletin response and uses SoftPaq SP168736 for those rows.

Engineering must therefore refuse treatment unless all of the following are captured and verified on the physical machine:

- exact HP model and Windows 11 build
- exact `HotKeyServiceUWP` service/display identity
- exact `HotKeyServiceUWP.exe` path, SHA-256, file version, product identity, valid HP publisher signature, and certificate thumbprint
- installed HP Hotkey Support package/product version and SoftPaq identity where locally discoverable
- the detected model appears in the current HP bulletin resolution table with a published minimum version, or separate authoritative HP evidence establishes its applicable security floor
- installed version is greater than or equal to that model's published minimum version

If the target model has no resolvable row in the current bulletin, security eligibility remains `needs-evidence` and mutation is refused. The provider must never infer that one model's minimum version applies to an unlisted model.

## Reversible engineering contract

After the security gate is physically resolvable, the implementation must provide Check, Capture, DryRun, Apply, Verify, VerifyReboot, and Rollback; structured JSONL logging; idempotence; terminating failure retention; `ShouldProcess` and `-WhatIf`; service, executable, package, security-version, dependency, device, management, and protected-scope drift refusal; exact capture of startup mode, `DelayedAutoStart` existence/type/raw value, running state, service account, dependencies/dependents, triggers, recovery configuration, machine/user/boot identity, BIOS, keyboard/HID inventory, and protected applications; and exact rollback of the captured startup/delayed-start/running state.

Production application may change only startup timing. Defender, Firewall, BitLocker, Credential Guard/VBS, Windows Update, recovery, enterprise management, keyboard/HID/ACPI components, PnP devices, INF/DriverStore content, firmware, Omnissa, Windows App, Remote Desktop, and Tailscale remain preserved.

## Physical validation still required

Retain `needs-evidence` for the exact target-model security floor, local package/SoftPaq identity, five matched baseline and five treatment cold boots, first-120-second CPU/disk attribution, service-start timing, the applicable brightness/volume/microphone/backlight/programmable-key matrix, protected-application readiness, reboot persistence, and executed exact rollback. Preserve favorable, adverse, failed, rejected, and inconclusive evidence. Stable remains outside this experiment.

## Sources reviewed 2026-08-04

- HP Security Bulletin HPSBHF04102 Rev. 2: https://support.hp.com/us-en/document/ish_14484164-14484183-16/hpsbhf04102
- CVE-2026-4000, severity High, CVSS 8.4, as listed by the same HP bulletin.

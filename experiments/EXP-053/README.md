# EXP-053: Logitech G Hub Controller Integration

Status: Experimental  
Stage: Validation  
Evidence: needs-evidence

## Purpose
Integrate one bounded Logitech G Hub current-user tray or background Run registration into the Lacksan Controller transaction model.

## Candidate
The `LogitechGHubDemandLaunch` profile removes exactly one eligible value under `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` whose value name identifies Logitech G Hub, whose resolved executable is `lghub.exe` or `lghub_agent.exe` under a Logitech G HUB application directory, and whose command contains an explicit background, minimized, startup, tray, or silent argument.

The provider refuses updater, repair, uninstall, firmware, pairing, driver, device-service, protected, unsigned, ambiguous, enterprise-managed, zero-candidate, and multiple-candidate states.

## Engineering controls
The provider supplies:

- HP Windows 11 support detection.
- Domain, MDM, PolicyManager, and Configuration Manager refusal.
- Exact registry path, value name, registry type, and unexpanded command capture.
- Resolved executable path, SHA-256, file version, Authenticode status, publisher subject, machine identity, and user SID capture.
- Dry run, `-WhatIf`, and `ShouldProcess` behavior.
- One-value application and immediate verification.
- Structured JSONL logging and terminating failure records.
- Idempotent repeated application.
- Reboot-persistence verification.
- Captured-state and executable-identity drift refusal.
- Rollback overwrite refusal.
- Publisher and executable-hash verification before rollback.
- Exact restoration of the original registry type and unexpanded command.
- Rollback equality verification.

## Preserved components
The candidate changes one current-user Run value only. Preserve the G Hub installation, packages, files, services, updater service, scheduled tasks, StartupTask registrations, profiles, macros, lighting state, onboard device memory, Logitech HID, receiver, Bluetooth, keyboard, mouse, headset, camera, audio and device-critical drivers, Windows security, Windows Update, recovery, credentials, accessibility, enterprise management, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Pester and zero-mutation integration
Run the Pester contract suite and require syntax, lifecycle, identity, support, management-refusal, state-capture, logging, idempotence, persistence, mutation-scope, and rollback tests to pass.

On a Windows 11 test system, execute `Check` and `DryRun` with a temporary JSONL log and state path. Confirm no registry value, service, task, package, file, device, driver, security control, update component, recovery setting, management state, or protected application changes. Test absent, unsigned, updater-only, protected-name, invalid-path, zero-candidate, and multiple-candidate refusal cases without mutation.

## Physical validation
Use one HP Windows 11 target with one eligible G Hub registration. Record Windows build, HP model, BIOS, G Hub version, executable hash and publisher, Logitech driver versions, power source, power mode, thermal state, network state, connected peripherals, and instrumentation version.

Complete at least five matched baseline and five treatment sign-in trials. Retain raw runs and report medians and dispersion for sign-in to usable desktop, first-120-second CPU and disk activity, G Hub process activity and working set, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

Verify manual G Hub launch, device detection, existing profiles, onboard settings, macros, lighting, audio features where present, updater behavior, basic device operation, Device Manager health, immediate removal, reboot persistence, exact rollback, restored sign-in launch behavior, and instrumentation overhead.

Preserve favorable, adverse, failed, and inconclusive evidence. Missing physical execution and measurements remain `needs-evidence`. Never assign Stable automatically.

# EXP-068: HP Audio Analytics Manual demand-start

## Status
Experimental. Physical measurements remain `needs-evidence`. Stable remains unassigned.

## Candidate
Change only the exact `HPAudioAnalytics` service from Automatic or Automatic Delayed Start to Manual. Preserve its current running state during application.

## Required controls
The provider requires HP Windows 11, elevation, exact service and executable identity, a valid HP publisher signature, no enterprise service-policy ownership, no dependencies or dependents, and no active protected HP hotkey or audio-management process. It captures the original service configuration and executable identity before mutation, supports dry run and WhatIf, verifies immediately and after reboot, emits JSONL logs, behaves idempotently, terminates on failure, refuses drift, and restores startup mode, delayed-start state, and running state exactly.

## Preserved scope
Preserve HP Hotkey Support, audio devices, APOs, drivers, packages, files, tasks, Windows security, Windows Update, recovery, enterprise management, credentials, accessibility, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale.

## Zero-mutation integration check
Run Check, DryRun, and Apply with WhatIf on an elevated HP Windows 11 test machine. Confirm that the service startup mode and running state remain unchanged, support output includes identity and management fields, and the log contains valid one-line JSON records.

## Physical validation
Record device model, Windows build, BIOS, service executable version and SHA-256, power source, thermal state, and benchmark conditions. Complete five matched baseline and five treatment sign-in trials. Measure usable-desktop latency plus CPU and disk activity during the first 120 seconds. Verify speakers, microphone, headset, volume and microphone-mute hotkeys, HP hotkey UI, protected remote-access readiness, immediate verification, reboot persistence, exact rollback, and rollback persistence. Report medians only and preserve failed or inconclusive runs.

## Evidence still required
Physical HP execution, repeated measurements, hotkey and audio checks, protected-application readiness, reboot persistence, exact rollback execution, and median results remain `needs-evidence`.

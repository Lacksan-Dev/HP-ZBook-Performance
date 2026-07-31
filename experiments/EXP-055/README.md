# EXP-055 Logitech G Hub updater demand start

## Candidate
Use the `LogitechGHubUpdaterDemandStart` controller profile to change only `LGHUBUpdaterService` from Automatic or Automatic Delayed Start to Manual. Preserve the service running state during application.

## Required support detection
Proceed only on elevated HP Windows 11 systems when exactly one service has the name `LGHUBUpdaterService`, the display identity identifies Logitech G HUB updater, the resolved executable ends in `lghub_updater.exe`, and Authenticode reports a valid Logitech or Logi publisher. Refuse absent, ambiguous, unsigned, identity-mismatched, disabled, driver-backed, dependency-bearing, enterprise-managed, or actively updating states.

Before mutation, inspect domain membership, MDM enrollment, PolicyManager state, Configuration Manager ownership, service policy paths, dependencies, dependent services, active `lghub`, `lghub_agent`, and `lghub_updater` processes, executable version, SHA-256, signature subject, service account, start mode, delayed-start value, and running state. Any protected Windows, security, update, recovery, credential, accessibility, networking, device-critical, Omnissa, Windows App, Remote Desktop, or Tailscale dependency causes refusal.

## Current-state capture
Write a versioned state artifact bound to EXP-055, provider identity, machine name, Windows build, HP manufacturer and model, capture timestamp, exact service name, display name, unexpanded binary path, resolved executable path, executable version, SHA-256, signature status and signer, service account, dependencies, dependent services, startup mode, delayed-auto-start value, and running state. Exclude serial numbers, usernames beyond the required local identity binding, credentials, tokens, tenant identifiers, and application data.

## Dry run and application
`DryRun` and `-WhatIf` must execute all support, identity, management, dependency, active-use, and drift checks without changing service configuration or running state. Application may execute only one mutation: set the exact service startup configuration to Manual and set `DelayedAutoStart` to zero. It must check the `sc.exe` exit code, preserve the current running state, verify the resulting configuration immediately, log the result as JSONL, and terminate on every mismatch.

Repeated application is idempotent only when the captured state artifact is valid and the exact applied state remains present. A missing, foreign, malformed, machine-mismatched, experiment-mismatched, provider-mismatched, or service-mismatched state artifact causes refusal.

## Verification
Immediate verification requires `StartMode=Manual`, `DelayedAutoStart=0`, unchanged running state, unchanged executable identity, unchanged dependencies, and unchanged protected scope. Reboot verification records boot time and confirms the exact Manual configuration persists while G HUB can be launched on demand, devices remain detected, configuration persists, updater behavior remains functional, and protected remote-access applications remain ready.

## Exact rollback
Rollback requires the captured machine, experiment, provider, service, executable path, version, SHA-256, signature, signer, service account, dependencies, and dependent services to match current state. It also requires the current configuration to equal the exact applied state. Refuse overwrite when service identity, executable identity, dependencies, management ownership, or configuration has drifted.

Restore the captured startup mode and exact delayed-auto-start value. Restore the captured running state only after identity checks pass. Verify exact startup, delayed-start, and running-state equality after restoration. Preserve failed rollback evidence and stop further mutation on any mismatch.

## Pester and integration coverage
Pester contract tests must verify the seven actions, exact service and executable identities, Logitech publisher validation, management refusal, dependency refusal, active-use refusal, SHA-256 capture, structured JSONL logging, `ShouldProcess`, `sc.exe` exit-code handling, idempotence, reboot verification, state identity validation, applied-state drift refusal, exact rollback, and protected-scope exclusions.

The integration procedure begins with `Check`, `Capture`, `DryRun`, and `-WhatIf`, confirming zero mutation by comparing service configuration, running state, executable hash, dependency lists, protected process readiness, and relevant registry state before and after. Physical application follows only after the zero-mutation checks pass.

## Benchmark and evidence
Perform at least five matched baseline and five treatment sign-ins. Record Windows build, HP model, BIOS, storage and display drivers, G HUB version, updater executable hash, power source, power mode, thermal state, network state, pending-reboot state, and instrumentation overhead. Report raw runs and medians for sign-in to usable desktop and first-120-second CPU and disk activity.

Verify G HUB demand launch, device detection, configuration persistence, update-check behavior, Logitech HID readiness, Device Manager health, Omnissa, Windows App, Remote Desktop, Tailscale, reboot persistence, and exact rollback. Preserve favorable, adverse, failed, and inconclusive evidence.

Physical application and measurements remain `needs-evidence`. Release status remains Experimental. Stable remains unassigned.

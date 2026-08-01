# EXP-024 Engineering Report

## Candidate
Change only `HPTouchpointAnalyticsService` from Automatic or Automatic (Delayed Start) to Manual. The controller refuses any service whose executable identity does not identify HP Touchpoint Analytics Client and preserves the captured running state while applying the startup-mode treatment.

## Controls
- HP Windows 11 support detection
- exact service name and executable-path identity
- HP publisher, version floor, hash, dependency, pending-reboot, and unmanaged-system gates
- original startup mode, delayed-auto-start state, dependency topology, and running-state capture
- dry run through `ShouldProcess`
- verified application and reboot-persistence verification
- JSONL structured logging
- idempotent repeated application
- terminating failure handling
- drift-aware exact rollback

## Safety boundary
No service is deleted. No executable, package, driver, HID component, security control, Windows Update component, recovery component, enterprise-management component, Omnissa component, Windows App component, Remote Desktop component, or Tailscale component is removed or disabled.

## Automated lab harness
`Invoke-Exp024LabHarness.ps1` turns the physical validation sequence into a reboot-aware state machine rather than a prose handoff.

The harness:
- uses the existing EXP-024 controller for support detection, capture, treatment, reboot verification, and exact rollback
- refuses a baseline whose captured startup mode is already Manual
- creates a unique evidence directory for each run
- registers one reversible current-user logon scheduled task and refuses a pre-existing task with the same identity
- requires a clean reboot before accepting each trial and rejects duplicate evidence from the same boot
- alternates Baseline and Treatment boots for the configured number of runs per arm
- samples first-window CPU, disk, and network activity for the configured duration
- captures HP Touchpoint service process CPU, I/O transfer deltas, TCP endpoints, running state, and whether it starts during the sample
- records Explorer start/responding data as a clearly labeled desktop-readiness proxy
- captures Tailscale and Remote Desktop service state plus matching Omnissa, Windows App, Remote Desktop, and Tailscale process presence
- records instrumentation CPU cost
- calculates medians and median absolute deviation from retained raw JSON runs
- restores the exact captured service state at completion or explicit Stop
- removes its scheduled task at completion or Stop
- gates automatic reboot behind the explicit `-AllowAutomaticReboot` switch
- never configures automatic logon or stores credentials

`-WhatIf` produces a dry-run plan without changing service startup state or registering the persistent harness task.

## Evidence limits
The harness deliberately labels `bootToExplorerStartMs` as a proxy rather than direct first-input latency. System network throughput is measured while service TCP endpoints are captured separately, so per-process network bytes remain unavailable from this harness. HP customer-workflow demand-start behavior remains a separate functional check until a supported local HP workflow is identified on the physical system.

Physical HP execution, five baseline and five treatment boots, customer-workflow demand-start confirmation, and resulting measurements remain `needs-evidence`. No performance improvement is claimed before those artifacts exist.

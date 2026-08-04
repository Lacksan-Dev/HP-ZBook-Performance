# Project Charter

## Program
Lacksan Windows R&D Lab

## Initial platform
HP ZBook business and workstation laptops running Windows 11.

## Program objective
Develop repeatable methods to measure, improve, verify, document, and reverse Windows responsiveness changes without relying on hardware replacement.

## Continuous operating model
- Run research and experiment work every two hours.
- Maintain multiple experiments in parallel.
- Convert useful findings from any research layer into focused EXP issues.
- Merge Experimental work by default after automated checks, scope review, original-state capture, verification, and rollback are complete.
- Use `needs-evidence` rather than blocking the portfolio.
- Stable release requires explicit human approval. The operator granted that approval on 2026-08-02 for validation-ready UX-ROM work after each candidate completes its declared physical verification on the operator-controlled lab computer; see `release/STABLE-APPROVAL-2026-08-02.md`.

## Current priorities
1. Reduce sign-in to usable-desktop latency.
2. Remove unnecessary user-application startup registrations while preserving Omnissa, Windows App, Remote Desktop, and Tailscale.
3. Remove Logitech user-space startup, tray, updater, and telemetry registrations while preserving device-critical drivers.
4. Minimize Microsoft Teams and Microsoft Office auto-start activity.
5. Minimize Microsoft Edge demand-launch latency without placing Edge in the Startup folder.
6. Find services that can be delayed, suspended, demand-started, consolidated, or replaced by smaller user-mode components.
7. Prototype lightweight user-mode replacements for redundant launchers, updaters, telemetry, readiness probes, and experiment logging.
8. Measure every candidate with repeated runs and medians.
9. On explicitly self-managed lab systems, clean operator-controlled Workplace/MDM enrollment state when it interferes with validation while keeping Windows security, Windows Update, Edge Update, credentials, and browser profile data outside the cleanup mutation scope.
10. Run merged validation-ready providers through the UX-ROM Physical Validation / Stable Promotion surface and retain machine-local evidence for promotion decisions.

## Experiments
- `EXP-001`: Establish an HP ZBook responsiveness baseline for Windows sign-in, Outlook, Edge, Windows Search, idle activity, and wake-to-network readiness.
- `EXP-002`: Minimize startup registrations with a protected remote-access allowlist.
- `EXP-003`: Optimize Edge demand-launch responsiveness without a Startup-folder entry.
- `EXP-004`: Discover and test reversible service suspension, demand-start, and replacement candidates.
- `EXP-005`: Prototype lightweight user-mode replacements for redundant Windows and vendor user-mode functions.
- `EXP-137`: Clean self-managed Workplace/MDM enrollment state, reboot-verify the cleanup, and resume EXP-071 Edge background-mode validation automatically.

## Release states
Experimental, Pilot, Stable, Retired, Rejected, Inconclusive.

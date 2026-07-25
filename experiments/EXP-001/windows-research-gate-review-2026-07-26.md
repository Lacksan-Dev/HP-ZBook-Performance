# EXP-001 Windows Research Gate Review

## Decision

Advance EXP-001 from `stage:research` to `stage:design`.

The existing Windows research dossier already establishes the measurement surfaces, compatibility boundaries, security constraints, primary instrumentation, required inventory, and candidate operational definitions needed for Experiment Design. Repeated benchmark samples, medians, instrumentation-overhead measurements, reboot persistence, and thermal/energy evidence belong in the executable protocol and later lab execution. Requiring those results before Design creates a circular gate because Design must first define how those results will be collected and accepted.

## Documented facts verified on 2026-07-26

1. Microsoft documents Windows Performance Recorder and Windows Performance Analyzer as the supported ETW collection and analysis stack for Windows performance work.
2. Microsoft Edge Startup Boost can start browser processes at OS sign-in and restart them after the final browser window closes. A process-cold Edge launch therefore requires explicit process-state control.
3. Microsoft documents the `StartupBoostEnabled` policy under `SOFTWARE\Policies\Microsoft\Edge` and the related background-mode policy surface.
4. Microsoft documents Windows Search as required for classic Outlook desktop search, with Automatic or Automatic (Delayed Start) supported startup modes.
5. HP Image Assistant 5.3.6, dated 2026-06-09, supports Windows 10 and Windows 11 on listed HP business platforms. Exact ZBook model support must be confirmed against HP's current platform list.

## Measured facts

Repository evidence records engineering screening and state-verification work, including repeated synthetic observations. Those results remain screening evidence only. No claim of customer-workflow improvement is accepted at this gate.

## Hypotheses carried into Design

- Sign-in and application-readiness variability may correlate with startup applications, services, logon-triggered tasks, update activity, security scanning, synchronization, power controls, thermal state, and application background processes.
- Edge and Outlook readiness may require separate cold, warm, local-content, and network-dependent workload definitions.
- HP platform controls may supersede or modify the effect of Windows power-mode settings on some ZBook models.

## Unresolved questions for Experiment Design

- Exact lab ZBook product number, BIOS, firmware, drivers, Windows build, application versions, management state, security stack, dock, display, power source, and thermal profile.
- Monotonic start and readiness markers for each customer workflow.
- Reset procedure for Outlook, Edge, Windows Search, wake-to-network, and idle observations.
- Instrumentation-overhead acceptance threshold.
- Repetition count, counterbalancing, warm-up handling, interrupted-run rules, median calculation, and dispersion reporting.
- Reboot-persistence test and rollback verification.
- Thermal and energy evidence collection method.
- Treatment of existing engineering work completed before the approved protocol.

## Design constraints

- Preserve Windows Update, Defender, firewall, management, encryption, recovery, HP security, and OEM support controls.
- Keep the baseline observational. Any later configuration change requires support detection, original-state capture, dry-run behavior, verification, structured logging, idempotence, failure handling, exact rollback, and rollback verification.
- Separate classic Outlook from new Outlook and process-cold Edge from background-assisted Edge.
- Record raw samples and report medians. Preserve failed and interrupted runs.
- Treat HP Image Assistant as read-only analysis during baseline characterization.

## Primary sources

- Microsoft Learn, Windows Performance Toolkit: https://learn.microsoft.com/windows-hardware/test/wpt/
- Microsoft Learn, Edge `StartupBoostEnabled` policy, updated 2026-05-21: https://learn.microsoft.com/deployedge/microsoft-edge-policies/startupboostenabled
- Microsoft Learn, Edge policy catalog: https://learn.microsoft.com/deployedge/microsoft-edge-policies
- Microsoft Support, desktop search service availability for Outlook: https://support.microsoft.com/outlook/why-is-desktop-search-service-unavailable
- HP Client Management Solutions, HP Image Assistant 5.3.6: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html
- HP Client Management Solutions, HPIA supported platforms: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/imagepal/ref/platformList.html

## Handoff

Experiment Design can now define the executable protocol and decide how existing screening artifacts will be isolated from the formal baseline series. No performance value or causal conclusion is accepted by this gate review.

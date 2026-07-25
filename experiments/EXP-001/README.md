# EXP-001: Establish HP ZBook Responsiveness Baseline

## Status
Experimental

## Current stage
Windows Research

## Customer problem
Office users frequently experience delayed responsiveness after Windows sign-in and during Outlook, Edge, Windows Search, OneDrive, and Teams activity.

## Initial scope
Measure the factory or current-state behavior of one representative HP ZBook before applying any calibration.

## Required environment record
- HP ZBook model
- CPU, memory, storage, and graphics
- Windows edition and build
- BIOS version
- Driver versions
- Microsoft 365 channel and version
- Edge version
- Power source and Windows power mode
- Ambient and thermal state
- Network type

## Initial measurements
- Sign-in to usable desktop
- Outlook cold launch
- Outlook warm launch
- Outlook search readiness
- Edge cold launch
- Edge first-interaction readiness
- Windows Search response
- Wake to network-ready
- Idle CPU, memory, and disk activity

## Benchmark rule
Use repeated runs and report the median. Record raw results. No performance claims exist until measurements are supplied.

## Next handoff
Keep `stage:research` until the workflow probes, instrumentation-overhead
profile, repeated raw runs, medians, reproducibility rule, and reboot-persistence
check in [validation-protocol.md](validation-protocol.md) are complete and
accepted. The experimental utility transaction is implemented and documented in
[engineering-validation.md](engineering-validation.md); it does not yet support
a performance claim or a design-stage handoff.

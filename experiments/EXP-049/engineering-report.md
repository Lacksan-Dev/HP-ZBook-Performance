# EXP-049 Engineering Report

## Purpose
Integrate a second reversible startup calibration into the Lacksan Controller through a named profile and the shared transaction model.

## Candidate
`ClassicTeamsDemandLaunch` inventories the system and removes one exact classic Teams Squirrel current-user Run registration. New Teams MSIX identities and all application, package, file, credential, service, task, update, device, and driver components remain unchanged.

## Controls
- HP Windows 11 support detection
- exact value name, launcher, process-start, and system-initiated argument matching
- refusal of new Teams, WindowsApps, updater-only, protected, broad, and multiple matches
- exact registry path, value name, unexpanded command, value kind, machine, user SID, and timestamp capture
- dry run, apply, immediate verification, JSONL logging, idempotence, terminating failure handling, reboot verification, exact rollback, overwrite refusal, and rollback verification
- controller dependency and protected-scope declarations
- Pester contract tests and a zero-mutation integration check

## Validation status
Physical HP Windows 11 application, five matched baseline and treatment sign-in trials, first-120-second CPU and disk measurements, protected remote-access readiness, Teams on-demand launch, sign-in and meeting readiness, update validation, reboot verification, rollback execution, instrumentation-overhead qualification, and medians remain `needs-evidence`.

## Release status
Experimental. Stable requires explicit human approval.

# EXP-048 Engineering Report

## Purpose
Integrate one existing reversible startup calibration into the Lacksan Controller so the product can execute a real mutation through a named profile rather than remaining inventory-only.

## Candidate
The `OneDriveDemandLaunch` profile runs system inventory and then removes one exact current-user `OneDrive.exe /background` Run registration. The application, files, credentials, updater, services, tasks, packages, and drivers remain unchanged.

## Controls
- HP Windows 11 support detection
- exact value-name, executable, argument, and protected-token matching
- original registry path, value name, unexpanded command, value kind, machine, user SID, and timestamp capture
- dry run, application, immediate verification, JSONL logging, idempotence, terminating failures, reboot-persistence verification, exact rollback, overwrite refusal, and rollback verification
- manifest dependency and protected-scope declarations
- Pester contract tests

## Validation status
Repository static review and physical lab execution remain separate. Physical application, at least five matched baseline and treatment sign-in trials, first-120-second CPU and disk measurements, protected remote-access readiness, OneDrive launch and synchronization checks, reboot verification, rollback execution, instrumentation-overhead qualification, and medians remain `needs-evidence`.

## Release status
Experimental. Stable requires explicit human approval.

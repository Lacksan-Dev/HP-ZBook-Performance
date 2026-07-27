# EXP-020 Engineering Report

## Candidate

Disable only `\Microsoft\Office\Office Background Task Handler Registration` and preserve every other Office, OneDrive, Windows, driver, security, management, and protected remote-access component.

## Implemented controls

- HP Windows 11 support detection
- exact task path, task name, exported XML, enabled state, and SHA-256 capture
- dry-run output with zero system modification
- bounded application through `ShouldProcess`
- post-change verification
- JSONL event logging
- idempotent repeated application
- terminating identity, integrity, support, application, and rollback failures
- reboot-persistence verification mode
- exact enabled-state rollback with integrity-checked state
- Pester contract tests

## Validation handoff

Physical HP ZBook evidence remains required:

1. Record Windows build, HP model, BIOS, Office version, power source, and thermal state.
2. Run at least five controlled baseline trials and five candidate trials.
3. Measure sign-in to usable desktop, first-120-second CPU and disk activity, Office cold launch, document open/save, and OneDrive readiness.
4. Qualify measurement overhead.
5. Apply, reboot, verify persistence, execute rollback, reboot, and verify exact restoration.
6. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
7. Report medians and preserve failed or inconclusive evidence.

## Current result

Engineering complete. Performance effect remains unmeasured. Release status remains Experimental. Stable remains unavailable without explicit human approval.

# EXP-041 Engineering Report

## Candidate
Enable the documented Microsoft Edge recommended policy `EfficiencyModeEnabled` with DWORD value `1`.

## Change boundary
The implementation writes one recommended Edge policy value. It does not modify applications, user data, services, scheduled tasks, drivers, security controls, update components, recovery, enterprise management, or protected remote-access applications.

## Engineering controls
Support detection, management-policy refusal, current-state capture, dry run, application verification, JSONL logging, idempotence, failure handling, reboot-persistence verification, exact rollback, rollback mutation refusal, Pester contract tests, and a read-only integration check are included.

## Validation handoff
Run five matched baseline and five treatment trials under the same Windows build, HP model, BIOS, driver set, Edge version, power source, power mode, and thermal condition. Report medians for launch milestones, controlled navigation, CPU, memory, disk, GPU, and battery cost. Verify restart behavior, reboot persistence, rollback, Edge update behavior, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

## Evidence status
Physical measurements remain `needs-evidence`. Preserve `status:experimental`. No performance result is claimed.

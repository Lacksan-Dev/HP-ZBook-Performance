# EXP-014 Engineering Report

## Candidate
A user-mode Microsoft Edge demand-launch broker that launches one controlled new-tab window only when requested.

## Implemented controls
- Windows installation support detection through Edge binary resolution
- pre-existing broker-state detection and idempotent repeated application
- dry-run output
- controlled application through `ShouldProcess`
- visible-window readiness verification with bounded timeout
- JSONL structured logging
- captured process identity and launch timing
- exact rollback limited to the process ID created by the broker
- rollback verification and state-file removal
- failure logging
- Pester contract tests

## Preserved state
No registry, service, scheduled task, Startup folder, Edge profile, password, cookie, favorite, extension, security, update, management, driver, Omnissa, Windows App, Remote Desktop, or Tailscale setting is changed.

## Evidence classification
Repository implementation only. Physical HP ZBook launch measurements, repeated runs, medians, instrumentation overhead, and comparison with direct Edge launch remain pending. No responsiveness claim is approved.

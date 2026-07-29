# EXP-051 Validation Handoff

Status: needs-evidence

Run on an HP Windows 11 target with an eligible Logi Bolt registration.

1. Record Windows build, model, BIOS, Logi Bolt version, Logitech driver versions, power source, thermal state, and instrumentation version.
2. Complete five matched baseline sign-in trials.
3. Run controller DryRun, Capture, Apply, and Verify for `LogiBoltDemandLaunch`.
4. Complete five matched treatment sign-in trials.
5. Compare medians for sign-in to usable desktop and CPU and disk activity during the first 120 seconds.
6. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
7. Confirm Logi Bolt manual launch, receiver visibility, keyboard and mouse function, and settings access.
8. Reboot and run VerifyReboot.
9. Run Rollback, verify exact registry restoration, reboot, and confirm restored auto-launch behavior.
10. Preserve every failed or inconclusive run and qualify instrumentation overhead.

Success requires a reproducible median responsiveness improvement without functional, reliability, security, update, management, driver, or remote-access regression. No threshold result is recorded until physical evidence exists.

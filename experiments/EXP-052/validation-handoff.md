# EXP-052 Validation Handoff

Status: needs-evidence

1. Record Windows build, HP model, BIOS, Logi Tune and Logitech driver versions, power source, thermal state, and instrumentation.
2. Complete five matched baseline sign-in trials.
3. Run controller DryRun, Capture, Apply, and Verify for `LogiTuneDemandLaunch`.
4. Complete five matched treatment trials and compare medians for sign-in readiness and first-120-second CPU and disk activity.
5. Confirm Omnissa, Windows App, Remote Desktop, and Tailscale readiness.
6. Confirm Logi Tune manual launch, camera and headset visibility, settings access, and update behavior.
7. Reboot and run VerifyReboot.
8. Run Rollback, verify exact registry restoration, reboot, and confirm restored auto-launch behavior.
9. Preserve failed and inconclusive runs and qualify instrumentation overhead.

No performance threshold result is recorded until physical evidence exists.

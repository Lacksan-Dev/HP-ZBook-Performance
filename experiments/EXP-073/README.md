# EXP-073: Edge sleeping-tabs timeout

## Candidate
Set only `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended\SleepingTabsTimeout` to `REG_DWORD 900`, the supported 15-minute value. Microsoft documents the policy for Edge 88 or later, with mandatory and recommended registry paths and dynamic policy refresh.

## Safety boundary
The provider requires elevated HP Windows 11, one supported Edge installation, no enterprise-management signals, and no existing mandatory or recommended timeout value. It changes no Edge profile, credentials, cookies, favorites, extensions, files, services, tasks, packages, drivers, security controls, update controls, recovery settings, enterprise-management settings, or protected remote-access applications.

## Execution
1. Run `Check`, then `Capture` or `DryRun`.
2. Run `Apply`; repeat it to confirm zero-mutation idempotence.
3. Restart Edge and run `Verify`.
4. Reboot and run `VerifyReboot`.
5. Run `Rollback`; confirm the experiment-created value is absent and repeat rollback safely.
6. Retain state and JSONL logs for successful, failed, and inconclusive runs.

## Physical validation
Collect at least five matched baseline and five treatment runs on the same Windows build, BIOS, Edge version, power source, thermal condition, and workload. Record inactive-tab working set, background CPU and disk activity, tab reactivation latency, Edge cold launch, first navigation, Outlook responsiveness, and Omnissa, Windows App, Remote Desktop, and Tailscale readiness.

Physical execution, browser restart, reboot persistence, exact rollback, and median measurements remain `needs-evidence`. Keep Experimental. Never assign Stable.

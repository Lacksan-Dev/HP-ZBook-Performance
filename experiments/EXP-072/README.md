# EXP-072 Edge sleeping tabs recommended policy

## Candidate
Set only `HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended\SleepingTabsEnabled` to `REG_DWORD 1` on supported unmanaged HP Windows 11 systems.

## Safety and integration check
Run `Check`, `Capture`, and `DryRun` first. Confirm zero mutation during those actions. Refuse managed systems or any existing mandatory or recommended value. Confirm Windows security, Windows Update, recovery, device-critical drivers, Omnissa, Windows App, Remote Desktop, and Tailscale remain unchanged.

## Physical validation
Record Windows build, HP model, BIOS, Edge version, driver set, AC or battery state, power mode, thermal state, tab set, dwell duration, and instrumentation overhead. Run five matched baseline and five treatment trials. Measure Edge working set after inactive-tab dwell, background CPU and disk, tab reactivation latency, cold launch, first interactive window, first navigation, Outlook responsiveness, and protected remote-access readiness. Report medians and retain every failed or inconclusive run.

After application, restart Edge and run `Verify`. Reboot and run `VerifyReboot`. Execute `Rollback`, confirm the experiment-created value is absent, restart Edge, and repeat protected-scope readiness checks. Physical measurements remain `needs-evidence`.

# EXP-084 Office hardware graphics acceleration comparison

## Candidate
Set only `HKCU\Software\Microsoft\Office\16.0\Common\Graphics\DisableHardwareAcceleration` to `REG_DWORD 1` for an eligible current-user classic Outlook installation on an unmanaged HP Windows 11 system.

## Safety and refusal
The provider requires one Microsoft-signed classic Outlook executable, captures Outlook and graphics-driver identity, and refuses domain, MDM, PolicyManager, Configuration Manager, Office-policy ownership, any existing preference value, ambiguous Outlook installations, invalid signatures, and any running Outlook, Word, Excel, PowerPoint, OneNote, or Access process. It changes no mailbox, profile, OST/PST, add-in, Click-to-Run component, Office update setting, display driver, GPU setting, service, task, package, security control, recovery setting, enterprise-management state, device-critical driver, Omnissa, Windows App, Remote Desktop, or Tailscale configuration.

## Lifecycle
1. Run `Check` and retain support, Outlook executable, graphics-driver, management, and current registry evidence.
2. Close every Office desktop application.
3. Run `Capture` with a new state path.
4. Run `DryRun` and `-WhatIf`; verify zero mutation.
5. Run `Apply`; verify one current-user DWORD mutation.
6. Run `Verify`, launch Outlook and the Office regression controls, close them, reboot, then run `VerifyReboot`.
7. Close Office applications and run `Rollback`; verify exact original-value absence and remove the Graphics key only when the experiment created it and it remains empty.

All actions emit structured JSONL when `LogPath` is supplied. State artifacts are schema-versioned and bound to the experiment, provider, machine, user SID, path, value, treatment, and captured Outlook executable identity. Existing state files, management ownership, Office process activity, preconfigured values, executable drift, applied-state drift, and rollback overwrite conditions terminate execution.

## Pester and zero-mutation integration
Run `controller/tests/EXP-084.OfficeHardwareAccelerationPolicy.Tests.ps1` with Pester. On Windows, capture before and after exports for the target registry path, Office policy paths, Office process inventory, Outlook executable identity, graphics adapters and driver versions, installed Office identity, Defender, Firewall, BitLocker, Credential Guard and VBS, Windows Update, recovery, enterprise-management indicators, device inventory, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale. `Check`, `DryRun`, and `-WhatIf` must produce identical before and after captures.

## Application and verification integration
Use a disposable current-user state path and JSONL log. Execute `Capture`, `Apply`, `Verify`, a controlled Outlook launch, controlled mailbox navigation and message selection, compose-window opening, scrolling, and high-DPI rendering checks. Execute basic cold-launch and rendering checks for Word, Excel, and PowerPoint. Close Office, reboot, run `VerifyReboot`, repeat functional checks, close Office, run `Rollback`, and verify the exact original registry state and protected-scope snapshots.

Retain every refusal, parser failure, provider failure, launch failure, rendering defect, rollback failure, and inconclusive observation. Never replace adverse evidence with a later successful run.

## Physical validation
Use five matched baseline restarts and five matched treatment restarts under the same Windows build, HP model, BIOS, Office and Outlook version, mailbox state, add-in set, display topology, resolution, scaling, session type, GPU and driver version, AC power, power mode, thermal state, network condition, and launch procedure.

Report raw runs, medians, and dispersion for sign-in to usable desktop; Outlook process start to first visible window, responsive main window, folder-pane and message-list readiness, and one controlled local interaction; Outlook CPU time, peak working set, disk I/O, and GPU engine activity; first-120-second system CPU and disk activity; Word, Excel, and PowerPoint cold-launch readiness; and Omnissa, Windows App, Remote Desktop, and Tailscale readiness.

Success requires at least a 15 percent reduction in median Outlook cold-launch-to-responsive latency with no material regression in rendering correctness, launch reliability, Office regression controls, sign-in readiness, or protected-application readiness. Neutral, adverse, failed, rejected, and inconclusive results remain evidence.

Physical execution, repeated measurements, reboot persistence, rendering checks, cross-Office controls, protected-application checks, instrumentation qualification, and exact rollback remain `needs-evidence`. Stable requires explicit human approval.

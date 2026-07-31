# EXP-083 Windows Search highlights policy

## Candidate
Set only `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search\EnableDynamicContentInWSB` to `REG_DWORD 0` on an eligible unmanaged HP Windows 11 system.

## Safety and refusal
The provider refuses unsupported editions, missing elevation, domain membership, MDM enrollment, PolicyManager ownership, Configuration Manager ownership, and any existing policy value. It changes no Search service, index, package, task, executable, network setting, security control, update component, recovery setting, driver, or protected remote-access application.

## Lifecycle
1. Run `Check` and retain support and management evidence.
2. Run `Capture` with a new state path.
3. Run `DryRun` and `-WhatIf`; confirm zero mutation.
4. Run `Apply`; verify one DWORD mutation.
5. Run `Verify`, refresh Search UI or reboot, then run `VerifyReboot`.
6. Run `Rollback`; verify the original value absence and remove the policy key only when the experiment created it and it remains empty.

All actions emit JSONL records when `LogPath` is supplied. State artifacts are schema-versioned and bound to experiment, provider, machine, user SID, path, and value name. Existing state files, management ownership, policy drift, and rollback overwrite conditions terminate execution.

## Pester and integration
Run the EXP-083 Pester contract. On Windows, capture before and after registry exports, Search service state, Search package inventory, index configuration, Defender, Firewall, BitLocker, VBS, Windows Update, recovery, enterprise-management signals, device inventory, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale. Dry run and `-WhatIf` must produce identical before and after captures.

## Physical validation
Use five matched baseline and five matched treatment runs under the same Windows build, edition, BIOS, drivers, power source, thermal state, network state, index state, and query set. Retain raw runs and report medians plus dispersion for Search-home readiness, first local application, setting, and file result readiness, SearchHost CPU, disk, memory, and network activity, sign-in readiness, Outlook readiness, and protected-application readiness.

Physical execution, repeated measurements, reboot persistence, local-search checks, protected-application checks, and exact rollback remain `needs-evidence`. Preserve favorable, adverse, failed, rejected, and inconclusive evidence. Never assign Stable automatically.

# EXP-011 Research Brief: Edge Background Mode

## Customer problem

Microsoft Edge should open quickly when requested without retaining unnecessary browser applications and browsing-session processes after the last window closes.

## Objective

Measure `BackgroundModeEnabled` independently from `StartupBoostEnabled`, then determine whether disabling background mode reduces post-close resource cost while preserving or improving demand-launch readiness under the selected Startup Boost configuration.

## Documented facts

1. Microsoft documents `BackgroundModeEnabled` for Microsoft Edge 77 or later on Windows.
2. Enabling background mode allows Edge processes to start at operating-system sign-in and remain running after the last browser window closes. Background applications and the current browsing session, including session cookies, can remain active.
3. Microsoft documents mandatory and recommended policy paths. The recommended Windows registry path is `SOFTWARE\Policies\Microsoft\Edge\Recommended`, value `BackgroundModeEnabled`, type `REG_DWORD`.
4. Microsoft documents `StartupBoostEnabled` for Edge 88 or later on Windows. Startup Boost can start Edge processes at sign-in and restart them in the background after the last browser window closes.
5. Microsoft explicitly documents an interaction between Startup Boost and background mode. When background mode keeps Edge alive, Startup Boost may have no closed-browser event from which to restart Edge.
6. Both policies support dynamic refresh, apply across profiles, and apply to profiles signed in with a Microsoft account.

## Hypothesis

With Startup Boost controlled separately, setting recommended `BackgroundModeEnabled=0` may reduce process count and private working set after the last Edge window closes while retaining the demand-launch benefit supplied by Startup Boost. This remains unmeasured.

## Independent variable

Recommended `BackgroundModeEnabled` only:

- Control: preserve the captured original recommended-policy state.
- Treatment: recommended `BackgroundModeEnabled=0`.

Mandatory enterprise `BackgroundModeEnabled` policy takes precedence. Application must refuse when a mandatory value exists.

## Controlled variables

- Existing `StartupBoostEnabled` treatment and effective state
- Edge version and update channel
- Edge profile
- extensions
- first-run state
- hardware acceleration state
- sleeping-tabs configuration
- test URL and network path
- Windows build, device, BIOS, drivers, power source, power mode, and thermal condition

## Required measurements

For each valid control and treatment condition, use repeated runs and report medians:

- cold process launch
- first visible window
- first interactive window
- first new-tab readiness
- first controlled navigation
- Edge process count and private working set before launch
- Edge process count and private working set after closing the last window
- time until the expected post-close process state is reached
- behavior after reboot

Record raw runs and variability. Do not combine Startup Boost and background-mode changes in one treatment transition.

## Engineering requirements

- HP Windows 11 and Edge support detection
- mandatory-policy detection and refusal
- exact capture of recommended-policy key existence, value existence, type, and data
- dry run
- application through the recommended policy path
- effective-policy verification after Edge policy refresh or browser restart as required by the implementation
- structured JSONL logging
- idempotent repeated application
- explicit failure handling
- reboot-persistence verification
- exact rollback and rollback verification
- no Edge Startup-folder entry

## Preserved boundaries

Preserve profiles, passwords, cookies, favorites, extensions, SmartScreen, security controls, Edge Update, enterprise management, Omnissa, Windows App, Remote Desktop, Tailscale, Windows security, recovery, and device-critical drivers.

## Risks

- Extensions or installed web applications may rely on background execution.
- Closing the last Edge window may change notification or application behavior when background mode is disabled.
- Recommended policy can be overridden by the user.
- Startup Boost and background mode interact, so an uncontrolled combined change would confound results.

## Rollback requirement

Restore the exact captured recommended-policy state. If the value or key was absent, remove only the experiment-created value and remove the key only when it was created by the experiment and remains empty.

## Evidence status

Physical HP ZBook application, effective-policy confirmation, reboot persistence, rollback execution, repeated launch trials, post-close resource measurements, instrumentation-overhead qualification, and median comparison remain `needs-evidence`. No performance improvement is claimed.

## Primary sources

- Microsoft Edge policy reference, `BackgroundModeEnabled`, retrieved 2026-07-27: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled
- Microsoft Edge policy reference, `StartupBoostEnabled`, retrieved 2026-07-27: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled
- Microsoft Edge policy index, retrieved 2026-07-27: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies

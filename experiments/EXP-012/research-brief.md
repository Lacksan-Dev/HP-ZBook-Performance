# EXP-012 Research Brief

## Objective
Measure whether enabling Microsoft Edge Sleeping Tabs through the recommended policy reduces eligible background-tab resource use while preserving demand-launch responsiveness and active-site behavior.

## Documented facts
- Microsoft documents `SleepingTabsEnabled` for Edge 88 or later on Windows.
- The policy supports mandatory and recommended configuration.
- The recommended registry path is `HKLM\SOFTWARE\Policies\Microsoft\Edge\Recommended` and the value is `SleepingTabsEnabled` as `REG_DWORD`.
- Sleeping Tabs uses heuristics to avoid sleeping tabs performing useful background work.

## Hypothesis
Enabling the recommended policy may reduce background CPU and memory use with acceptable tab-wake latency. This remains unmeasured.

## Scope
One policy value only. Startup Boost, background mode, timeout, URL exclusions, efficiency mode, profiles, extensions, cache, hardware acceleration, and first-run state remain unchanged.

## Safety boundary
Mandatory enterprise policy has precedence. Preserve Edge data, SmartScreen, updates, management, Startup folders, Omnissa, Windows App, Remote Desktop, Tailscale, Windows security, recovery, and drivers.

## Required evidence
Repeated control and treatment runs with medians for demand launch, first interaction, controlled navigation, active-tab behavior, background CPU, private working set, and tab-wake latency. Record Edge version, Windows build, device, power, thermals, extensions, and test URLs.

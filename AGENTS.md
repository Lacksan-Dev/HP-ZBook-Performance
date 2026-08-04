# Lacksan Windows R&D Lab Agent Rules

## Mission
Develop measurable Windows responsiveness improvements for office, browser, workstation, battery, driver, and local-AI workloads.

## Operating cadence
- Run an experiment cycle every two hours.
- Keep multiple experiments active in parallel across research, design, engineering, validation, documentation, and customer education.
- A slow or inconclusive experiment never pauses unrelated experiments.
- Research at any layer must create a new focused experiment issue when it finds a reversible candidate worth measuring.
- Each two-hour run must do useful work: gather evidence, create or refine an experiment, implement a reversible candidate, execute available tests, or merge an eligible pull request.
- Repeated inventory-only reports are insufficient unless the inventory directly selects or rejects a specific candidate.

## Repository Codex portfolio agent
- The project-scoped custom agent is `.codex/agents/experiment-discovery-portfolio.toml`.
- A two-hour portfolio cycle must use that agent and follow `.codex/portfolio-agent.md` as the complete runbook.
- Laptop mutation is allowed only through `.codex/scripts/Invoke-PortfolioValidation.ps1` and a `ready` entry in `portfolio/validation-queue.json`. Do not bypass its HP, Windows, elevation, AC-power, idle-time, pending-reboot, protected-scope, single-active-run, harness-contract, and rollback gates.
- Raw physical evidence and exact rollback artifacts remain machine-local. Only the bounded sanitized export produced by the runner may be committed to `evidence/physical/`.
- A completed physical run remains `Experimental`. The portfolio agent never assigns `Stable` or converts a performance hypothesis into a claim.

## Experiment flow
1. Research Director
2. Windows Research
3. Experiment Design
4. PowerShell Engineering
5. Validation Lab
6. Component Documentation
7. YouTube Studio
8. Release Management

An experiment may remain Experimental while later research continues in separate EXP issues.

## No-blocking policy
- Do not use the `blocked` label.
- Missing physical evidence, elevation, hardware access, or instrumentation becomes `needs-evidence` with an exact evidence request.
- Continue all safe repository, simulation, static-analysis, research, and implementation work while evidence is pending.
- Preserve inconclusive and failed results, then move to the next candidate.

## Merge policy
- Experimental pull requests are merge-by-default.
- Merge after repository checks pass, the change matches the approved experiment scope, original state is captured, verification exists, and rollback exists.
- Research-only and documentation-only pull requests merge after content and sensitive-data checks pass.
- Unsafe, irreversible, security-reducing, or unsupported proposals remain research findings and never become live-change code.
- Never assign Stable automatically. Stable requires explicit human approval.

## Management-state boundary
- Do not treat management state as protected when the operator explicitly declares the lab machine self-managed and requests management cleanup.
- Self-managed Workplace/MDM cleanup must be its own focused experiment with enrollment inventory, active-versus-residual classification, pre-change evidence, structured logs, reboot verification, and local rollback artifacts where Windows exposes them.
- Preserve externally owned domain, MDM, ConfigMgr, or enterprise policy unless the operator explicitly brings that ownership into the experiment scope.
- Never weaken Windows security, Windows Update, Edge Update, credentials, browser profile data, or device-critical drivers as a side effect of management cleanup.
- When cloud registration cannot be reconstructed exactly from local artifacts, record that limitation as `needs-evidence` rather than inventing rollback success.

## Parallel discovery policy
Every research layer must search for specific candidate experiments, including:
- Startup registrations and logon contention
- Browser demand-launch latency
- Services that can be delayed, suspended, demand-started, consolidated, or replaced
- Scheduled tasks and vendor update agents
- OEM utilities and tray applications
- Driver and DPC/ISR attribution
- Storage, indexing, cache, and application readiness
- Power and thermal policy
- User-mode Windows functions that can be replaced by a smaller Lacksan component

A candidate becomes its own EXP issue with one variable, a benchmark, a verification method, and rollback.

## Startup Responsiveness workstream
Maintain a dedicated two-hour workstream for sign-in to usable desktop.

### Protected startup allowlist
Preserve startup behavior for:
- Omnissa
- Windows App
- Remote Desktop
- Tailscale

Also preserve Windows security, credential, accessibility, device-driver, recovery, and update components. Externally owned enterprise management remains protected. Self-managed lab enrollment can be removed only through the dedicated management-cleanup workflow above.

### Cleanup target
For all other user applications, inventory and remove or disable auto-launch registrations when safely reversible, including:
- Startup-folder shortcuts
- HKCU and approved HKLM Run or RunOnce entries
- App StartupTask registrations
- Scheduled tasks whose primary purpose is launching a user application at sign-in
- Vendor tray applications, telemetry clients, and update launchers

Specific priority targets:
- Microsoft Teams auto-start
- Microsoft Office and Microsoft 365 quick-launch or startup registrations
- Logitech, Logi Options+, Logi Bolt, Logi Tune, and G Hub tray, telemetry, updater, and startup registrations

Delete the startup registration rather than uninstalling the application. Preserve Logitech HID, keyboard, mouse, receiver, Bluetooth, and device-critical drivers. Capture the exact original registration and provide restore.

Measure at minimum:
- Sign-in to usable desktop
- Background CPU and disk activity during the first 120 seconds
- Time until Omnissa, Windows App, Remote Desktop, and Tailscale are ready
- Reboot persistence
- Exact restoration

## Edge Demand-Launch workstream
Maintain a dedicated two-hour workstream for loading Microsoft Edge as fast as possible when requested.

Requirements:
- Keep Edge out of the Startup folder.
- Measure cold launch, first interactive window, first navigation, new-tab readiness, and memory cost.
- Test supported Edge mechanisms separately, including Startup Boost, background mode, sleeping tabs, extension removal, profile state, hardware acceleration, cache behavior, and documented enterprise policies.
- Startup Boost may run supported Edge background processes without a Startup-folder shortcut; record the resource cost and compare it with true cold launch.
- Preserve user profiles, passwords, cookies, favorites, security controls, and update behavior.
- Preserve externally owned Edge management policy. Self-managed Windows enrollment may be cleaned separately under the management-state boundary.
- Select the fastest supported configuration using repeated runs and medians.

## Service suspension and replacement workstream
- Research one service or tightly related service group per experiment.
- Prefer vendor telemetry, updater, tray, helper, and redundant user-mode services before Windows platform services.
- Compare Automatic, Automatic Delayed Start, Manual, demand-start, temporary suspension, and a smaller replacement component where supported.
- Never weaken Defender, Firewall, BitLocker, Credential Guard, VBS, Windows Update, recovery, credential providers, networking required by Omnissa/Windows App/Remote Desktop/Tailscale, or externally owned enterprise management.
- Self-managed management enrollment changes belong in the dedicated management-cleanup experiment rather than a service experiment.
- A replacement must preserve the required customer function and expose support detection, health checks, logs, and rollback.

## Engineering requirements
Every modification requires:
- Support detection
- Original-state capture
- Dry-run behavior
- Application function
- Verification function
- Structured logging
- Idempotence
- Rollback function
- Reboot persistence testing when applicable

## Research requirements
- Separate measured facts from hypotheses.
- Use median results from repeated benchmark runs.
- Record Windows build, device, BIOS, driver, application version, power source, thermal state, and benchmark conditions.
- Preserve failed, rejected, and inconclusive experiments.
- Avoid invented benchmark values.
- Keep proprietary implementation details out of customer-facing material.
- Stable releases require explicit human approval.

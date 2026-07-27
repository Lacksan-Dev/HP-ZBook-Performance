# EXP-001 Windows Research: HP ZBook Responsiveness Baseline

## Research control

- Experiment: `EXP-001`
- Source issue: `Lacksan-Dev/HP-ZBook-Performance#1`
- Issue priority: P1 (High)
- Research date and source retrieval date: 2026-07-25
- Target family: one lab-controlled HP ZBook running Windows 11
- Repository input: [research-brief.md](research-brief.md)
- Stage disposition: **keep `stage:research`**
- Supplemental startup/community triage:
  [startup-community-research-2026-07-26.md](startup-community-research-2026-07-26.md)
- Hourly layer 1 physical/thermal evidence:
  [layer-01-physical-thermal-2026-07-27.md](layer-evidence/layer-01-physical-thermal-2026-07-27.md)
- Hourly layer 2 hardware-resource evidence:
  [layer-02-hardware-resources-2026-07-27.md](layer-evidence/layer-02-hardware-resources-2026-07-27.md)

This report covers one experiment only. It maps the Windows, application, driver,
firmware, policy, service, scheduled-task, registry, and HP OEM surfaces that can
affect the requested baseline. It does not apply or recommend a calibration.

## Executive finding

Windows Performance Recorder (WPR), Windows Performance Analyzer (WPA), Windows
Assessment Toolkit, inbox power and network diagnostics, application state, and
read-only HP tooling can support this baseline. The experiment is not ready for
Experiment Design, however, because the repository contains no selected system
inventory, no validated start/readiness definitions, no recorded instrumentation
overhead, and no repeated raw measurements or medians.

The evidence is therefore sufficient to define the research envelope and the
remaining collection work, but not sufficient to satisfy the research brief's
handoff gate. `stage:research` must remain in place.

## Scope and evidence classifications

The research brief authorizes current-state measurement only. No Windows, BIOS,
driver, application, policy, service, startup, power, registry, security, update,
or OEM configuration is to be changed for this baseline.

This document uses the following classifications:

- **Documented fact**: behavior or support information stated by a primary vendor
  source.
- **Lab measurement**: a value observed on the selected lab system under recorded
  conditions. There are no lab measurements yet.
- **Hypothesis**: a causal explanation that a later controlled trace or experiment
  may test.
- **Unresolved question**: information that is absent or not yet validated.

Vendor documentation describes supported behavior; it is not evidence that a
feature, policy, driver, service, task, or bottleneck is present on the eventual
test system.

## Documented facts

### Measurement stack and Windows release control

1. The Windows Performance Toolkit (WPT) is part of the Windows Assessment and
   Deployment Kit (ADK). WPR records Event Tracing for Windows (ETW) data and WPA
   analyzes the resulting traces. WPR supports built-in and custom XML profiles.
   [Windows Performance Toolkit][S01], [ETW][S02], [WPR reference][S03]

2. The Windows Assessment Console can package assessments into repeatable jobs
   and compare results. Microsoft's On/Off Transition Performance assessment
   covers boot, Fast Startup, hibernate, and standby scenarios. Its standardized
   results can supplement, but cannot replace, this experiment's customer-facing
   readiness endpoints. [Assessment Console][S04], [Available assessments][S05]

3. Microsoft's Fast Startup analysis exercise uses WPR scenario recording and
   WPA to inspect initialization phases. Explorer initialization markers can aid
   attribution, but Explorer completion alone does not establish the brief's
   undefined “usable desktop” condition. [Fast Startup analysis][S06]

4. ADK support is version-dependent. The lab should use an ADK supported for the
   recorded Windows build and install the current servicing patch. A trace
   collector or analysis version must not be selected before the exact Windows
   release and architecture are known. [ADK download and support][S07],
   [What's new in Windows kits][S08]

5. Windows 11 feature updates follow an annual release cadence, and servicing
   status varies by release and edition. The exact edition, release, build, and
   cumulative update are part of the experiment identity. [Windows 11 release
   information][S09]

6. File-system minifilters used by security, encryption, backup, and other
   products can add I/O work. The Windows minifilter assessment can attribute
   callback duration. Presence or latency must be measured; it is not a reason
   to disable a filter. [Minifilter diagnostics][S10], [File-system filter
   drivers][S11]

### Sign-in, startup, services, policy, and maintenance

7. Documented legacy startup locations include:

   - `HKLM\Software\Microsoft\Windows\CurrentVersion\Run`
   - `HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce`
   - `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
   - `HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`

   Microsoft states that execution order is indeterminate and that Windows can
   delay startup execution. Startup applications can also be registered through
   startup folders and surfaced in Settings or Task Manager. [Run and RunOnce
   keys][S12], [Configure startup applications][S13], [Startup application
   compatibility][S14]

8. Task Scheduler supports logon triggers. A task definition's trigger, action,
   conditions, principal, last/next run time, and last result are therefore
   required inventory for sign-in analysis; a task name alone is not evidence of
   impact. [Logon-triggered tasks][S15]

9. Windows creates some per-user service instances at sign-in. Their names and
   behavior vary by Windows version. Microsoft's documentation warns against
   broad disabling because applications and system functions depend on them.
   [Per-user services][S16]

10. Winlogon loads the user profile before it activates the shell. User Profile
    Service operational events and Group Policy processing can help divide the
    sign-in path. Synchronous Group Policy waits before exposing the desktop;
    asynchronous processing does not. [Winlogon responsibilities][S17],
    [User Profile Service events][S18], [initial Group Policy processing][S19]

11. Supported Windows clients can delay logon scripts to reduce contention, and
    the documented policy maps to
    `Software\Policies\Microsoft\Windows\System` with the
    `EnableLogonScriptDelay` value. This is an inventory item only: changing it
    would alter the baseline and may violate organization management intent.
    [Logon script delay behavior][S20], [Policy CSP mapping][S21]

12. Automatic Maintenance runs eligible tasks under idle and power conditions
    and normally pauses when the user resumes activity. Scheduled maintenance,
    update, security, telemetry, and OEM tasks can contaminate an idle or launch
    run, but no task may be disabled merely because it executes during a trace.
    [Automatic Maintenance tasks][S22], [Task Scheduler overview][S23]

13. Delivery Optimization can deliver Windows, Store, and other Microsoft
    content and can participate in Microsoft 365 Apps updates. Its activity can
    consume network, CPU, and disk resources. Supported bandwidth policies exist,
    but they are not changes authorized by this baseline. [Delivery Optimization
    workflow][S24], [Delivery Optimization policy reference][S25],
    [Microsoft 365 Apps and Delivery Optimization][S26]

14. Microsoft Defender Antivirus includes a performance analyzer on supported
    Windows 10/11 clients with Defender platform 4.18.2108.7 or later and
    PowerShell 5.1 or later. It records scan attribution by path, file, process,
    and extension. It should be used only if an ETW trace attributes material
    work to Defender. Microsoft cautions that every exclusion reduces protection.
    [Defender performance analyzer][S27], [Defender exclusions][S28]

### Outlook and Windows Search

15. Classic Outlook can use Cached Exchange Mode with Microsoft 365 or Exchange
    accounts, maintaining an offline Outlook data file. New Outlook does not
    expose the classic Cached Exchange Mode option, and POP/IMAP accounts do not
    use it. Variant, account type, profile type, online/cached state, data volume,
    add-ins, and network path materially change the launch and search workloads.
    [Cached Exchange Mode][S29], [Outlook performance troubleshooting][S30]

16. Classic Outlook search can depend on Windows Search indexing of OST/PST
    content. Indexing continues while Outlook is running and can back off under
    load. Rebuilding the catalog is a disruptive repair that can take substantial
    time and must not be used to prepare a neutral baseline. [Outlook performance
    troubleshooting][S30], [Rebuild the search catalog][S31]

17. Microsoft documents Windows Search (`WSearch`) as required for Outlook desktop
    search, with Automatic or Automatic (Delayed Start) as supported startup
    states. Disabling it would break the target workflow, not optimize it.
    [Desktop Search service unavailable][S32]

18. Classic Outlook supports COM add-ins; new Outlook does not. Classic Outlook
    records add-in boot timing in Application event log event 45, and documented
    COM add-in inventory includes
    `HKLM\SOFTWARE\Microsoft\Office\Outlook\Addins`. Add-ins should be inventoried
    and timed, not disabled during baseline collection. [Outlook add-in
    warnings][S33], [Outlook add-in event logging][S34], [Create an add-in
    inventory][S35]

19. Windows Search “Classic” and “Enhanced” modes cover different paths and have
    different resource costs. Search status may be throttled by user activity,
    idle state, battery, and policy. Microsoft identifies item count and database
    size as major factors and warns that a rebuild is disruptive. Search mode,
    included/excluded paths, index status, corpus, query, expected result, and
    power state must remain recorded. [Search indexing in Windows][S36],
    [Windows Search performance issues][S37]

20. Microsoft 365 Apps update channel, version, and build define the Outlook
    binary under test. OneDrive and Teams have separate update mechanisms, so an
    Office channel alone does not identify their versions. [Microsoft 365 Apps
    update channels][S38], [Microsoft 365 Apps update history][S39]

### Edge, OneDrive, and Teams

21. Edge Startup Boost can start browser processes at OS sign-in and restart them
    in the background after the last window closes. It is supported on Windows
    from Edge 88. If enabled, closing all windows does not create a process-cold
    Edge launch. The state is visible in `edge://settings/system` and can be
    governed by the documented `StartupBoostEnabled` policy under
    `SOFTWARE\Policies\Microsoft\Edge`. [Edge StartupBoostEnabled policy][S40],
    [Startup Boost support][S41]

22. Edge background mode can start processes at sign-in and keep them running
    after the last browser window closes. It is supported on Windows from Edge
    77 and has a documented `BackgroundModeEnabled` policy. [Edge background-mode
    policy][S42]

23. Edge startup behavior can open a new tab, restore the previous session, or
    open controlled URLs. Profile, startup policy, page content, cache, extensions,
    sign-in/sync, and network state must be fixed. `edge://policy` is the supported
    view of effective policy. [Edge RestoreOnStartup policy][S43],
    [Configure Edge policy][S44], [Manage Edge extensions][S45]

24. Microsoft supports only the latest version in each Edge channel. The exact
    channel and version must be recorded for every collection series. [Edge
    deployment and lifecycle planning][S46]

25. OneDrive updates independently of Microsoft 365 Apps. It checks for updates
    while running, and a scheduled task can update it when it is not running.
    OneDrive update ring, version, sync state, Known Folder Move, Files On-Demand,
    and effective policy are required controls. The OneDrive sync health dashboard
    requires supported versions and tenant configuration and is optional rather
    than a prerequisite. [OneDrive update process][S47], [OneDrive policies][S48],
    [OneDrive sync health][S49]

26. Teams can auto-start and run in the background, and its user settings expose
    auto-start, background, and close behavior. Teams updates automatically when
    the app is idle. Installed version, sign-in, update state, auto-start,
    background, foreground, and meeting/call state must be recorded without
    suppressing normal managed behavior. [Teams settings][S50], [Update
    Teams][S51], [Deploy Teams with Microsoft 365 Apps][S52]

### Sleep, wake, power, and network

27. `powercfg` provides supported, read-only reports and queries for the active
    scheme, supported sleep states, wake-capable devices, last wake source, wake
    timers, outstanding power requests, battery, SleepStudy, sleep transitions,
    and system power. The selected commands depend on the actual sleep model and
    privileges. [Powercfg command-line options][S53]

28. Modern Standby uses the S0 low-power idle model. On a system designed for
    Modern Standby, S1-S3 are not used. Microsoft does not support switching
    between S3 and Modern Standby through a BIOS setting without a complete OS
    reinstallation. The lab must record `powercfg /a` and test the supported model
    as found. [Modern Standby][S54], [System power states][S55]

29. SleepStudy is available for Modern Standby systems. WPA and the
    `Microsoft-Windows-PDC` provider can attribute resume work, including device
    transition delays. Network and display devices are common analysis surfaces,
    but no device is a proven cause until traced on the selected system. [Modern
    Standby SleepStudy][S56], [Modern Standby resume performance][S57]

30. Starting with Windows 11 version 24H2, Windows can disable most wake sources
    after excessive battery drain during Modern Standby. Build, AC/DC power,
    battery state, wake source, dock state, and recent thermal/power history are
    necessary comparability controls. [Modern Standby wake sources][S58]

31. Windows power mode exposes efficiency, balanced, and performance choices, but
    availability and effect depend on the platform. Modern Standby systems use
    Balanced or derived plans. Energy Saver behavior changed in Windows 11
    version 24H2. The lab must record effective state; changing to a nominal
    “high performance” mode is not neutral baseline preparation. [Windows power
    mode][S59], [Power policy settings][S60], [Energy Saver][S61]

32. NCSI uses active and passive probes to classify local or Internet
    connectivity. On Windows 11 it is hosted by Network List Manager. A successful
    NCSI state does not prove that an enterprise DNS name, proxy, VPN, identity
    provider, or application endpoint is ready. Microsoft explicitly warns not
    to disable active probing as an NCSI repair. [NCSI overview][S62]

33. The inbox wireless network report covers the previous three days and includes
    adapter/driver information, IP configuration, profiles, connection sessions,
    and disconnect reasons. It is diagnostic context rather than a precise
    wake-to-ready stopwatch. [Wireless network report][S63]

34. Packet Monitor (`pktmon`) is an inbox Windows 10/11 cross-component tool for
    filtered packet capture, drop detection, event collection, and counters. Its
    component IDs are not persistent across reboots. If used, collection must be
    narrowly filtered, time-correlated, and reviewed for sensitive data.
    [Pktmon command reference][S64]

## HP, firmware, driver, and OEM findings

1. HP Image Assistant (HPIA) supports HP business computers and can analyze the
   system against an HP reference image for BIOS, driver, and HP software
   recommendations. Current vendor metadata lists HPIA 5.3.6 dated 2026-06-09 for
   Windows 10/11 and provides a supported-platform list. HPIA can return an
   unsupported-platform/OS condition; an analysis result is not universal support
   for every ZBook. Use **analyze/report only** for the baseline—do not download or
   install recommendations. [HPIA use][S65], [HPIA current version and supported
   platforms][S66]

2. Exact HP product number, system-board identifier, BIOS revision/date, dock
   model/firmware, storage/NVMe firmware, chipset/platform components, graphics,
   WLAN/LAN/Bluetooth, audio, camera, Thunderbolt/USB, and device driver
   version/provider/date are part of the environment record. HPIA support status
   and HP SoftPaq applicability must be retained with the report.

3. HP documents model-dependent graphics modes for newer ZBooks. Hybrid mode is
   the default on the cited systems, and discrete mode trades battery life for
   performance. Availability differs across Firefly, Power, Studio, and Fury
   families. The lab must record the effective mode and Windows per-application
   graphics choice; it must not assume or switch a mode before the baseline.
   [HP ZBook GPU operating modes][S67]

4. HP Power Manager features vary by supported system. On some models it exposes
   Smart Sense, Cool, Quiet, or Performance, with Performance requiring AC power.
   HP states that when System Control manages performance, Windows power modes do
   not operate. Record the installed component version, effective thermal/profile
   state, AC/DC state, and whether System Control is active. [HP Power Manager
   performance control][S68]

5. HP Support Assistant can check and automatically install driver and firmware
   updates on supported Windows systems. Record its version, policy/settings,
   running processes, task definitions, and whether an update is pending or was
   recently applied. Do not disable it or allow an unplanned update during a
   measurement series. [HP Support Assistant][S69]

6. HP Wolf Security components vary by commercial-PC configuration and can update
   automatically. Sure Click can isolate supported browser, Office, and PDF
   content in micro-virtual machines. Record the installed components, versions,
   policy, update state, relevant services/tasks/filter drivers, and whether the
   controlled content is isolated. Preserve the security control. [HP Wolf
   Security][S70], [HP Sure Click architecture][S71]

7. A documented HP Wolf/Sophos conflict applies to specific Sure Sense and Sophos
   Intercept X versions. It is not evidence of a general conflict. Compatibility
   findings must be matched to exact installed products and versions. [HP
   Wolf/Sophos compatibility notice][S72]

8. HP directs business-PC driver and BIOS maintenance through HP tools/support.
   Intel, AMD, and NVIDIA each caution that notebook/workstation OEM drivers can
   contain platform customizations; generic reference drivers are not a neutral
   replacement. The baseline must use the driver stack as found and record HP
   applicability rather than mass-update drivers. [HP business-PC updates][S73],
   [Intel OEM graphics guidance][S74], [AMD notebook driver guidance][S75],
   [NVIDIA notebook driver guidance][S76]

9. A future firmware change would require exact-platform support confirmation,
   AC power, recovery/BitLocker planning, original-state capture, management
   approval, and remeasurement after reboot. No firmware change is authorized in
   EXP-001. [HP BIOS update guidance][S77]

## Read-only configuration and compatibility matrix

| Surface | Supported state or option to record | Compatibility limit / baseline implication |
|---|---|---|
| Windows | Edition, release, build, update revision, architecture, install date, servicing state | Results apply only to the recorded build; select an ADK/WPT version that supports it. |
| WPR/WPA | Inbox WPR or WPT version; built-in or reviewed custom profile | Custom providers and stacks add overhead and data volume; validate overhead before measured runs. |
| Sign-in | Restart/sign-out/Fast Startup path, sign-in method, profile type, shell, policy mode | Restart, sign-out, shutdown/Fast Startup, domain policy, Hello, password, and cached credentials are different paths. |
| Startup | Registered startup apps, four documented Run/RunOnce locations, startup folders, logon-triggered tasks | Registration does not prove execution time or causality; retain command, signer, trigger, and trace evidence. |
| Outlook | Classic/new, channel/build, architecture, account/profile, cached/online, OST/PST, mailbox/index state, add-ins | Cached Exchange Mode and COM add-ins are classic-Outlook concepts; do not merge classic and new Outlook samples. |
| Windows Search | Classic/Enhanced, included paths, item count, index status, policy, `WSearch` state | Rebuild and service changes mutate the workload and are excluded. |
| Edge | Channel/version, Startup Boost, background mode, startup pages, profile, extensions, policy, cache/content/network | A window-closed launch is not process-cold when background processes remain. |
| OneDrive | Version/ring, account, sync state, KFM, Files On-Demand, policy, pending work | OneDrive updates separately from Office; dashboard support depends on tenant/version. |
| Teams | Version, account, auto-start/background/close/update/call state | Auto-update can change the binary; do not combine pre- and post-update runs. |
| Defender/security | Product/platform versions, real-time state, policy, filter drivers, update/scan activity | Do not add exclusions or disable protection. Use the performance analyzer only for attributed Defender work. |
| Scheduled work | Task definitions and recent results for Microsoft, app, management, security, and OEM tasks | Do not infer impact from task names and do not disable tasks to manufacture idle. |
| Power | AC/DC, battery %, active scheme/mode, Energy Saver, power requests, HP profile, temperature/fan/settling history | Windows and HP controls can interact; the displayed Windows mode may not be the controlling layer. |
| Sleep/wake | `powercfg /a`, transition used, wake source/timer/device, Modern Standby/DRIPS evidence | Do not switch S3/Modern Standby; SleepStudy applies only to Modern Standby. |
| Network | Adapter/driver, Wi-Fi/Ethernet/dock, SSID/BSSID/band/link rate where applicable, DHCP/DNS/gateway, proxy/VPN, NCSI, endpoint | NCSI “Internet” and application readiness are different endpoints; avoid production secrets in traces. |
| HP support | Exact product number, BIOS, HPIA supported-platform result, HP software/firmware/dock state | Run HPIA in analysis mode only; recommendations are not baseline changes. |
| Graphics | iGPU/dGPU versions, HP graphics mode, Windows per-app assignment, display/dock topology | Available modes are model-dependent and switching can change power, resume, and launch behavior. |

## Required read-only inventory

The validation lab should preserve command outputs or exported data with a UTC
timestamp, tool version, exit status, and structured log location. Collection
scripts belong to the later engineering stage and must meet repository support,
dry-run, verification, idempotence, rollback, and logging requirements.

### Device and platform

- HP product name, product number, SKU, serial handling identifier, system-board
  identifier, CPU, memory population, storage model/firmware/health, graphics
  devices, display topology, dock, BIOS revision/date, TPM/Secure Boot/BitLocker
  state as authorized, and HPIA platform-support result.
- PnP device instance, provider, signer, driver version/date, status, and hardware
  IDs for storage, chipset/platform, graphics, network, Bluetooth, audio,
  Thunderbolt/USB, dock, and any device with an error.
- Active filter drivers and network bindings. Do not remove a filter to simplify
  the trace.

### Windows, management, security, and updates

- Windows edition, display version, build/revision, architecture, install/boot
  time, cumulative update state, pending reboot indications, locale/time zone,
  domain/Entra/workgroup state, and management authority.
- Effective Group Policy and MDM policy reports, including sign-in scripts,
  synchronous processing, startup, Defender, update, Delivery Optimization,
  Search, OneDrive, Edge, and power policy when present.
- Service name, display name, startup type, current state, executable path, account,
  and signer. Focus analysis on services actually active in the traces; do not use
  a generic disable list.
- Complete scheduled-task definitions and recent run metadata. Preserve Microsoft,
  management, update, security, app, driver, and HP tasks.
- Installed endpoint protection/EDR, encryption, VPN, DLP, credential, HP Wolf,
  backup, and management-agent versions and effective states.
- Windows Update, Store, Defender intelligence/platform, Microsoft 365 Apps,
  Edge, Teams, OneDrive, HPIA/HP Support Assistant update states and timestamps.

### Applications and workload data

- Outlook variant, architecture, update channel/build, account/profile type,
  cached/online mode where applicable, OST/PST and mailbox characteristics,
  indexing state, add-in inventory, event 45 observations, launch arguments, and
  approved test data/query.
- Edge channel/version, update state, process state before launch, profile, sync,
  extensions, `edge://policy`, Startup Boost/background mode/startup action,
  controlled page, cache definition, and first-interaction action.
- Windows Search surface, Classic/Enhanced state, included/excluded paths, policy,
  index count/status, approved corpus, exact query, and expected result.
- OneDrive and Teams versions, sign-in, startup, background, sync/update/activity,
  policy, and approved test content.

### Power, thermal, network, and run conditions

- AC/DC source, adapter rating, battery percentage/health, active Windows scheme
  and mode, Energy Saver, HP performance/thermal mode, power requests, sleep
  model, wake-capable devices, last wake, wake timers, and SleepStudy availability.
- Ambient conditions, inlet/system temperatures exposed by approved tooling, fan
  state where observable, clock/power limits where supported, prior workload,
  settling duration, and thermal-throttling evidence.
- Network medium/path, adapter/driver, dock, profile, SSID/BSSID/band/link rate
  where applicable, DHCP address state, DNS/gateway, proxy/VPN/captive portal,
  NCSI classification, signal and disconnect evidence, and the approved endpoint
  used for readiness.

## Measurement implications for the design handoff

These are candidate requirements, not validated measurement definitions.

| Workflow | Start candidate | Readiness candidate | Reset and control issues still requiring validation |
|---|---|---|---|
| Sign-in to usable desktop | Explicit user completion of the agreed credential action, correlated to ETW | Instrumented probe confirms Explorer shell/taskbar and the agreed customer action responds | Restart vs sign-out vs Fast Startup; policy/profile path; startup and update activity; no subjective-only endpoint |
| Outlook cold launch | Controlled launch action with process start correlation | Agreed main window/content rendered and responsive | Prove no Outlook process remains; define profile/data/network/index/add-in state |
| Outlook warm launch | Controlled launch after a fixed prior run and close/settle sequence | Same visible readiness probe as cold launch | Define cache-preserving reset; confirm background processes and add-ins |
| Outlook search readiness | Submission of one approved fixed query | Expected result becomes visible and actionable | Variant; cached/online mode; corpus/index status; server/network dependence |
| Edge cold launch | Controlled launch with process start correlation | Fixed local or controlled page rendered and agreed interaction succeeds | Ensure no Edge processes remain or rename the workload; Startup Boost/background mode; extensions/cache/network |
| Edge first interaction | Agreed input marker after the controlled page appears | Observable response to a fixed action | Define page/content and animation/network completion without relying on visual judgment alone |
| Windows Search | Submission of one fixed query in one named Search surface | Expected approved local result visible and actionable | Fix Classic/Enhanced mode, index/corpus/status, power and user-activity throttling |
| Wake to network-ready | Agreed physical wake input with power-transition correlation | Approved DNS and application-relevant endpoint probe succeeds | Specify sleep model, medium, dock/VPN/proxy, NCSI vs endpoint, cache, AP/path, and timeout/failure classification |
| Idle CPU/memory/disk | End of a fixed settling period after all prescribed foreground actions | Complete fixed observation window | “Idle” must not mean disabled services/tasks; retain maintenance, sync, scan, update, thermal and power observations |

Every endpoint must be validated against ETW or another monotonic instrumented
marker. Human stopwatch timing may be retained as an observation but cannot be
the sole measurement. The design must specify repetitions, randomized or
counterbalanced run order where appropriate, warm-ups, failure rules, and a
predeclared treatment of interrupted runs. Raw samples and dispersion must be
retained; the median is the required headline result.

## Lab measurements

No lab system was made available and no benchmark artifacts were present in the
repository. No commands were run against a candidate ZBook. Consequently:

| Required result | Current status |
|---|---|
| Windows sign-in to usable desktop | Not measured |
| Outlook cold launch | Not measured |
| Outlook warm launch | Not measured |
| Outlook search readiness | Not measured |
| Edge cold launch | Not measured |
| Edge first-interaction readiness | Not measured |
| Windows Search response | Not measured |
| Wake to network-ready | Not measured |
| Idle CPU, memory, and disk activity | Not measured |
| Instrumentation overhead | Not measured |
| Repeated raw runs and medians | Not available |

No timing, utilization value, improvement, bottleneck, or causal claim is made.

## Hypotheses for later testing

The following are deliberately unconfirmed:

1. Sign-in variability may correlate with synchronous management processing,
   profile work, logon-triggered tasks, startup applications, per-user services,
   update/security work, or application auto-start.
2. Outlook cold/warm launch and search variability may correlate with Outlook
   variant, profile/data size, cached/online mode, add-ins, Windows Search state,
   endpoint protection, storage I/O, or network path.
3. Edge “cold” launch may not be process-cold if Startup Boost or background mode
   is active; extension, profile, startup-content, sync, and update state may
   explain part of the observed variation.
4. Idle resource use may correspond to legitimate indexing, sync, maintenance,
   update, security, management, or OEM work rather than unnecessary software.
5. Wake-to-network variability may correlate with sleep model, NIC/graphics/dock
   device transitions, access point association, DHCP/DNS, proxy/VPN, NCSI, power
   policy, or firmware/driver state.
6. HP performance/thermal management and graphics mode may change the effective
   behavior attributed to Windows power mode.

Each hypothesis requires time-correlated evidence. None authorizes a change.

## Unresolved questions and evidence gaps

1. Which exact HP ZBook product number and configuration is reserved?
2. What BIOS, dock, storage, chipset, graphics, network, and other driver/firmware
   versions are installed, and does HPIA report the platform as supported?
3. Which Windows 11 edition, release, build/revision, servicing state, management
   authority, security stack, and pending-reboot state are in scope?
4. Which Outlook variant/build, profile/account, data set, add-ins, index state,
   query, and expected result define the Outlook workloads?
5. Which Edge build/profile, extensions, policies, process/caching state,
   controlled page, and interaction define cold launch and first readiness?
6. Which Search surface, mode, corpus, status, query, and result define Windows
   Search response?
7. Which OneDrive and Teams versions and foreground/background/sync/update states
   are part of each workflow?
8. What observable, instrumented event defines usable desktop and each
   application readiness point?
9. Which supported sleep state, wake action, network path, and application-relevant
   endpoint define network-ready?
10. What run count, run order, warm-up, settling interval, timeout, failure
    classification, and dispersion measures will be predeclared?
11. What WPR/ETW profile and auxiliary tools produce sufficient evidence with
    acceptable measured overhead?
12. How will power, battery, HP profile, thermal history, ambient state, network,
    maintenance, update, scan, sync, and management activity be controlled or
    recorded without disabling them?
13. What approved synthetic data replaces production mail, browser history,
    documents, credentials, and collaboration content?
14. What reproducibility or customer-impact decision rule permits handoff to a
    narrower causal experiment?

## Security, update, management, and rollback constraints

- Preserve Defender/EDR, firewall, encryption, Secure Boot, BitLocker, HP Wolf,
  DLP, VPN, identity, management, update, backup, and recovery controls.
- Do not add antivirus exclusions, stop or delete services/tasks, remove startup
  entries, uninstall OEM software, clear search/mail/browser data, or force a
  generic driver/BIOS solely to improve a baseline number.
- Schedule a documented lab window to avoid an update crossing a measurement
  series. Do not disable the update mechanism. If any binary or firmware changes,
  close the series and start a newly identified configuration.
- Obtain management/security approval before collecting ETL, packet, mailbox,
  browser, identity, device serial, or policy data. Use approved synthetic content,
  restrict access, and define retention/redaction.
- Read-only inventory and tracing have no configuration rollback. Temporary
  tracing sessions must still have explicit stop/cleanup handling and verified
  output locations.
- Any later change proposal must independently provide support detection,
  original-state capture, dry-run, application, verification, structured logging,
  idempotence, rollback, and reboot-persistence testing where applicable.

## Research-to-design gate

The gate is **not satisfied**. Before replacing `stage:research` with
`stage:design`, the repository must contain:

1. the exact system and complete environment record;
2. validated start, readiness, reset, and control definitions for all nine
   workflows;
3. a supported instrumentation plan with measured overhead;
4. repeated raw runs, preserved failed/rejected/inconclusive runs, and medians;
5. variability and limitation reporting; and
6. a reproducibility/decision rule accepted for Experiment Design.

## Primary source register

All sources were retrieved 2026-07-25.

[S01]: https://learn.microsoft.com/en-us/windows-hardware/test/wpt/
[S02]: https://learn.microsoft.com/en-us/windows-hardware/test/wpt/event-tracing-for-windows
[S03]: https://learn.microsoft.com/en-us/windows-hardware/test/wpt/wpr-reference
[S04]: https://learn.microsoft.com/en-us/windows-hardware/test/assessments/windows-assessment-console-overview
[S05]: https://learn.microsoft.com/en-us/windows-hardware/test/assessments/assessments
[S06]: https://learn.microsoft.com/en-us/windows-hardware/test/wpt/optimizing-performance-and-responsiveness-exercise-2
[S07]: https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install
[S08]: https://learn.microsoft.com/en-us/windows-hardware/get-started/what-s-new-in-kits-and-tools
[S09]: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
[S10]: https://learn.microsoft.com/en-us/windows-hardware/test/assessments/minifilter-diagnostics
[S11]: https://learn.microsoft.com/en-us/windows-hardware/drivers/ifs/about-file-system-filter-drivers
[S12]: https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys
[S13]: https://support.microsoft.com/en-us/windows/experience/startup-boot/configure-startup-applications-in-windows
[S14]: https://learn.microsoft.com/en-us/windows/compatibility/startup-apps
[S15]: https://learn.microsoft.com/en-us/windows/win32/taskschd/starting-an-executable-when-a-user-logs-on
[S16]: https://learn.microsoft.com/en-us/windows/application-management/per-user-services-in-windows
[S17]: https://learn.microsoft.com/en-us/windows/win32/secauthn/responsibilities-of-winlogon
[S18]: https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/jj649075(v=ws.11)
[S19]: https://learn.microsoft.com/en-us/previous-versions/windows/desktop/policy/initial-processing-of-group-policy
[S20]: https://learn.microsoft.com/en-us/troubleshoot/windows-client/group-policy/logon-scripts-not-run-for-long-time
[S21]: https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-admx-grouppolicy
[S22]: https://learn.microsoft.com/en-us/windows/win32/taskschd/task-maintenence
[S23]: https://learn.microsoft.com/en-us/windows/win32/taskschd/about-the-task-scheduler
[S24]: https://learn.microsoft.com/en-us/windows/deployment/do/delivery-optimization-workflow
[S25]: https://learn.microsoft.com/en-us/windows/deployment/do/waas-delivery-optimization-reference
[S26]: https://learn.microsoft.com/en-us/microsoft-365-apps/updates/delivery-optimization
[S27]: https://learn.microsoft.com/en-us/defender-endpoint/tune-performance-defender-antivirus
[S28]: https://learn.microsoft.com/en-us/defender-endpoint/configure-contextual-file-folder-exclusions-microsoft-defender-antivirus
[S29]: https://support.microsoft.com/en-us/outlook/turn-on-cached-exchange-mode
[S30]: https://support.microsoft.com/en-us/outlook/how-to-troubleshoot-performance-issues-in-outlook
[S31]: https://support.microsoft.com/en-us/outlook/fix-search-issues-by-rebuilding-your-instant-search-catalog
[S32]: https://support.microsoft.com/en-us/outlook/why-is-desktop-search-service-unavailable
[S33]: https://support.microsoft.com/en-us/outlook/outlook-add-in-warnings
[S34]: https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/performance/log-entries-for-add-ins
[S35]: https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/get-started/create-add-in-inventory
[S36]: https://support.microsoft.com/en-us/windows/experience/performance-optimization/search-indexing-in-windows
[S37]: https://learn.microsoft.com/en-us/troubleshoot/windows-client/shell-experience/windows-search-performance-issues
[S38]: https://learn.microsoft.com/en-us/microsoft-365-apps/updates/overview-update-channels
[S39]: https://learn.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date
[S40]: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/startupboostenabled
[S41]: https://support.microsoft.com/en-us/edge/get-help-with-startup-boost
[S42]: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/backgroundmodeenabled
[S43]: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-policies/restoreonstartup
[S44]: https://learn.microsoft.com/en-us/deployedge/configure-microsoft-edge
[S45]: https://learn.microsoft.com/en-us/deployedge/microsoft-edge-manage-extensions
[S46]: https://learn.microsoft.com/en-us/deployedge/deploy-edge-plan-deployment
[S47]: https://learn.microsoft.com/en-us/sharepoint/sync-client-update-process
[S48]: https://learn.microsoft.com/en-us/sharepoint/use-group-policy
[S49]: https://learn.microsoft.com/en-us/sharepoint/sync-health
[S50]: https://support.microsoft.com/en-us/teams/notifications-settings/change-settings-in-microsoft-teams
[S51]: https://support.microsoft.com/en-us/teams/notifications-settings/update-microsoft-teams
[S52]: https://learn.microsoft.com/en-us/microsoft-365-apps/deploy/teams-install
[S53]: https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options
[S54]: https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby
[S55]: https://learn.microsoft.com/en-us/windows/win32/power/system-power-states
[S56]: https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-sleepstudy
[S57]: https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-resume-performance
[S58]: https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-wake-sources
[S59]: https://support.microsoft.com/en-us/windows/change-the-power-mode-for-your-windows-pc-c2aff038-22c9-f46d-5ca0-78696fdf2de8
[S60]: https://learn.microsoft.com/en-us/windows/win32/power/power-policy-settings
[S61]: https://learn.microsoft.com/en-us/windows-hardware/design/component-guidelines/energy-saver
[S62]: https://learn.microsoft.com/en-us/windows-server/networking/ncsi/ncsi-overview
[S63]: https://support.microsoft.com/en-us/windows/experience/connectivity-networking/analyze-the-wireless-network-report
[S64]: https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/pktmon
[S65]: https://support.hp.com/us-en/document/ish_7636709-7636753-16
[S66]: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html
[S67]: https://support.hp.com/us-en/document/ish_11059579-11059627-16
[S68]: https://support.hp.com/in-en/document/ish_5180936-5180983-16
[S69]: https://support.hp.com/us-en/help/hp-support-assistant
[S70]: https://support.hp.com/in-en/document/ish_6704518-6704563-16
[S71]: https://h20195.www2.hp.com/v2/GetDocument.aspx?docname=4AA7-4555ENW
[S72]: https://support.hp.com/gb-en/document/ish_4025840-4025768-16
[S73]: https://support.hp.com/us-en/document/ish_2850716-2380784-16
[S74]: https://www.intel.com/content/www/us/en/support/articles/000038757/graphics.html
[S75]: https://www.amd.com/en/resources/support-articles/release-notes/RN-RAD-WIN-24-5-1.html
[S76]: https://nvidia.custhelp.com/app/answers/detail/a_id/2085
[S77]: https://support.hp.com/us-en/document/ish_4208192-2358829-16

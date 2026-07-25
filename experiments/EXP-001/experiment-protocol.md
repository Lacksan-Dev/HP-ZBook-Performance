# EXP-001 Experiment Protocol: HP ZBook Responsiveness Baseline

## Protocol control

- Experiment: `EXP-001`
- Source issue: `#1`
- Priority: P1 (High)
- Release status: Experimental
- Protocol purpose: establish a reproducible untreated baseline before any calibration is evaluated
- Formal evidence rule: existing synthetic or screening observations remain excluded from the formal baseline series

## Objective

Create a controlled, repeatable baseline for customer-visible Windows responsiveness on one lab-controlled HP ZBook running Windows 11. The protocol measures current-state behavior only. It does not authorize tuning changes or customer performance claims.

## Testable hypothesis

Under fixed hardware, software, power, thermal, network, application, profile, and background-workload conditions, repeated measurements of each defined workflow will produce a stable median and visible run-to-run dispersion that are sufficient to support a later causal calibration experiment.

The hypothesis is supported only when every required workflow completes the planned valid repetitions and satisfies the reproducibility gate defined below.

## Control state

The control is the selected HP ZBook in its observed, supported, managed state before any Lacksan calibration.

The following must remain unchanged throughout a formal series:

- Windows edition, release, build, cumulative update, and architecture
- BIOS and firmware
- device drivers
- Microsoft 365, Outlook, Edge, OneDrive, and Teams versions
- Outlook variant, profile, mailbox/data set, cache mode, add-ins, and search state
- Edge channel, profile, extensions, startup behavior, cache treatment, and test content
- Windows Search mode, corpus, index status, query, and expected result
- OneDrive and Teams sign-in, startup, sync, update, foreground, and background states
- Defender, firewall, encryption, recovery, management, and HP security controls
- dock, displays, peripherals, network adapter, and network path
- power source, Windows power mode, battery state band, and Energy Saver state
- room conditions and thermal preparation

No service, task, policy, registry value, startup item, security control, application option, BIOS setting, or driver may be changed during the baseline series.

## Independent variable

For EXP-001 the independent variable is workflow condition, with no tuning treatment applied.

Formal conditions are:

1. Windows sign-in to usable desktop
2. Outlook process-cold launch
3. Outlook warm launch
4. Outlook search readiness
5. Edge process-cold launch
6. Edge first-interaction readiness
7. Windows Search response
8. Resume to network-ready
9. Idle resource activity

OneDrive and Teams state is a controlled condition, rather than an independent variable, unless a later experiment explicitly isolates either application.

## Dependent variables

For each timing workflow:

- elapsed time from the defined monotonic start marker to the defined readiness marker
- success, failed, interrupted, or invalid classification
- CPU, disk, memory, and network activity during the observation window where instrumentation supports collection

For idle:

- median CPU utilization over the observation window
- committed memory and available memory
- disk active time, throughput, and I/O count where available
- network throughput where available
- process-level contributors when ETW or counters identify them

## Operational definitions

### 1. Sign-in to usable desktop

Start marker: successful credential submission or the earliest monotonic Winlogon marker available in the selected instrumentation profile.

Readiness marker: Explorer shell present, taskbar and Start responsive, and a scripted local readiness probe completes successfully. The probe must avoid network access and must record its own duration.

Reset: restart the device, wait at the sign-in screen for the fixed pre-run interval, then begin the run.

### 2. Outlook process-cold launch

Start marker: scripted process-launch timestamp.

Readiness marker: the Outlook main window is responsive and the agreed local folder or view is displayed. Network-dependent mailbox synchronization must be recorded separately from local window readiness.

Reset: close Outlook, verify all Outlook processes have exited, preserve the agreed profile and cache state, then apply the fixed settling interval. Classic Outlook and new Outlook require separate series.

### 3. Outlook warm launch

Start marker: scripted process-launch timestamp after one completed launch in the same Windows session.

Readiness marker: same local window-readiness condition as the cold series.

Reset: close Outlook, verify process exit, retain warmed file-system and application caches, then apply the fixed settling interval.

### 4. Outlook search readiness

Start marker: scripted submission of the fixed search query after Outlook local readiness.

Readiness marker: the agreed expected result is rendered and the result surface accepts scripted focus or selection.

Reset: use the same approved lab mailbox, folder, query, index state, and Outlook variant for every run. Index rebuilds and repair actions are prohibited.

### 5. Edge process-cold launch

Start marker: scripted process-launch timestamp.

Readiness marker: the controlled local test page is rendered and the scripted first interaction completes.

Reset: close Edge, verify all Edge processes have exited, and verify Startup Boost and background-mode process state as found and recorded. A process-cold series requires zero remaining Edge processes. Policy or setting changes are prohibited during baseline collection.

### 6. Edge first-interaction readiness

Start marker: browser launch timestamp.

Readiness marker: the fixed scripted interaction on the controlled page completes.

Reset: same Edge profile, extension state, startup policy, cache treatment, page content, and process-state rule for every run.

### 7. Windows Search response

Start marker: scripted query submission in the selected Windows Search surface.

Readiness marker: the agreed expected indexed result appears and accepts selection.

Reset: fixed corpus, query, expected result, index mode, index status, power state, and settling interval. Index rebuilds are prohibited.

### 8. Resume to network-ready

Start marker: first monotonic resume marker available after the selected supported sleep transition.

Readiness marker: the selected adapter has a valid route and the fixed local or lab-controlled endpoint responds according to the predefined probe. Internet classification alone is insufficient.

Reset: use the supported sleep model reported by `powercfg /a`, the same sleep duration, adapter, dock state, access point, network path, and power source.

### 9. Idle resource activity

Start marker: end of the fixed post-sign-in or post-workload settling interval.

Readiness/end marker: completion of the fixed observation window.

Reset: no foreground interaction; fixed OneDrive, Teams, update, indexing, Defender, maintenance, and network conditions. Unexpected maintenance or update activity invalidates the run but remains preserved in raw evidence.

## Benchmark procedure

### Phase A: enrollment and protocol lock

Before measured collection, record every required metadata field and complete the readiness checklist. Freeze application updates and OS servicing only through the lab's approved maintenance-window process. Do not disable update services or security controls.

Create a protocol-lock record containing:

- repository commit SHA for the collector and protocol
- collector version and file hashes
- WPT/ADK version
- exact workload definitions
- exact reset steps
- exact run order
- exact readiness probes
- exact data-set identifiers

A formal series cannot begin until this record is complete.

### Phase B: instrumentation-overhead qualification

For each representative timing class, perform paired screening runs with the minimum timing probe and with the full ETW/counter profile.

- Minimum pairs: 3 per representative class
- Compare paired medians and raw deltas
- Full instrumentation is accepted when its median added duration is no greater than 5% of the minimally instrumented median and no greater than 100 ms, whichever is more permissive
- If the threshold is exceeded, use the minimum probe for formal timing and collect full traces in separate diagnostic runs

These qualification runs are screening evidence and remain excluded from formal workflow medians.

### Phase C: warm-up

Perform one unreported warm-up for every workflow after enrollment, collector installation, application update, Windows update, BIOS/driver change, or protocol change.

Warm-ups are preserved and labeled `warm-up`; they are excluded from the formal median.

### Phase D: measured collection

For every workflow:

1. Verify metadata and control-state checks.
2. Execute the exact reset procedure.
3. Wait the fixed settling interval.
4. Start the minimum timing probe and required supporting instrumentation.
5. Execute one workflow run.
6. Classify the run.
7. Preserve raw logs, traces, counters, screenshots where required, and hashes.
8. Restore the defined reset state before the next run.

Run order must be generated before collection using a recorded random seed, while respecting reboot and sleep prerequisites. Consecutive runs of the same workflow are permitted only where reset cost requires blocking; the chosen design must be recorded before data collection.

## Repetition count

- Minimum valid measured repetitions per workflow: 7
- Maximum attempted repetitions per workflow before design review: 10
- Warm-up runs: 1 minimum, excluded from the formal median
- Instrumentation-overhead screening: separate from formal repetitions

When fewer than 7 valid runs remain after classification, the series is incomplete and cannot pass.

## Run classification

- Valid: all control checks pass, start and readiness markers are present, no prohibited state change occurs, and required evidence is complete
- Failed: the workflow reaches a clear failure state
- Interrupted: operator, power, application, or external interruption prevents completion
- Invalid: a control violation, update, maintenance event, thermal breach, network-path change, missing marker, or collector fault makes the timing incomparable

Every attempted run remains preserved. Failed, interrupted, and invalid runs are excluded from the formal median and reported separately with reasons. Runs may never be silently discarded.

## Median calculation

For each workflow:

1. Sort all valid elapsed-time samples in ascending order.
2. For an odd count, report the middle value.
3. For an even count, report the arithmetic mean of the two middle values.
4. Report raw valid samples beside the median.
5. Also report minimum, maximum, median absolute deviation, and count of valid, failed, interrupted, and invalid runs.

No outlier removal is allowed during EXP-001. Extreme values remain in the valid set unless a documented control violation changes their classification.

## Success threshold

EXP-001 succeeds as a baseline protocol when all conditions below are met:

- all 9 workflows have at least 7 valid measured runs
- all required metadata and raw evidence are present
- all attempted runs are classified and preserved
- instrumentation overhead is qualified or separated from formal timing
- readiness probes are deterministic and produce no ambiguous endpoints
- for each timing workflow, median absolute deviation is no greater than 10% of the workflow median
- no application, OS, driver, BIOS, policy, security, or management state changes occur during a formal series
- independent review can reproduce the median from the raw files

This threshold establishes baseline reproducibility only. It does not establish a performance improvement.

## Failure threshold

The protocol fails when any condition below occurs:

- a workflow cannot produce 7 valid runs within 10 attempts
- start or readiness markers remain ambiguous
- median absolute deviation exceeds 20% of the workflow median after control review
- instrumentation materially alters timing and cannot be separated
- required control state cannot be held or recorded
- raw evidence is incomplete or cannot reproduce the reported median
- a prohibited system or application change occurs during the formal series
- a security, management, encryption, recovery, or support control must be weakened to execute the protocol

## Inconclusive threshold

The outcome is inconclusive when:

- median absolute deviation is greater than 10% and no greater than 20%
- environmental or network variability remains plausible after controls
- the workflow endpoint is technically observable but weakly aligned with customer readiness
- the selected device or data set becomes unavailable before completion

An inconclusive result returns to Design for refinement and remains preserved.

## Environmental controls

### Power

- Use AC power for the primary baseline unless the issue explicitly authorizes a battery series
- Record charger wattage and dock power-delivery path
- Record battery percentage before every run; keep within a predeclared 20-percentage-point band
- Record Windows power mode and Energy Saver state

### Thermal

- Use the same room and surface
- Record ambient temperature when a reliable sensor is available
- Begin each run only after the fixed idle-settling interval and when the selected CPU temperature or package-power indicator is within the predeclared readiness band
- Record fan state where observable
- Invalidate runs affected by thermal throttling or a readiness-band breach

### Network

- Use the same adapter, access point or switch, SSID/VLAN where applicable, DNS path, and endpoint
- Record link speed and signal strength for wireless runs
- Prefer a lab-controlled local endpoint for readiness probes
- Prohibit network-path changes during a formal series

### Background workload

- Record OneDrive, Teams, Defender, Windows Search, Windows Update, Delivery Optimization, maintenance, and HP utility state
- Preserve managed behavior as found
- Invalidate rather than suppress runs contaminated by unexpected update or maintenance activity

### Human interaction

- Use scripted actions wherever practical
- Keep operator interaction outside measured windows
- Record any manual action and timestamp

## Recorded system metadata

Required before each formal series:

- HP product name, product number, serial identifier or anonymized lab asset ID
- CPU, memory capacity/configuration, storage model/firmware/health, GPU
- BIOS and firmware versions
- Windows edition, release, build, architecture, cumulative update, install type
- Secure Boot, BitLocker or device-encryption state, virtualization-based security, Defender platform, firewall, management enrollment, domain/Entra state
- all relevant chipset, storage, graphics, network, audio, Bluetooth, dock, and Thunderbolt/USB4 driver versions
- installed HP utilities and versions
- Outlook variant, architecture, channel, version/build, profile type, account type, cache mode, add-ins, mailbox/data-set identifier, OST/PST size where applicable, index state
- Edge channel, version, profile identifier, extension list, Startup Boost/background-process state, policy snapshot, cache treatment, test-page hash
- Windows Search mode, indexed locations, corpus identifier, item count where available, query, expected result, service state
- OneDrive and Teams versions, sign-in, startup, sync/update/background states
- WPT/ADK version and collector hashes
- power source, charger/dock path, power mode, battery percentage, Energy Saver state
- supported sleep states, wake source, adapter, network path
- ambient and device thermal indicators
- connected displays and peripherals
- date, local time, operator or automation identity, repository commit SHA

## Risks

- A single ZBook provides protocol evidence rather than fleet-wide generalization.
- Scripted readiness may diverge from perceived customer readiness.
- Network, synchronization, indexing, security scanning, maintenance, and updates may invalidate runs.
- Instrumentation may alter the workload.
- Real mailbox or browser data may create handling risk; approved lab data is required.
- Existing pre-protocol engineering artifacts may bias operator expectations and must remain separated from the formal baseline.
- Application or Windows updates can split a series into incompatible configurations.
- Repeated restart and sleep cycles may expose unrelated platform instability.

## Verification requirements for engineering

The Engineering stage must produce a collector and harness that verifies before every run:

- supported Windows and HP platform identity
- required application variants and versions
- collector integrity and version
- exact control-state match
- process state for Outlook and Edge
- Windows Search service and index state
- OneDrive and Teams state
- power, battery, thermal, network, dock, display, and peripheral conditions
- required evidence paths and available storage

After each run it must verify:

- start and readiness markers exist
- all logs and traces closed successfully
- hashes and run manifest were written
- run classification is explicit
- no prohibited state mutation occurred

## Original-state capture

Although EXP-001 is observational, Engineering must capture the original state of every surface it reads or temporarily configures, including:

- ETW/WPR sessions and profiles
- performance-counter sessions
- temporary scheduled tasks or startup hooks created solely for measurement
- firewall rules or local endpoints created solely for lab probing
- temporary files, folders, environment variables, certificates, services, or event-log channels used by the harness

The collector must avoid persistent configuration where a read-only method exists.

## Dry-run requirement

A dry run must:

- perform support and prerequisite checks
- display the exact workflow, commands, collectors, output paths, reset steps, and temporary resources
- make zero system changes
- start zero formal benchmark runs
- write only a dry-run report in the chosen output directory

## Rollback test

Before formal collection, Engineering must demonstrate rollback in a disposable or approved lab session:

1. Capture original state.
2. Apply only the temporary instrumentation resources required by the harness.
3. Verify those resources exist and function.
4. Execute rollback.
5. Verify every temporary resource is removed or restored exactly.
6. Compare the post-rollback state against the captured state.
7. Preserve the rollback manifest and result.

Rollback passes only when the comparison reports zero unexplained differences.

## Reboot-persistence test

Any temporary resource intended to persist across restart must be tested through one restart cycle before formal collection. The test must confirm:

- intended resources persist
- unintended resources do not appear
- collection resumes only through an explicit approved trigger
- rollback after restart restores the captured state

## Idempotence requirement

Repeated preparation and rollback must produce the same verified state without duplicate tasks, sessions, files, firewall rules, services, or configuration entries.

## Stop conditions

Stop the current run immediately when:

- a security, management, encryption, recovery, or update control changes unexpectedly
- Windows, an application, a driver, BIOS, or firmware updates
- thermal throttling occurs or the thermal readiness band is breached
- AC power, dock state, adapter, access point, network path, display, or peripheral state changes
- required start/readiness markers fail
- storage capacity becomes insufficient
- the collector reports integrity failure
- unexpected personal or production data appears
- a crash, bugcheck, application hang, or data-integrity concern occurs

Stop the entire formal series and return to Design when:

- 7 valid runs cannot be achieved within 10 attempts
- instrumentation overhead cannot be qualified or separated
- the control state cannot be held
- rollback produces an unexplained difference
- endpoint definitions require revision

## Engineering handoff

Engineering is authorized to implement the observational baseline collector and harness only. It may add support detection, inventory, readiness probes, timing, ETW/counter collection, manifests, hashing, dry-run, temporary-resource setup, verification, idempotence checks, reboot-persistence checks, and exact rollback.

Engineering is not authorized to apply performance tuning, disable or weaken Windows/HP/security/management controls, alter application behavior for advantage, merge existing pre-protocol tuning work into the formal baseline, or claim customer improvement.

Existing synthetic, screening, or tuning artifacts must be placed outside the formal baseline evidence path and clearly labeled pre-protocol.

## Design gate decision

This protocol is executable once Engineering supplies the collector and harness defined above. Every permitted temporary modification has original-state capture, dry-run, verification, idempotence, rollback, rollback verification, and stop conditions.

Advance to `stage:engineering` for implementation of the observational collector only.

# EXP-001 Research Brief: HP ZBook Responsiveness Baseline

## Brief control

- Experiment: `EXP-001`
- Source issue: `#1`
- Owner at handoff: Windows Research
- Status: Experimental
- Priority: P1 (High)
- Stage on completion of this brief: Research

### Priority rationale

This baseline is a prerequisite for evaluating later Windows calibration work. Without a repeatable current-state record, the lab cannot distinguish a measured improvement from normal run-to-run variation. The work is high priority, but it is not classified as P0 because the intake does not describe an outage, safety event, security incident, or other emergency.

## Refined customer problem

Office users report that an HP ZBook can feel slow to become usable after Windows sign-in and can respond slowly around common Outlook, Edge, Windows Search, OneDrive, and Teams activity. The intake does not yet establish which delay is most important, how each readiness point is defined, which system or software versions are affected, or whether the delays are reproducible.

The immediate research problem is therefore to establish a controlled, repeatable current-state baseline on one representative HP ZBook. The baseline must turn the reported experience into operationally defined timings and resource-activity observations before any calibration is applied.

## Business value

A trustworthy baseline will:

- provide a defensible comparison point for later experiments;
- prevent normal variability from being presented as a performance improvement;
- focus engineering effort on customer-visible workflows;
- expose missing environment or workload controls before tuning work begins; and
- support evidence-based go, revise, or stop decisions without making premature performance claims.

No monetary benefit, time saving, or performance improvement is claimed at this stage.

## Scope

### Included

- Record one HP ZBook's current hardware, firmware, driver, Windows, application, power, thermal, network, and benchmark conditions.
- Define and measure the following current-state workflows:
  - Windows sign-in to usable desktop;
  - Outlook cold launch;
  - Outlook warm launch;
  - Outlook search readiness;
  - Edge cold launch;
  - Edge first-interaction readiness;
  - Windows Search response;
  - wake to network-ready; and
  - idle CPU, memory, and disk activity.
- Treat OneDrive and Teams as controlled foreground or background conditions where their activity can affect the listed workflows.
- Preserve raw results, use repeated runs, and report the median.
- Capture observations needed to decide whether a narrower follow-on experiment is justified.

### Excluded

- Applying or recommending Windows, BIOS, driver, application, policy, service, startup, power, or registry changes.
- Comparing tuned and untuned configurations.
- Hardware replacement or upgrade evaluation.
- Claims that the selected device represents every HP ZBook or every user.
- Cross-model, cross-vendor, or fleet-wide conclusions.
- Windows 10, Windows Server, non-Windows operating systems, virtual machines, and non-HP systems.
- Standalone OneDrive sync-speed or Teams call-quality benchmarking.
- Battery endurance, graphics rendering, sustained compute, gaming, and local-AI throughput testing.
- Production release, customer-facing performance claims, or assignment of Stable status.

## Target environment

### Windows versions

- Target family: Windows 11.
- Target configuration for this experiment: one installed Windows 11 edition, release, and OS build on the selected lab system.
- Windows Research must record the exact edition, release, OS build, update state, and relevant security or servicing configuration before the first measured run.
- Results apply only to the recorded build. Additional Windows 11 releases or builds require separate validation.

### HP systems

- One lab-controlled HP ZBook business or workstation laptop selected as the representative baseline system.
- The exact product name/model, processor, memory, storage, graphics, BIOS, and relevant driver versions must be recorded before testing.
- No other HP model or configuration is in scope until the baseline protocol is proven.

### Applications

- Microsoft Outlook: the installed Outlook product/variant, update channel, version, profile type, and mailbox/data conditions must be recorded.
- Microsoft Edge: the installed channel, version, profile, extension state, and test-page conditions must be recorded.
- Windows Search: the Windows-integrated search experience used by the agreed workflow.
- Microsoft OneDrive and Microsoft Teams: installed versions and activity states must be recorded when present because they may influence sign-in, idle, storage, network, Outlook, or Edge conditions.

Results apply only to the recorded application variants and versions.

### Workloads

- A controlled Windows sign-in sequence.
- Cold and warm Outlook launches plus an agreed search-readiness action.
- A cold Edge launch plus an agreed first-interaction action.
- An agreed Windows Search query and result-readiness condition.
- Resume from an agreed sleep state to an agreed network-readiness condition.
- An agreed idle observation window after foreground activity has stopped.

Each workload requires an explicit start event, end/readiness event, reset procedure, data set or content where applicable, and allowed background-activity state before measurements begin.

## Initial hypothesis

If the lab fixes the environment, defines observable readiness points, resets state consistently, and repeats each workflow, then it can produce a reproducible median baseline for the selected HP ZBook. The resulting observations may identify one or more workflows or environmental conditions that warrant a narrower causal experiment.

This is a testable hypothesis, not a performance claim. No expected timing, improvement magnitude, bottleneck, or root cause is asserted.

## Known facts

- The project charter identifies HP ZBook laptops running Windows 11 as the initial platform.
- The intake reports delayed responsiveness after Windows sign-in and around Outlook, Edge, Windows Search, OneDrive, and Teams activity.
- `EXP-001` is intended to measure one representative HP ZBook before any Windows calibration is applied.
- The repository requires repeated runs, median reporting, raw-result retention, and an environment record.
- The required environment record includes the device configuration, Windows build, BIOS, drivers, application versions, power source and mode, thermal state, network type, and benchmark conditions.
- No benchmark results or verified performance measurements are present in the intake or experiment README.
- Stable releases require explicit human approval.

## Hypotheses and assumptions requiring validation

- The reported delays can be reproduced on the selected lab system.
- The selected system is sufficiently representative to develop the first baseline protocol.
- Observable start and readiness events can be defined for every workload without relying only on subjective judgment.
- The chosen reset and control procedures can keep run-to-run variation low enough for the median to be useful.
- OneDrive, Teams, network, thermal, power, indexing, caching, and update activity can be observed and controlled well enough to interpret results.
- The instrumentation overhead will be small enough to avoid materially changing the workflows being measured.

## Unknowns

- Which HP ZBook model and hardware configuration will be used.
- Which Windows 11 edition, release, build, update state, and configuration will be tested.
- Which Outlook product/variant, profile, mailbox/data set, and search state will be used.
- Which Edge profile, extensions, page/content, cache state, and network conditions will be used.
- Whether OneDrive and Teams are installed, signed in, starting automatically, syncing, updating, or otherwise active.
- The operational definitions of usable desktop, search readiness, first-interaction readiness, network-ready, and idle.
- The sign-in method, restart/shutdown state, sleep state, and Fast Startup treatment.
- The Windows Search corpus, indexing state, query, and expected result condition.
- The number of repetitions, warm-up policy, run order, reset steps, idle-settling period, and outlier treatment.
- The instrumentation and event sources available on the selected system.
- The customer impact threshold or decision rule that would make a later change meaningful.

## Risks

- A single device may produce a useful protocol but not a generalizable performance conclusion.
- Ambiguous readiness definitions can produce precise-looking but non-comparable timings.
- Caches, search indexing, sync, updates, endpoint protection, and scheduled tasks can contaminate cold, warm, idle, and sign-in runs.
- Power-source, power-mode, battery, temperature, fan, and thermal-history differences can distort comparisons.
- Network variability can dominate Outlook, Edge, OneDrive, Teams, search, and wake-to-network observations.
- Application or Windows updates during the experiment can invalidate comparisons.
- Instrumentation can alter launch time or resource activity.
- Real mailbox, search, browser, or collaboration data can create privacy or handling concerns; approved lab data must be used.
- Recording only medians can hide unstable runs; raw results and dispersion must remain available even though the median is the required headline statistic.

## Handoff questions for Windows Research

1. Which exact HP ZBook will be reserved, and what are its complete hardware, BIOS, driver, storage-health, and power details?
2. Which exact Windows 11 edition, release, OS build, update state, power mode, and security configuration will be the baseline?
3. What customer journey is represented by each workload, and what observable event defines its start and readiness endpoint?
4. How will usable desktop, Outlook search readiness, Edge first-interaction readiness, network-ready, and idle be operationally defined?
5. Which Outlook variant, channel/version, profile type, mailbox/data set, account state, cache state, and search query will be used?
6. Which Edge channel/version, profile, extensions, page/content, cache state, and first interaction will be used?
7. Which Windows Search surface, corpus, indexing state, query, and result condition will be used?
8. What OneDrive and Teams installation, sign-in, startup, sync, update, foreground, and background states will be required for each workflow?
9. What restart, shutdown, sign-out, sign-in, sleep, wake, Fast Startup, cache-reset, and settling procedures will make runs comparable?
10. How will power source, battery state, network path, ambient conditions, thermal state, and recent workload history be fixed or recorded?
11. Which event sources and tools will capture timings and idle CPU, memory, and disk activity, and how will their overhead be checked?
12. How many measured repetitions and warm-up runs are required, how will run order be chosen, and how will failed or interrupted runs be retained and classified?
13. Besides the required median, which raw values and variability indicators will be retained so unstable results are visible?
14. What approved lab data will replace production mailbox, browser, search, OneDrive, and Teams content?
15. What evidence or decision rule will determine whether the baseline is reproducible enough to hand off to Experiment Design or needs revision?

## Research-stage completion criteria

Windows Research may hand the experiment to Experiment Design only when:

- every target workflow has an unambiguous start event, readiness endpoint, reset method, and controlled-condition record;
- the exact system, Windows, application, power, thermal, and network environment is documented;
- repeated raw runs have been retained and the median is reported without invented or missing values;
- failed, interrupted, rejected, and inconclusive runs remain preserved and identifiable;
- measurement limitations, variability, and instrumentation overhead are reported; and
- facts, observations, and hypotheses remain explicitly separated.

This brief authorizes baseline research only. It does not authorize calibration changes or a Stable release.

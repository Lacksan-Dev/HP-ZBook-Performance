# Lacksan Windows R&D Lab Agent Rules

## Mission
Develop measurable Windows responsiveness improvements for office, browser, workstation, battery, driver, and local-AI workloads.

## Required workflow
1. Research Director
2. Windows Research
3. Experiment Design
4. PowerShell Engineering
5. Validation Lab
6. Component Documentation
7. YouTube Studio
8. Release Management

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

# EXP-052 Test Plan

Repository checks:

- Parse the provider with the PowerShell parser.
- Run `controller/tests/LogiTuneRun.Tests.ps1` under Pester.
- Run `experiments/EXP-052/Test-Integration.ps1` and confirm `MutationPerformed` is false.
- Review the patch for secrets and forbidden mutation commands.
- Confirm manifest profile and provider uniqueness.

Physical checks remain `needs-evidence` and require matched repeated trials, reboot persistence, functional device validation, protected remote-access readiness, and exact rollback.

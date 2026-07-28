# Lacksan Controller MVP

EXP-046 introduces the product-level orchestration layer for the experiment repository.

## Commands

```powershell
.\controller\Invoke-LacksanController.ps1 -Action Scan
.\controller\Invoke-LacksanController.ps1 -Action Recommend
.\controller\Invoke-LacksanController.ps1 -Action DryRun
.\controller\Invoke-LacksanController.ps1 -Action Apply -Confirm:$false
.\controller\Invoke-LacksanController.ps1 -Action Verify -TransactionId <id>
.\controller\Invoke-LacksanController.ps1 -Action VerifyReboot -TransactionId <id>
.\controller\Invoke-LacksanController.ps1 -Action Report -TransactionId <id>
.\controller\Invoke-LacksanController.ps1 -Action Rollback -TransactionId <id> -Confirm:$false
```

The initial `InventoryOnly` profile is deliberately read-only. It validates the manifest/provider architecture, transaction journal, structured logging, protected-application inventory, dry run, verification, reporting, and rollback flow before existing experiments are adapted into reversible providers.

## Provider contract

Each provider declares dependencies, conflicts, reboot requirements, operating mode, and every protected scope. A provider script implements `Check`, `Capture`, `DryRun`, `Apply`, `Verify`, `VerifyReboot`, and `Rollback`.

The controller captures every provider before application. A failed application triggers reverse-order rollback of providers already applied. Reports omit usernames, paths, registry data, credentials, and application content.

## Validation status

Repository contract and integration tests are included. Physical HP ZBook execution, repeated combined-profile benchmarks, reboot persistence, rollback execution, and measured medians remain `needs-evidence`. No performance result is claimed.

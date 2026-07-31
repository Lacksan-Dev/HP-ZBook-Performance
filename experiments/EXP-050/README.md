# EXP-050

Controller integration for one exact Logi Options+ current-user tray or background Run registration.

## Safety and lifecycle

The provider requires HP Windows 11, an unmanaged current-user context, exactly one eligible Run value, a supported Logi Options+ executable identity, a valid Logitech or Logi Authenticode publisher, and an explicit background, minimized, startup, tray, or silent argument. It refuses updater, firmware, receiver, Bluetooth, protected-application, device-driver, enterprise-management, and ambiguous identities.

Capture records the exact registry path, value name, registry kind, unexpanded command, resolved executable, executable SHA-256, executable version, publisher subject, machine, and user SID. Application removes one Run value only. Verification covers immediate absence and post-reboot persistence. Rollback refuses drift, validates the saved command, publisher, and executable hash, then restores the exact value kind and unexpanded data.

Run repository-static integration validation with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\experiments\EXP-050\Test-Integration.ps1
Invoke-Pester .\controller\tests\EXP-050.LogiOptionsPlusRun.Tests.ps1
```

## Physical validation

Use five matched baseline sign-ins and five matched treatment sign-ins. Record Windows build, HP model, BIOS, storage and display drivers, Logi Options+ version, power source, power mode, thermal state, connected devices, and instrumentation overhead. Report medians for sign-in to usable desktop, first-120-second CPU and disk activity, Logi Options+ process activity, manual launch readiness, device-settings readiness, update behavior, and readiness of Omnissa, Windows App, Remote Desktop, and Tailscale.

After treatment, verify basic keyboard, mouse, receiver, and Bluetooth operation, then reboot and run `VerifyReboot`. Execute exact rollback and repeat the functional checks. Preserve favorable, adverse, failed, and inconclusive evidence.

Physical HP Windows 11 measurement, reboot verification, device-function checks, update validation, protected-application readiness, and rollback execution remain `needs-evidence`. Release remains Experimental. Stable remains excluded.

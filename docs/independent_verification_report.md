# Independent Post-Implementation Verification Report

**Summary.** Every script, backup artifact, Desktop launcher, and live hardware/OS transition in `C:\Users\Admin\.gemini\antigravity\scratch\pc-optimizer\` passed the deterministic 25-check round-trip verification suite ([`verify_all_modes.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/verify_all_modes.ps1)). Two defects were caught during live testing, fixed at the root cause in [`CheDoDiHoc_CuuHo.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/CheDoDiHoc_CuuHo.ps1), and re-verified to `25/25 PASS` (`0 FAIL`). The system is left in the verified `-VeNha` Home Anti-Wear Gaming state (`Storage 60%`, `AC Efficient Aggressive`, `2560x1600 @ 60Hz`, and `10%` restored brightness).

---

## 1. Bugs Discovered and Fixed During Live Audit

1. **Brightness Restoration State Machine (`Save-PriorBrightnessIfNeeded` & `Invoke-VeNha` in [`CheDoDiHoc_CuuHo.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/CheDoDiHoc_CuuHo.ps1#L331-L343))**
   - **Root Cause (Measured).** The original implementation checked `if ($existing.PriorBrightness -gt 20)` to decide whether to preserve `PriorBrightness` across consecutive `-DiHoc` (`20%`) and `-DiHocUltra` (`12%`) switches. Because the user's pre-test brightness on this laptop was `10%` (`OriginalBrightness = 10` in [`baseline_backup.json`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/backup/baseline_backup.json#L5)), switching from `-DiHoc` (`20%`) to `-DiHocUltra` (`12%`) evaluated `10 -gt 20` as `False` and overwrote `PriorBrightness` with `20%`.
   - **Fix Applied.** Replaced the threshold guess with an explicit `InCampusMode` boolean state transition in [`runtime_state.json`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/backup/runtime_state.json). Entering `-DiHoc` or `-DiHocUltra` from Home mode records `PriorBrightness` (`10%`) and sets `InCampusMode = $true`. Switching between `-DiHoc` and `-DiHocUltra` preserves `PriorBrightness = 10%` while `InCampusMode` is `$true`. Running `-VeNha` restores `PriorBrightness` (`10%`) and resets `InCampusMode = $false`.
2. **Non-Elevated Registry Path Fallback for Cốc Cốc Efficiency & Battery Saver (`Invoke-CheDoDiHoc` & `Invoke-VeNha` in [`CheDoDiHoc_CuuHo.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/CheDoDiHoc_CuuHo.ps1#L512-L518))**
   - **Root Cause (Measured).** On Windows 11, `HKCU:\Software\Policies` is owned by `NT AUTHORITY\SYSTEM` and grants `ReadKey` only to a non-elevated user token (`DESKTOP-6FFCHTF\Admin`), while `BUILTIN\Administrators` holds `FullControl`. Writing `HKCU:\Software\Policies\CocCoc\Browser` from a non-elevated token threw `System.UnauthorizedAccessException`, which was silently swallowed by `catch {}`.
   - **Fix Applied.** Added `HKCU:\Software\CocCoc\Browser` (where `DESKTOP-6FFCHTF\Admin` holds `FullControl` in both non-elevated and elevated tokens) alongside `HKCU:\Software\Policies\CocCoc\Browser` and `HKLM:\SOFTWARE\Policies\CocCoc\Browser` in both `-DiHocUltra` and `-VeNha` cleanup, and preserved UTF-8 with BOM (`0xEF 0xBB 0xBF`) on all `.ps1` scripts for Windows PowerShell 5.1 parser compatibility.

---

## 2. Deterministic 25-Point Verification Matrix

| Check ID | Check Description | Measured Result | Expected Target | Status |
| :--- | :--- | :--- | :--- | :--- |
| **1.1** | AST Parse [`CheDoDiHoc_CuuHo.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/CheDoDiHoc_CuuHo.ps1) | `0 errors` (UTF-8 BOM present) | `0 errors` | **PASS** |
| **1.2** | AST Parse [`baseline_setup.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/baseline_setup.ps1) | `0 errors` (UTF-8 BOM present) | `0 errors` | **PASS** |
| **1.3** | [`baseline_backup.json`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/backup/baseline_backup.json) integrity | Valid JSON (`Timestamp=2026-11-10T00:42:05`, `8` PowerSettings, `10` Services, `24` Tasks, `17` Registry entries) | Non-empty valid JSON | **PASS** |
| **1.4** | Legacy `TOI UU PUBG IRIS XE.lnk` backup | `Desktop=False`, `Backup=True` | Moved from Desktop to `backup\` | **PASS** |
| **1.5** | Desktop launchers (`.lnk` & `.bat`) | Target `powershell.exe` with `-NoProfile -ExecutionPolicy Bypass -File "C:\Users\Admin\.gemini\antigravity\scratch\pc-optimizer\CheDoDiHoc_CuuHo.ps1"` | Accurate target path & args | **PASS** |
| **2.0** | Mode `-Status` live output | Displays `100% (71.59 Wh / 71.59 Wh)`, `17305 mV (4.326 V/cell)`, `32 °C`, `Storage`, RAM Free/Total, and 4 runtime estimate rows | All telemetry & runtime estimates | **PASS** |
| **2.1a** | Mode `[1] -DiHoc` Boost indices | `DC=0x00000000 (0)`, `AC=0x00000004 (4)` | `DC=0x0`, `AC=0x4` | **PASS** |
| **2.1b** | Mode `[1] -DiHoc` `DC PROCFREQMAX` | `0x00000960 (2400 MHz)` | `0x960 (2400 MHz)` | **PASS** |
| **2.1c** | Mode `[1] -DiHoc` `DC PERFEPP` | `0x0000005a (90%)` | `0x5a (90%)` | **PASS** |
| **2.1d** | Mode `[1] -DiHoc` `DC ESBATTTHRESHOLD` | `0x00000064 (100%)` | `0x64 (100%)` | **PASS** |
| **2.1e** | Mode `[1] -DiHoc` `DC Wireless Saving` | `0x00000003 (3)` | `0x3 (Maximum Power Saving)` | **PASS** |
| **2.1f** | Mode `[1] -DiHoc` Screen Brightness | `20%` | `20%` | **PASS** |
| **2.2a** | Mode `[2] -DiHocUltra` `DC CPMAXCORES` | `0x00000032 (50%)` | `0x32 (50%)` | **PASS** |
| **2.2b** | Mode `[2] -DiHocUltra` `DC PROCFREQMAX` | `0x000006a4 (1700 MHz)` | `0x6a4 (1700 MHz)` | **PASS** |
| **2.2c** | Mode `[2] -DiHocUltra` `DC PERFEPP` | `0x00000064 (100%)` | `0x64 (100%)` | **PASS** |
| **2.2d** | Mode `[2] -DiHocUltra` Cốc Cốc Saver keys | `HighEfficiencyModeEnabled=1`, `BatterySaverModeAvailability=1` | `1, 1` | **PASS** |
| **2.2e** | Mode `[2] -DiHocUltra` Brightness & State | `Current=12%`, `SavedPrior=10%` | `Current=12%`, `SavedPrior=10%` | **PASS** |
| **2.3** | Mode `[3] -SacDay100` `IdeaBatteryAgent.dll` | `Mode=Normal (0)`, `IsExpressCharging=False` | `Normal (0)`, `IsExpressCharging=False` | **PASS** |
| **2.4a** | Mode `[4] -VeNha` `IdeaBatteryAgent.dll` | `Mode=Storage (1)`, `IsExpressCharging=False` | `Storage (1)`, `IsExpressCharging=False` | **PASS** |
| **2.4b** | Mode `[4] -VeNha` PowerCfg Restored | `DCCores=0x00000064 (100%)`, `DCFreq=0x00000dac (3500 MHz)`, `ACBoost=0x00000004 (4)` | `0x64`, `0xdac`, `0x4` | **PASS** |
| **2.4c** | Mode `[4] -VeNha` Brightness & Display | `Bri=10%`, `2560x1600 @ 60Hz` | Pre-test `10%`, `2560x1600 @ 60Hz` | **PASS** |
| **2.4d** | Mode `[4] -VeNha` `\PUBGWirelessAndHzGuard` | `State=Running` | `Running` | **PASS** |
| **2.5** | Mode `[5] -CuuHoRAM` execution speed | `Internal=956 ms`, `TotalProcess=1847 ms`, `ExitCode=0` | `< 2000 ms`, `0 errors` | **PASS** |
| **3.1** | Protected Processes & Services Whitelist | `node:5, python:1, pythonw:1, browser:18, steam:1, goodbyedpi:1, EVKey64:1, FnHotkeyUtility:1, LenovoVantageService:Running` | 100% intact | **PASS** |
| **3.2** | Protected Caches (`_npx` & `.cache`) | `_npx=52287 files`, `.cache=4521 files` (identical pre/post counts) | 100% intact | **PASS** |

---

## 3. Principles Applied

- [`principle-prove-it-works`](file:///C:/Users/Admin/.gemini/config/plugins/pstack/skills/principle-prove-it-works/SKILL.md) drove the creation of [`verify_all_modes.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/verify_all_modes.ps1), which queries `powercfg /qh SCHEME_CURRENT`, `IdeaBatteryAgent.dll`, `WmiMonitorBrightness`, `Win32_VideoController`, process tables, and file counts directly after each mode switch instead of trusting script console logs.
- [`principle-model-the-domain`](file:///C:/Users/Admin/.gemini/config/plugins/pstack/skills/principle-model-the-domain/SKILL.md) replaced the `PriorBrightness -gt 20` heuristic in [`CheDoDiHoc_CuuHo.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/CheDoDiHoc_CuuHo.ps1#L331-L343) with an explicit `InCampusMode` boolean state transition in [`runtime_state.json`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/backup/runtime_state.json).
- [`principle-fix-root-causes`](file:///C:/Users/Admin/.gemini/config/plugins/pstack/skills/principle-fix-root-causes/SKILL.md) traced the non-elevated `HKCU:\Software\Policies\CocCoc\Browser` failure to the `NT AUTHORITY\SYSTEM` DACL on `HKCU:\Software\Policies` and added `HKCU:\Software\CocCoc\Browser` alongside the policy paths, plus restored UTF-8 BOM encoding for Windows PowerShell 5.1.

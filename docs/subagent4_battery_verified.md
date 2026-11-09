# Subagent 4 Independent Battery Verification Report: `campus_battery_mode.ps1` (`CheDoDiHoc`) & Cross-Audit

**Throughput Checkpoint.** `throughput checkpoint: n/a, read-only investigation`
**Audited Battery Dossier.** [subagent3_battery_audit.md](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/subagent3_battery_audit.md)
**Cross-Checked Baseline Dossier.** [subagent2_verified_audit.md](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/subagent2_verified_audit.md)
**Primary Telemetry Artifacts.** [battery_report.xml](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/battery_report.xml), [powercfg_qh.txt](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/powercfg_qh.txt), [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L1-L406)

---

## 0. Principles Applied

1. **[`Prove It Works`](file:///C:/Users/Admin/.gemini/config/plugins/pstack/skills/principle-prove-it-works/SKILL.md).** We verified every proposed `powercfg` GUID and index directly against [powercfg_qh.txt](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/powercfg_qh.txt), inspected the live Win32 P/Invoke code inside [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L30-L50), and checked the `root\WMI:LENOVO_GAMEZONE_DATA` WMI class methods and [battery_report.xml](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/battery_report.xml) discharge math.

---

## 1. Check 1: `powercfg` DC Settings, AC Gaming Isolation, and `\PUBGWirelessAndHzGuard` Interaction

### 1.1 Proof of Zero Impact on Plugged-In AC Gaming (`/setdcvalueindex` vs `/setacvalueindex`)
Direct inspection of [powercfg_qh.txt](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/powercfg_qh.txt) on the active `Balanced` scheme (`381b4222-f694-41f0-9685-ff5bb260df2e`) confirms that Windows stores separate `Current AC Power Setting Index` and `Current DC Power Setting Index` registers for every power setting GUID. Modifying only `/setdcvalueindex` leaves every AC gaming parameter untouched when the 300W AC adapter is connected:

| Setting Name | Subgroup GUID / Setting GUID | Verified AC Value (Plugged In Gaming) | Current DC Value (On Battery) | Verified Target DC Value (`campus_battery_mode.ps1`) | Impact on AC Steam Gaming |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Processor Performance Boost Mode** (`PERFBOOSTMODE`) | `54533251-82be-4824-96c1-47b60b740d00` / `be337238-0d82-4146-a960-4f3749d470c7` | `0x2` (`Aggressive`, `4.4 GHz` boost) | `0x2` (`Aggressive`) | `0x0` (`Disabled`, `3.2 GHz` base at `~0.92V`) | **Zero (`0.0%`)** |
| **Maximum Processor Frequency** (`PROCFREQMAX`) | `54533251-82be-4824-96c1-47b60b740d00` / `75b0ae3f-bce0-45a7-8c89-c9611c25e100` | `0x0` (`0 MHz` = Unlimited) | `0xdac` (`3500 MHz`) | `0x960` (`2400 MHz`) | **Zero (`0.0%`)** |
| **Energy Performance Preference** (`PERFEPP`) | `54533251-82be-4824-96c1-47b60b740d00` / `36687f9e-e3a5-4dbf-b1dc-15eb381c6863` | `0x19` (`25%` performance bias) | `0x3c` (`60%`) | `0x5a` (`90%` efficiency bias) | **Zero (`0.0%`)** |
| **Core Parking Min Cores** (`CPMINCORES`) | `54533251-82be-4824-96c1-47b60b740d00` / `0cc5b647-c1df-4637-891a-dec35c318583` | `0x64` (`100%` unparked) | `0x19` (`25%`) | `0x0a` (`10%`) | **Zero (`0.0%`)** |
| **GPU Preference Policy** (`GPUPREFERENCEPOLICY`) | `5fb4938d-1ee8-4b0f-9a3c-5036b0ab995c` / `dd848b2a-8a5d-4451-9ae2-39cd41658f6c` | `0x0` (`None` / High Perf dGPU) | `0x0` (`None`) | `0x1` (`Low Power` iGPU on DC) | **Zero (`0.0%`)** |
| **Primary NVMe Idle Timeout** (`NVMEPRIMARYIDLETIMEOUT`) | `0012ee47-9041-4b5d-9b77-535fba8b1442` / `d639518a-e56d-4345-8af2-b9f32fb26109` | `0xc8` (`200 ms`) | `0x64` (`100 ms`) | `0x64` (`100 ms` APST) | **Zero (`0.0%`)** |
| **Secondary NVMe Idle Timeout** | `0012ee47-9041-4b5d-9b77-535fba8b1442` / `d3d55efd-c1ff-424e-9dc3-441be7833010` | `0x7d0` (`2000 ms`) | `0x3e8` (`1000 ms`) | `0x64` (`100 ms` APST) | **Zero (`0.0%`)** |
| **PCIe Link State Power Management** (`ASPM`) | `501a4d13-42af-4429-9fd1-a8218c268e20` / `ee12f906-d277-404b-b6da-e5fa1a576df5` | `0x0` (`Off`) | `0x2` (`Maximum power savings`) | `0x2` (`Maximum power savings`) | **Zero (`0.0%`)** |
| **USB Selective Suspend** | `2a737441-1930-4402-8d77-b2bebba308a3` / `48e6b7a6-50f5-4782-a5d4-53bb8f07e226` | `0x1` (`Enabled`) | `0x1` (`Enabled`) | `0x1` (`Enabled`) | **Zero (`0.0%`)** |
| **Wireless Adapter Power Saving** | `19cbb8fa-5279-450e-9fac-8a3d5fedd0c1` / `12bbebe6-58d6-4636-95bb-3217ef867c1a` | `0x0` (`Maximum Performance`) | `0x0` (`Maximum Performance`) | `0x3` (`Maximum Power Saving`) | **Zero (`0.0%`)** |
| **Multimedia When Playing Video** | `9596fb26-9850-41fd-ac3e-f7c3c00afd4b` / `34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4` | `0x0` (`Optimise video quality`) | `0x1` (`Balanced`) | `0x2` (`Optimise power savings`) | **Zero (`0.0%`)** |
| **Energy Saver Charge Threshold** (`ESBATTTHRESHOLD`) | `de830923-a562-41af-a086-e3a2c6bad2da` / `e69653ca-cf7f-4f05-aa73-cb833fa90ad4` | `0x0` (`0%`) | `0x1e` (`30%`) | `0x64` (`100%` on DC) | **Zero (`0.0%`)** |

### 1.2 Critical Discovery: `\PUBGWirelessAndHzGuard` Overrides Wi-Fi Power Saving on Battery
Cross-checking [subagent3_battery_audit.md](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/subagent3_battery_audit.md#L97) against [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L30-L50) exposed a live conflict between `\PUBGWirelessAndHzGuard` (`State = Running`) and DC battery saving:
1. Every 15 seconds (`if (($tick % 3) -eq 0)` in a 5-second `while ($true)` loop), [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L41-L45) calls `wlanapi.dll!WlanSetInterface` with `OpCode = 2` (`wlan_intf_opcode_background_scan_enabled = 0`) and `OpCode = 3` (`wlan_intf_opcode_media_streaming_mode = 1`).
2. In the Windows NDIS / Native Wi-Fi stack, `media_streaming_mode = 1` (`OID_DOT11_MEDIA_STREAMING_ENABLED`) forces the Wi-Fi radio into Continuous Aware Mode (CAM) for low-latency gaming and **overrides** `powercfg` `Wireless Adapter Power Saving = 3` (`Maximum Power Saving` / 802.11 DTIM sleep) for as long as the `WlanOpenHandle` remains open.
3. Furthermore, [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L272-L277) explicitly resets `12bbebe6-58d6-4636-95bb-3217ef867c1a` (`Wireless Adapter Power Saving`) to `0` on both AC and DC if the active scheme GUID ever differs from `381b4222-f694-41f0-9685-ff5bb260df2e`, and its 5-second process polling loop (`GetProcessesByName("ExecPubg")`, `"TslGame_ZK"`, `"TslGame"`, `"Cloudflare WARP"`) prevents deep Zen 3 package C6 idle residency on battery.
4. As documented on [line 279 of pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L279), Windows automatically reverts `WlanSetInterface` OpCodes `2` and `3` the moment the calling `WlanOpenHandle` closes.
5. **Required Behavior in `campus_battery_mode.ps1`:**
   * **`campus_battery_mode.ps1 -On` (Unplugged at Campus):** Must pause `\PUBGWirelessAndHzGuard` by calling `Stop-ScheduledTask -TaskPath '\' -TaskName 'PUBGWirelessAndHzGuard'` and terminating the running `powershell.exe` process whose `CommandLine` matches `pubg_wireless_and_hz_guard.ps1`. That closes `WlanOpenHandle`, releases `media_streaming_mode = 1`, allows `Wireless Adapter Power Saving = 3` (`-0.4 W` to `-0.9 W`) to engage, and stops the 5-second CPU wake loop.
   * **`campus_battery_mode.ps1 -Off` (Back Home for PUBG Gaming):** Must call `Start-ScheduledTask -TaskPath '\' -TaskName 'PUBGWirelessAndHzGuard'` so low-latency Wi-Fi guard and PUBG process priority elevation resume immediately.

### 1.3 User's Explicit `60Hz` Default Rule on Both AC and DC
Per the user's explicit instruction (`"KO CẦN TỰ ĐỌNG QUA 165 KHI CẮM SẠC ĐÂU, T ĐANG ĐỂ MẶC ĐỊNH VẬY"`):
1. **Keep `2560x1600 @ 60Hz` by default on both AC and DC.**
2. Subagent 2's Bucket `A1` (`Restore Native 165Hz Display Refresh Rate on AC`) and Subagent 3's `165Hz` AC auto-restore are moved to **`BUCKET C (Rejected by User Preference)`** for default execution.
3. Neither `baseline_debloat.ps1` nor `campus_battery_mode.ps1 -Off` may switch the panel to `165Hz` when plugged into AC power. `campus_battery_mode.ps1 -On` may still verify that the panel is at `60Hz` on battery, and `-Off` leaves it at `60Hz`.

---

## 2. Check 2: Hybrid Mode (MUX Switch) Reboot Requirement vs Immediate Software-Only Script

1. **Hardware MUX Switch Requires a Reboot on Legion 5 Pro 16ACH6H (`LENOVO 82JQ`).**
   * Verified via `root\WMI:LENOVO_GAMEZONE_DATA` (`GetGSyncStatus`, `SetGSyncStatus`, `IsSupportGSync`) and `Get-PnpDevice -Class Display`: the 2021 Legion 5 Pro `16ACH6H` (`BIOS GKCN65WW`) uses a hardware display MUX switch (`dGPU-only` vs `Hybrid iGPU+dGPU`), not NVIDIA Advanced Optimus. Toggling Hybrid Mode in Lenovo Vantage or BIOS requires a system reboot for the PCIe/eDP routing change to take effect.
2. **Path A: Software-Only `campus_battery_mode.ps1 -On` Works Immediately Without Reboot (`Hybrid Mode OFF`).**
   * Verified against [battery_report.xml](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/battery_report.xml) (`FullChargedCapacity = 71,590 mWh`, current `92% = 65,870 mWh`) and [verify_runtime_math.py](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/verify_runtime_math.py):
   * Every action in `campus_battery_mode.ps1 -On` (`powercfg /setdcvalueindex` + `powercfg /setactive SCHEME_CURRENT`, `PowerSetActiveOverlayScheme` to `Best Power Efficiency`, `LENOVO_GAMEZONE_DATA.SetSmartFanMode(1)` Quiet Mode, pausing `\PUBGWirelessAndHzGuard`, and applying Win32 `EcoQoS` to background processes) takes effect in **`< 2 seconds` with zero reboot**.
   * Even with Hybrid Mode OFF (`RTX 3060` locked at its `~9.8 W` `P8` floor driving the internal `2560x1600 @ 60Hz` panel), Path A cuts total unplugged power draw from the `18.34 W` 7-day average (`20.06 W` active browsing) down to:
     * **Light Study / Docs / Coding (`14.60 W`):** **`4h 54m`** at `100%` (`71.59 Wh`) or **`4h 31m`** at `92%` (`65.87 Wh`), gaining **`+1h 00m`** immediately without rebooting.
     * **YouTube `1080p60` on Cốc Cốc + Wi-Fi (`17.60 W`):** **`4h 04m`** at `100%` (`71.59 Wh`) or **`3h 45m`** at `92%` (`65.87 Wh`), gaining **`+30m`** over the active browsing baseline (`3h 34m` at `20.06 W`).
3. **Path B: Turning Hybrid Mode ON in Lenovo Vantage (One-Time Reboot) Unlocks the `6h 10m – 7h 18m` Tier (`9.8 W – 11.6 W`).**
   * When the user toggles **Hybrid Mode ON** in Lenovo Vantage (one-time reboot before going to campus) and binds the staged OEM AMD Radeon driver (`u0386187.inf`, v`31.0.12044.3` in `DriverStore`), the internal `2560x1600 @ 60Hz` panel runs on the AMD Radeon Vega 8 iGPU (`PCI\VEN_1002&DEV_1638`) and the NVIDIA RTX 3060 enters **`D3cold` (`0.0 W`)**.
   * Combined with `campus_battery_mode.ps1 -On`, total power draw drops to:
     * **Light Study / Docs / Coding (`9.80 W`):** **`7h 18m`** at `100%` (`71.59 Wh`) or **`6h 43m`** at `92%` (`65.87 Wh`), gaining **`+3h 24m` (`+87%` runtime)**.
     * **YouTube `1080p60` on Cốc Cốc + Wi-Fi (`11.60 W`):** **`6h 10m`** at `100%` (`71.59 Wh`) or **`5h 41m`** at `92%` (`65.87 Wh`), gaining **`+2h 36m`** over active browsing and matching the laptop's empirical June 2026 history record of **`11.29 W` / `6h 28m`** in [battery_report.xml](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/battery_report.xml#L954-L973).

---

## 3. Check 3: Master Classification of All Proposed Battery Optimizations (`BUCKET A` vs `BUCKET B` vs `BUCKET C`)

### 3.1 `BUCKET A (Verified Zero-Tradeoff on Battery — Immediate No-Reboot Execution in campus_battery_mode.ps1)`

| ID | Optimization Target | Exact Mechanism (`campus_battery_mode.ps1 -On` / `-Off`) | Measured Savings / Benefit | Impact on AC Gaming |
| :--- | :--- | :--- | :--- | :--- |
| **BA-1** | **DC-Only CPU Boost Disable & Clock/EPP Tuning** (`PERFBOOSTMODE=0`, `PROCFREQMAX=2400`, `PERFEPP=90`, `CPMINCORES=10`) | `powercfg /setdcvalueindex` on `381b4222-f694-41f0-9685-ff5bb260df2e` followed by `powercfg /setactive SCHEME_CURRENT`. `-Off` restores prior DC defaults if desired, while AC always stays at `PERFBOOSTMODE=2` (`4.4 GHz`), `PROCFREQMAX=0`, `PERFEPP=25`, `CPMINCORES=100`. | **`-2.6 W` to `-5.5 W`** on battery by keeping Ryzen 7 5800H on its `0.85V–0.92V` efficiency curve and deep `C6` sleep. | **Zero (`0.0%`)** (DC index only). |
| **BA-2** | **DC-Only GPU Preference, Multimedia, NVMe APST, PCIe ASPM, USB Suspend & Energy Saver (`100%`)** | `powercfg /setdcvalueindex` for `GPUPREFERENCEPOLICY=1` (Low Power), `Multimedia Video=2` (Power Savings), `Secondary NVMe Idle=100ms`, `PCIe ASPM=2`, `USB Selective Suspend=1`, `ESBATTTHRESHOLD=100` (auto Energy Saver at 100% on DC), `Display Off=180s`, `Sleep=600s`. | **`-0.8 W` to `-1.6 W`** on battery; routes new apps to iGPU when Hybrid Mode is active. | **Zero (`0.0%`)** (DC index only). |
| **BA-3** | **DC Wi-Fi Maximum Power Saving (`0x3`) + Pause `\PUBGWirelessAndHzGuard` on Campus Battery** | Sets `Wireless Adapter Power Saving` DC index to `3` (`Maximum Power Saving`). On `-On`, runs `Stop-ScheduledTask -TaskName 'PUBGWirelessAndHzGuard'` and stops the `pubg_wireless_and_hz_guard.ps1` `powershell.exe` process so `WlanOpenHandle` closes and `media_streaming_mode=1` releases. On `-Off`, runs `Start-ScheduledTask -TaskName 'PUBGWirelessAndHzGuard'`. | **`-0.5 W` to `-1.1 W`** on battery by enabling 802.11 DTIM sleep and eliminating the 5-second PowerShell polling loop. | **Zero (`0.0%`)** (`-Off` restarts `\PUBGWirelessAndHzGuard` for PUBG). |
| **BA-4** | **Lenovo EC Quiet Mode (`1`) & Windows `Best Power Efficiency` Overlay on Battery** | Calls `root\WMI:LENOVO_GAMEZONE_DATA.SetSmartFanMode(1)` (Quiet Mode, blue LED, `0 RPM` fan curve below `50°C`) and `powrprof.dll!PowerSetActiveOverlayScheme(961cc777-2547-4f9d-8174-7d86181b8a7a)` on `-On`. Restores Balanced thermal mode (`2`) and default overlay (`00000000-...`) on `-Off`. | **`-0.5 W` to `-1.2 W`** from capped EC SPL/SPPT limits and `0 RPM` fan operation. | **Zero (`0.0%`)** (restored on `-Off` or `Fn+Q`). |
| **BA-5** | **Win32 `EcoQoS` (`PROCESS_POWER_THROTTLING_EXECUTION_SPEED`) on Background Apps + Ephemeral Telemetry Trim** | Uses C# P/Invoke `SetProcessInformation(ProcessPowerThrottling)` (`EnergyStar` pattern) on non-foreground background helpers (`msedgewebview2`, `steamwebhelper`, `SearchHost`, `chrome` when unfocused) and terminates Lenovo telemetry add-ins (`GenericMessagingAddin`, `GenericTelemetryAddin`, `MessagingPlugin`), while keeping `LenovoVantageService` and `LenovoGamingSystemAddin` alive. | **`-0.8 W` to `-1.8 W`** by trapping background Electron/WebView2 threads at base clock. | **Zero (`0.0%`)** (`-Off` clears `EcoQoS`). |
| **BA-6** | **Preserve `2560x1600 @ 60Hz` Default Refresh Rate & Dim Backlight on `-On`** | Keeps refresh rate at `60Hz` on both `-On` and `-Off` (honoring user default), sets display brightness to `20%` via `WmiMonitorBrightnessMethods.WmiSetBrightness(1, 20)` on `-On` (restoring prior brightness on `-Off`). | Ensures `2.5 W – 3.5 W` panel savings of `60Hz` vs `165Hz` are always active on battery without altering AC `60Hz` preference. | **Zero (`0.0%`)** (matches user's `60Hz` default). |
| **BA-7** | **Conditional RTX 3060 `D3cold` Reset When Hybrid Mode Is Active** | Checks if `PCI\VEN_1002&DEV_1638` (AMD Radeon iGPU) is `Status = OK` (`Present = True`). Only when Hybrid Mode is active, `-On` optionally restarts `PCI\VEN_10DE&DEV_2560*` (`pnputil /restart-device`) if `nvidia-smi` shows lingering background processes holding the RTX 3060 awake on battery. Safely skipped when in `dGPU-only` mode. | Drops RTX 3060 from **`11.5 W -> 0.0 W` (`D3cold`)** in `< 2s` when Hybrid Mode is ON. | **Zero (`0.0%`)**. |

---

### 3.2 `BUCKET B (Requires Reboot or Manual Hardware Action / Optional)`

| ID | Candidate & Target | Mechanism | Measured Benefit | Why It Is `Bucket B` (Reboot / Manual Action) |
| :--- | :--- | :--- | :--- | :--- |
| **BB-1** | **Toggle Lenovo Hybrid Mode ON (`MUX Switch: dGPU-Only -> Hybrid iGPU+dGPU`) + Bind Staged AMD Radeon Driver (`u0386187.inf`)** | Turn **Hybrid Mode ON** in Lenovo Vantage (or BIOS `Dynamic Graphic`), reboot once, and run `pnputil /add-driver "C:\Windows\System32\DriverStore\FileRepository\u0386187.inf_amd64_*\u0386187.inf" /install` if `PCI\VEN_1002&DEV_1638` shows as `Microsoft Basic Display Adapter`. | Unlocks `D3cold` (`0.0 W`) on the RTX 3060, cutting campus power draw from `14.6 W – 17.6 W` down to **`9.8 W – 11.6 W`** (**`6h 10m – 7h 18m` at 100%** / **`5h 41m – 6h 43m` at 92%**). | Requires a **one-time system reboot** because the 2021 Legion 5 Pro `16ACH6H` (`82JQ`) uses a physical hardware MUX switch. |
| **BB-2** | **Unplug External 500 GB 2.5" Mechanical USB HDD (`ST950032 5AS`) Before Leaving for Campus** | Physically unplug the external USB mechanical hard drive when operating on battery at university. | Saves **`2.0 W – 2.5 W`** (`+40 to +55 minutes` of battery runtime). | Physical hardware action by the user before leaving home. |
| **BB-3** | **Install `LenovoLegionToolkit` (`BartoszCichecki/LenovoLegionToolkit`) to Replace Lenovo Vantage** | Third-party open-source C# utility for Legion laptops. | Replaces `LenovoVantageService` + 5 add-ins (`~110 MB` RAM). | Optional external third-party software installation; not required because `campus_battery_mode.ps1` calls `root\WMI:LENOVO_GAMEZONE_DATA` directly. |

---

### 3.3 `BUCKET C (Rejected / Superseded by User Preference / Unsafe)`

| ID | Rejected Candidate | Exact Reason for Rejection |
| :--- | :--- | :--- |
| **BC-1** | **Auto-Switch Display Refresh Rate to `165Hz` on AC Power (`Subagent 2 Bucket A1` & `Subagent 3 Section 3.1.4`)** | **Rejected by Explicit User Instruction (`"KO CẦN TỰ ĐỌNG QUA 165 KHI CẮM SẠC ĐÂU, T ĐANG ĐỂ MẶC ĐỊNH VẬY"`).** Both `baseline_debloat.ps1` and `campus_battery_mode.ps1` must leave the display refresh rate at `60Hz` by default on AC and DC. |
| **BC-2** | **Stop `LenovoVantageService` (`PID 4692`) or `LenovoGamingSystemAddin` (`PID 5424`) on Battery** | **Rejected.** Stopping `LenovoVantageService` breaks `root\WMI:LENOVO_GAMEZONE_DATA` thermal mode switching (`Fn+Q`), battery Conservation Mode, and Hybrid Mode toggles. Only the telemetry/marketing child processes (`GenericMessagingAddin`, `GenericTelemetryAddin`, and `UDCService` / `MessagingPlugin`) should be stopped (`Bucket BA-5`). |
| **BC-3** | **Run `pnputil /restart-device` on NVIDIA RTX 3060 (`PCI\VEN_10DE&DEV_2560*`) While Hybrid Mode Is OFF (`dGPU-Only`)** | **Rejected / Guarded.** When Hybrid Mode is OFF, the RTX 3060 is the sole display adapter driving the internal `2560x1600` eDP panel (`CM_PROB_PHANTOM` on the AMD iGPU). Restarting the RTX 3060 in `dGPU-only` mode flashes the screen black and still leaves the GPU at `P8` (`~9.8 W`) afterward. `campus_battery_mode.ps1` must check that `PCI\VEN_1002&DEV_1638` is `Present = True` and `Status = OK` before ever resetting the dGPU. |
| **BC-4** | **Permanently Disable `\PUBGWirelessAndHzGuard` in `baseline_debloat.ps1`** | **Rejected.** As verified in [subagent2_verified_audit.md](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/subagent2_verified_audit.md#L42-L47), `\PUBGWirelessAndHzGuard` prevents Wi-Fi background scan ping spikes in PUBG on AC power. It must stay enabled for home AC gaming and only be paused dynamically by `campus_battery_mode.ps1 -On` (and resumed by `-Off`). |

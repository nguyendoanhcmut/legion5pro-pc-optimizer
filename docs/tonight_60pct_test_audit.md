# Tonight 60% Conservation Mode Audit (`2026-11-10 23:47 +07:00`)

`throughput checkpoint: n/a, read-only investigation`

## 1. Executive Verdict (`H0` Confirmed with High-Voltage Li-Po OCV Refinement)

Primary hardware telemetry confirms **`H0` (`60% Conservation Mode Worked Effectively`)** across every operational gate. The laptop shut down last night at `01:36:34`, stayed powered off for `13h 05m`, and cold-booted on battery today at `14:41:54`. Lenovo's embedded controller retained `BatteryChargeMode = Storage` (`55%-60%`) in NVRAM across full power-off without any script re-execution.

The user discharged the battery on DC from `100.0%` (`71,630 mWh`) down to `59.01%` (`42,260 mWh`) between `14:42:13` and `16:20:55`, then plugged in AC power. Over the next **`7 hours 26 minutes 47 seconds` on AC (`16:20:55` to `23:47:42`)**, including a **`42 minute 51 second` PUBG session (`22:07:53` to `22:50:44`)**, battery capacity remained completely flat at **`42,260 mWh` (`59%`)** with `0 mWh` net drift, `0 mA` current, `0 mW` charge rate, and `+0` charge cycles.

**Refinement on Cell Voltage (`Attack the Premise` + `Explain the Number`).** Measured resting pack voltage at `59.01%` is **`15,827 mV` (`3.957 V/cell`)**, which is `37 mV/cell` higher than the `3.85-3.92 V/cell` estimate in `H0`. That estimate assumed a standard `3.70 V`-nominal (`4.20 V` max) Li-ion curve. Primary static data from `IdeaBatteryAgent.dll` shows that the Sunwoda `L20D4PC1` pack is a **high-voltage 4S Li-Polymer cell** with `DesignVoltage = 15,360 mV` (`3.84 V/cell` nominal, `~4.35 V/cell` max). On a `3.84 V`-nominal Li-Po open-circuit curve, `59%` SoC naturally rests at `3.957 V/cell`. Lowering resting cell potential by **`-370 mV/cell`** (`4.326 V/cell` down to `3.957 V/cell`) removes the cathode from the `> 4.10 V/cell` electrolyte-oxidation zone during gaming heat soak.

---

## 2. Before vs. After Telemetry Comparison

| Metric | Last Night Baseline (`2026-11-10 00:35-01:26`) | Tonight Verified Test (`2026-11-10 23:47:32`) | Net Delta / Verdict |
| :--- | :--- | :--- | :--- |
| **EC Charge Mode** (`IdeaBatteryAgent.dll`) | `Normal` -> switched to `Storage` at `100%` | `Storage` (persisted across `13h 05m` shutdown) | Persisted in EC NVRAM |
| **Rapid Charge (`IsExpressCharging`)** | `False` | `False` | Safe (`Off`) |
| **Power Source (`PowerOnline` / `IsACIn`)** | `True` (AC Online) | `True` (AC Online for `7h 26m 47s`) | On AC bypass |
| **State of Charge (`RemainingPercent`)** | `100%` | `59%` (`59.01%` exact) | Inside `55%-60%` window |
| **Remaining Capacity (`mWh`)** | `71,590 - 71,600 mWh` | `42,260 mWh` (`42.26 Wh`) | `-29.34 Wh` stored energy |
| **Full Charge Capacity (`mWh`)** | `71,590 mWh` (`89.49%` of `80 Wh`) | `71,620 mWh` (`89.53%` of `80 Wh`, `LifePercent=90`) | `+30 mWh` (zero wear) |
| **Pack Voltage (`mV`)** | `17,305 mV` | `15,827 mV` | **`-1,478 mV`** |
| **Cell Voltage (`4S Li-Po`, `V/cell`)** | `4.326 V/cell` | `3.957 V/cell` (`3.9568 V/cell`) | **`-0.370 V/cell`** stress drop |
| **Battery Current / Rates** | `0 mA` (floating at `100%` ceiling) | `0 mA`, `ChargeRate = 0 mW`, `DischargeRate = 0 mW` | True zero-current bypass |
| **WMI `Charging` / `Discharging`** | `False` / `False` | `False` / `False` (`ChargeStatus = NoActivity`) | Idle EC charger state |
| **Battery Temperature (`°C`)** | `32 - 34 °C` | `34 °C` (`57m` after `43m` PUBG session) | Healthy thermal range |
| **Cycle Count** | `85` | `85` | **`+0` cycles added** |
| **CPU Boost (`AC` / `DC` `PERFBOOSTMODE`)** | `4` (`Efficient Aggressive`) / `2` | `4` (`Efficient Aggressive`) / `2` | Persisted across reboot |
| **GPU State (`nvidia-smi`, MUX dGPU-Only)** | `P8` idle | `P8`, `14.22 - 14.67 W`, `42 °C` | Normal dGPU-Only idle |
| **`\PUBGWirelessAndHzGuard`** | `Running` | `Running` (`LastRun = 16:21:04`, `PID 8208`, `WS = 4.0 MB`, `PM = 88.3 MB`) | Auto-started on AC plug-in |
| **System RAM** | ~`16.2 GB` total | `7,209 - 7,228 MB` free / `16,236 MB` (`55%` used) | Healthy headroom |

---

## 3. Full Chronological Timeline (`2026-11-09 23:08` to `2026-11-10 23:47`)

Data sources include [`battery_report_20261110.xml`](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/battery_report_20261110.xml), `Microsoft-Windows-Kernel-Power` / `Kernel-General` System events, and `C:\Program Files (x86)\Steam\logs\gameprocess_log.txt`.

| Local Time (`+07:00`) | Source / State | Capacity (`mWh` / `%`) | Duration | Energy Delta & Avg Power | Operational Event |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `2026-11-09 23:08:50` | `DC` (`Wake`) | `47,250` (`66.00%`) | `36s` | `-710 mWh` | Woke on battery from afternoon sleep |
| `2026-11-09 23:09:26` | `DC` (`Active`) | `46,540` (`65.01%`) | `1m 15s` | `0 mWh` | Brief battery use before AC plug-in |
| `2026-11-09 23:10:41` | `AC` (`Active`) | `46,540` -> `71,600` (`65.0%` -> `100.0%`) | `2h 24m 19s` | **`+25.06 Wh`** (charged under `Normal` mode) | Played *Half Sword Demo* (`23:38-23:54`) & *Volleyball Mania* (`23:58-00:08`); enabled `Storage` (`00:37-01:24`) after pack already hit `100%` |
| `2026-11-10 01:36:34` | `Shutdown` (`ID 13`) | `71,600` (`100.0%`) | `13h 05m 20s` | `0 Wh` | Full OS shutdown overnight (`01:36:34` -> `14:41:54`) |
| `2026-11-10 14:41:54` | `DC` (`Cold Boot`) | `71,630` (`100.0%`) | `21m 54s` (`14:42:13-15:04:07`) | `-7.88 Wh` (**`21.59 W`** drain) | Cold boot unplugged; dGPU-Only normal profile (`InCampusMode=False`) |
| `2026-11-10 15:04:07` | `DC` (`Suspend`) | `63,750` -> `63,030` (`89.0%` -> `88.0%`) | `43.5s` | `-0.72 Wh` | Brief button/lid sleep (`Event ID 42` / `107`) |
| `2026-11-10 15:04:50` | `DC` (`Active`) | `63,030` -> `53,000` (`88.0%` -> `74.0%`) | `30m 45s` | `-10.03 Wh` (**`19.57 W`** drain) | Unplugged active discharge |
| `2026-11-10 15:35:35` | `DC` (`Suspend`) | `53,000` -> `52,290` (`74.0%` -> `73.0%`) | `20m 55s` | `-0.71 Wh` (**`2.04 W`** sleep drain) | System idle sleep |
| `2026-11-10 15:56:30` | `DC` (`Active`) | `52,290` -> `42,260` (`73.0%` -> `59.01%`) | `24m 25s` | `-10.03 Wh` (**`24.64 W`** drain) | Discharged cleanly into the `55%-60%` target window (`59.01%`) |
| `2026-11-10 16:20:55` | **`AC` (`Plugged In`)** | **`42,260` (`59.01%`)** | **`7h 26m 47s`** (`16:20:55-23:47:42`) | **`0.00 Wh` (`0 mWh` change)** | AC plugged in (`Event ID 105`); `\PUBGWirelessAndHzGuard` auto-fired `9s` later at `16:21:04`; EC locked `ChargeRate = 0 mW` |
| `2026-11-10 22:07:53` | `AC` (`PUBG Load`) | **`42,260` (`59.01%`)** | `42m 51s` (`22:07:53-22:50:44`) | **`0.00 Wh` (`0 mWh` change)** | Played **PUBG (`AppID 578080`)** on AC; zero charging above `59%` and zero hybrid battery drain |
| `2026-11-10 23:47:42` | `AC` (`Audit Scan`) | **`42,260` (`59.01%`)** | Live | `0 mW` / `15,827 mV` / `34 °C` | Audit report generated; battery flat at `42,260 mWh` |

---

## 4. Operational Notes from [`CheDoDiHoc_CuuHo.ps1`](file:///C:/Users/Admin/.gemini/antigravity/scratch/pc-optimizer/CheDoDiHoc_CuuHo.ps1) `-Status`

1. **Smart Advisor Case A Suppressed Correctly.** Because `RemainingPercent = 59%` (`<= 65%`) while `ChargeMode = Storage`, the `[Ở NHÀ - CHỐNG CHAI PIN]` warning no longer triggers. Only informational Case D (`[NẾU SẮP ĐI HỌC]`) displays.
2. **Afternoon Discharge Rate Limiter (`21.75 W` active average).** During the `14:42 - 16:20` unplugged discharge, `Hybrid Mode` was `Off` (`dGPU-Only`, RTX 3060 awake at `~14.5 W`) and `InCampusMode` was `False` (`DC Boost = 2`). That `21.75 W` rate was helpful for intentionally draining `100% -> 59%` at home in `77` active minutes, whereas actual campus battery sessions should use `[1]`/`[2]` plus Lenovo Vantage `Hybrid Mode = ON`.
3. **Screen Brightness Note.** Live brightness currently reads `10%` (user-adjusted tonight).

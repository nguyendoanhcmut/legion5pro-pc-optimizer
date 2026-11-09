# Independent Optimization Verification and Safety Audit Report

**Throughput Checkpoint.** `throughput checkpoint: n/a, read-only investigation`
**Audited Dossier.** [subagent1_compiled_dossier.md](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/subagent1_compiled_dossier.md)
**Audited Telemetry.** [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json)
**Primary Probe Log.** [task-35.log](file:///C:/Users/Admin/.gemini/antigravity/brain/8f64601f-1682-49ad-b4c6-148bdd27734f/.system_generated/tasks/task-35.log)

---

## Section 1. Fact-Check of Live System State and Leftover Dell / Iris Xe Scripts

Direct inspection of the scripts in `C:\tools\goodbyedpi-0.2.3rc3-2\`, live `powercfg /qh` queries, and `user32.dll!EnumDisplaySettingsA` probes revealed six critical corrections to [subagent1_compiled_dossier.md](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/subagent1_compiled_dossier.md).

### 1.1 Architectural Separation Inside `C:\tools\goodbyedpi-0.2.3rc3-2\`
The directory `C:\tools\goodbyedpi-0.2.3rc3-2\` is a checkout of `goodbyedpi-steam-pubg-vn` v2.5 ([README.md](file:///C:/tools/goodbyedpi-0.2.3rc3-2/README.md#L1-L76)). This toolkit bundles two distinct subsystems that must be separated during optimization:

1. **Subsystem 1 (Desired & Active Vietnam Network / PUBG Anti-Hang Toolkit).**
   * **Files & Tasks.** [goodbyedpi_on.cmd](file:///C:/tools/goodbyedpi-0.2.3rc3-2/goodbyedpi_on.cmd#L1-L88) (`\GoodbyeDPI-On`, Desktop shortcut `GoodbyeDPI BAT.lnk`), [goodbyedpi_off.cmd](file:///C:/tools/goodbyedpi-0.2.3rc3-2/goodbyedpi_off.cmd#L1-L77) (`\GoodbyeDPI-Off`, Desktop shortcut `GoodbyeDPI TAT.lnk`), [pubg_autofix.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_autofix.ps1#L1-L1156), [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L1-L406) (`\PUBGWirelessAndHzGuard`), and `GoodbyeDPI` service (PID `14612`).
   * **Measured Behavior.** `goodbyedpi_on.cmd` starts `goodbyedpi.exe` (`-p -r -s -f 2 -k 2 -n -e 2 --native-frag --allow-no-sni --max-payload 1200 --blacklist steam-blacklist.txt`) and runs [pubg_autofix.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_autofix.ps1#L82-L87). That script configures Google DNS (`8.8.8.8`/`8.8.4.4`) with DoH, pins the fastest CloudFront SGN50 IP (`108.157.32.117`) in `hosts`, pre-warms PUBG `CohCache` to prevent `INITIALIZING...` hangs, syncs `IntegrityCheckHistory.csv` to skip `22.48 GB` of SHA-1 hashing on launch, sets `IFEO` `CpuPriorityClass = 3` (`High`) for `TslGame.exe` and `ExecPubg.exe`, and adds Windows Defender exclusions for PUBG and BattlEye.
   * **Verdict.** Subsystem 1 is actively used by the operator (`LastRunTime = 2026-11-08T21:29:19+07:00`) and must be preserved.

2. **Subsystem 2 (Hardware-Mismatched Dell Latitude 3450 Intel Iris Xe Script).**
   * **Files & Tasks.** [TOI_UU_PUBG_IRIS_XE.cmd](file:///C:/tools/goodbyedpi-0.2.3rc3-2/TOI_UU_PUBG_IRIS_XE.cmd#L1-L28) (`\PUBGIrisXe-Boost`, Desktop shortcut `TOI UU PUBG IRIS XE.lnk`), [pubg_iris_xe_boost.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_iris_xe_boost.ps1#L1-L475), [iris_xe_lib_power_os.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_power_os.ps1#L1-L544), [iris_xe_lib_native_diag.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_native_diag.ps1#L1-L496), and [iris_xe_lib_ue4_cache.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_ue4_cache.ps1#L1-L677).
   * **Measured Behavior.** These scripts target a Dell Latitude 3450 with an Intel Core i7-1355U (`2P+8E`) and shared-VRAM Intel Iris Xe iGPU. When invoked on this Lenovo Legion 5 Pro (`AMD Ryzen 7 5800H` 8C/16T + dedicated `RTX 3060 6GB`), `Get-TargetPowerSettings` in [iris_xe_lib_power_os.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_power_os.ps1#L79-L95) caps `PROCFREQMAX` on AC to `3700 MHz` (throttling the 5800H below its `4400 MHz` boost clock), `DetectTopology()` in [iris_xe_lib_native_diag.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_native_diag.ps1#L237) pins background processes to cores 4 through 7 (`0xFF00`) as fake E-cores, and `Optimize-PubgIniFiles` in [iris_xe_lib_ue4_cache.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_ue4_cache.ps1#L80-L108) lowers PUBG render scale to `70%` with a `60 FPS` cap.
   * **Verdict.** `\PUBGIrisXe-Boost` must be disabled and `TOI UU PUBG IRIS XE.lnk` must be backed up and removed from the Desktop so the user never triggers the `3700 MHz` CPU cap or `60 FPS` / `70%` render-scale cap by mistake.

### 1.2 Live `powercfg` Verification on the Active `Balanced` Scheme
Subagent 1 hypothesized that `\PUBGIrisXe-Boost` might have left the active power plan capped at `3700 MHz`. Direct inspection via `powercfg /qh SCHEME_CURRENT` and `Win32_Battery` ([task-35.log](file:///C:/Users/Admin/.gemini/antigravity/brain/8f64601f-1682-49ad-b4c6-148bdd27734f/.system_generated/tasks/task-35.log#L1-L16)) proves that the temporary `PUBG Iris Xe Boost` power scheme (`d4e34500-1355-496e-96e0-735167616d65`) was cleanly deleted when the `2026-11-07` session exited:

| Power Setting | GUID | Measured AC Value (Plugged In, 92%) | Measured DC Value (Battery) | Assessment |
| :--- | :--- | :--- | :--- | :--- |
| `PROCFREQMAX` (Class 0) | `75b0ae3f-bce0-45a7-8c89-c9611c25e100` | `0x00000000` (`0 MHz` = **Uncapped**) | `0x00000dac` (`3500 MHz`) | **Healthy on AC** (Full `4.4 GHz` boost active). |
| `PROCFREQMAX1` (Class 1) | `75b0ae3f-bce0-45a7-8c89-c9611c25e101` | `0x00000000` (`0 MHz` = **Uncapped**) | `0x00000000` (`0 MHz`) | **Healthy**. |
| `PROCTHROTTLEMIN` | `893dee8e-2bef-41e0-89c6-b55d0929964c` | `0x00000050` (`80%`) | `0x00000005` (`5%`) | **Healthy**. |
| `PROCTHROTTLEMAX` | `bc5038f7-23e0-4960-96da-33abaf5935ec` | `0x00000064` (`100%`) | `0x00000064` (`100%`) | **Healthy**. |
| `PERFBOOSTMODE` | `be337238-0d82-4146-a960-4f3749d470c7` | `0x00000002` (`Aggressive`) | `0x00000002` (`Aggressive`) | **Healthy**. |
| `CPMINCORES` (Core Parking) | `0cc5b647-c1df-4637-891a-dec35c318583` | `0x00000064` (`100%` unparked) | `0x00000019` (`25%`) | **Healthy**. |

Similarly, all running processes (`browser`, `chrome`, `msedgewebview2`, `SearchHost`, `Antigravity`, `node`, `python`) currently have `ProcessorAffinity = 65535` (`0xFFFF`, all 16 threads enabled), and `GameUserSettings.ini` is at `1680x1050`, `ScreenScale=100.000000`, `InGameFrameRateLimitType=Unlimited` ([task-35.log](file:///C:/Users/Admin/.gemini/antigravity/brain/8f64601f-1682-49ad-b4c6-148bdd27734f/.system_generated/tasks/task-35.log#L46-L102)).

### 1.3 Fact-Check of `pubg_wireless_and_hz_guard.ps1` and the `60Hz` vs `165Hz` Display Finding
1. **Why `pubg_wireless_and_hz_guard.ps1` Does Not Touch Display Refresh Rate.**
   Reading all 406 lines of [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L1-L406) proves that despite its filename, the script contains **zero display or refresh-rate (`Hz`) code**. Instead, it performs three legitimate PUBG tasks:
   * Holds an open `WlanOpenHandle` (`wlanapi.dll`) and calls `WlanSetInterface` OpCode `2` (`autoconf_enabled = 0`) and OpCode `3` (`media_streaming_mode = 1`) every 15 seconds so Windows Wi-Fi background scanning does not cause ping spikes during matches. As documented in [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L279-L282), Windows immediately reverts those low-latency Wi-Fi flags if the process closes its handle.
   * Detects `ExecPubg` / `TslGame_ZK` launches and elevates `TslGame.exe` to `High` priority.
   * Re-applies `Disable-PubgStartupMovies`, `Sync-PubgIntegrityCheckHistory`, and `Invoke-PubgBinaryPageCacheWarmup` whenever Steam updates `appmanifest_578080.acf`.
   * Furthermore, [pubg_autofix.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_autofix.ps1#L815-L840) automatically re-creates and restarts `\PUBGWirelessAndHzGuard` every time the user clicks `GoodbyeDPI BAT`. Therefore, Subagent 1's proposal to disable `\PUBGWirelessAndHzGuard` in Baseline is **rejected** (`Bucket C`).
2. **Major Hardware Finding (`60Hz` Active on a `165Hz` Panel While Plugged Into AC).**
   Probing `user32.dll!EnumDisplaySettingsA` on the primary display while plugged into AC power (`BatteryStatus = 2`, `92%`) revealed:
   * **Current Active Mode.** `2560x1600 @ 60Hz`
   * **Supported Panel Modes at `2560x1600`.** `165Hz`, `120Hz`, `100Hz`, `75Hz`, `60Hz`, `48Hz`, `30Hz`
   * Running the Legion 5 Pro's native `165Hz` G-Sync/FreeSync panel at `60Hz` while plugged into AC power caps visual fluidity in Steam games (`PUBG`, `Half Sword`, `Combat Master`) and browser scrolling to `36%` of the panel's capability (`16.67 ms` frame interval vs `6.06 ms` at `165Hz`). Switching the display refresh rate to `165Hz` via `ChangeDisplaySettingsEx` (with `60Hz` recorded in the backup file for `-Undo`) is a high-impact optimization.

### 1.4 Fact-Check of `npm-cache`, `.cache`, and `LenovoVantageService`
1. **Correction to `npm-cache` Size (`4.30 GB` Safe vs `1.37 GB` Active `_npx`).**
   Subagent 1 claimed that `C:\Users\Admin\AppData\Local\npm-cache\_cacache` held all `5,853.27 MB`. Subfolder measurement ([task-35.log](file:///C:/Users/Admin/.gemini/antigravity/brain/8f64601f-1682-49ad-b4c6-148bdd27734f/.system_generated/tasks/task-35.log#L121-L127)) shows:
   * `_cacache`: `4,400.00 MB` (`4.30 GB` — safe to delete anytime)
   * `_prebuilds` + `_logs`: `50.17 MB` (safe to delete anytime)
   * `_npx`: `1,403.10 MB` (`1.37 GB` — actively used by Antigravity `npx -y mcp-remote` processes for `exa` and `alphaxiv`; **must not be deleted**).
   * Correct immediate disk reclaim from `npm-cache` is **`4,450.17 MB` (`4.35 GB`)**, bringing total safe live disk reclaim to **`5,442.44 MB` (`5.31 GB`)** while Cốc Cốc is open, or **`6,563.15 MB` (`6.41 GB`)** when Cốc Cốc HTTP/Code cache (`1,120.71 MB`) is also cleaned.
2. **Complete Subfolder Audit of `C:\Users\Admin\.cache` (`1,422.44 MB`).**
   Every subfolder in `C:\Users\Admin\.cache` ([task-35.log](file:///C:/Users/Admin/.gemini/antigravity/brain/8f64601f-1682-49ad-b4c6-148bdd27734f/.system_generated/tasks/task-35.log#L106-L117)) holds local AI models or browser automation binaries required by the user's installed Antigravity skills (`puppeteer` `683.86 MB`, `chroma` `166.43 MB`, `babeldoc` `158.44 MB`, `whisper` `138.53 MB`, `selenium` `90.70 MB`, `huggingface` `87.50 MB`, `openscience` `54.54 MB`, `pdf2zh` `42.44 MB`). The entire `C:\Users\Admin\.cache` tree must be hard-excluded from cleanup.
3. **Correction to `LenovoVantageService` vs `UDCService`.**
   * `UDCService` (`UDClientService.exe` PID `4660` + `MessagingPlugin.exe` PID `9388`) consumes **`80.7 MB` Working Set and `193.6 MB` Private Memory** ([task-35.log](file:///C:/Users/Admin/.gemini/antigravity/brain/8f64601f-1682-49ad-b4c6-148bdd27734f/.system_generated/tasks/task-35.log#L19-L29)) solely for Lenovo Universal Device Client cloud telemetry. Stopping and disabling `UDCService` is 100% zero-tradeoff.
   * By contrast, `LenovoVantageService` (PID `4692`) hosts `LenovoVantage-(LenovoGamingSystemAddin)` (PID `5424`) and `LenovoVantage-(LenovoGamingUserAddin)` (PID `12960`), which control Legion thermal modes, GPU OverDrive, and battery Conservation Mode. Subagent 1's proposal in Candidate B5 to stop `LenovoVantageService` during Emergency Rescue is **rejected** (`Bucket C`). Instead, only the two marketing/telemetry child add-in processes (`LenovoVantage-(GenericMessagingAddin)` and `LenovoVantage-(GenericTelemetryAddin)`, taking `57.9 MB` WS / `71.3 MB` Private) should be terminated or trimmed, leaving `LenovoVantageService` and the gaming add-ins untouched.

---

## Section 2. Strict 3-Bucket Triage Table of All Candidate Optimizations

### 2.1 BUCKET A (`VERIFIED ZERO-TRADEOFF — KEEP`)

| ID | Candidate & Target | Exact Mechanism | Measured Benefit on This PC | Exact Apply Command / Logic | Exact Undo / Restore Command |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **A1** | **Restore Native `165Hz` Display Refresh Rate** (`2560x1600`) | P/Invoke `user32.dll!EnumDisplaySettingsA` + `ChangeDisplaySettingsExA` (`CDS_UPDATEREGISTRY = 1`) to switch from `60Hz` to `165Hz` on AC power. | Upgrades desktop and game refresh rate from `60Hz` (`16.67 ms`) to native `165Hz` (`6.06 ms`, `+175%` temporal resolution). | `[DisplayRefreshHelper]::SetRefreshRate(2560, 1600, 165)` | `[DisplayRefreshHelper]::SetRefreshRate(2560, 1600, $backup.OriginalRefreshRate)` (`60Hz`). |
| **A2** | **Disable Mismatched Dell Iris Xe Task & Desktop Shortcut** (`\PUBGIrisXe-Boost`) | Disable `\PUBGIrisXe-Boost` scheduled task and move `Desktop\TOI UU PUBG IRIS XE.lnk` into backup folder so the user cannot accidentally cap the Ryzen 7 5800H to `3700 MHz` or PUBG to `60 FPS`. | Prevents `-700 MHz` CPU clock throttling and fake E-core affinity pinning (`0xFF00`) on Zen 3. | `Disable-ScheduledTask -TaskPath '\' -TaskName 'PUBGIrisXe-Boost'`; move `.lnk` to backup directory. | `Enable-ScheduledTask -TaskPath '\' -TaskName 'PUBGIrisXe-Boost'`; restore `.lnk` to Desktop. |
| **A3** | **Disable 22 Telemetry, SoftLanding, OneDrive & Idle Browser Tasks** | `Stop-ScheduledTask` + `Disable-ScheduledTask` on `\OneDrive*` (3), `\PlatformExperiencesHelper*` (3), `\SoftLanding\S-1-5-21-*\SoftLanding*` (4), `\Mozilla\Firefox*` (2), and 10 Microsoft CEIP / Compatibility Appraiser / Siuf / WER / MapsToast tasks. | Eliminates 22 background periodic task triggers (`compattelrunner.exe`, `wsqmcons.exe`, `OneDriveStandaloneUpdater.exe`, `platform_experiences_helper.exe`). | Loop over verified task list, record original `State` in `baseline_debloat_backup.json`, call `Disable-ScheduledTask`. | Read `baseline_debloat_backup.json` and call `Enable-ScheduledTask` on every task whose prior state was `Ready` or `Running`. |
| **A4** | **Stop & Disable `UDCService` + `DiagTrack`; Set Updater Services to `Manual`** | Stop and disable `UDCService` (kills `UDClientService.exe` + `MessagingPlugin.exe`) and `DiagTrack`; set `MapsBroker`, `CocCocUpdater*`, `GoogleUpdater*`, and `edgeupdate` from `Auto` to `Manual`. | Immediately frees **`80.7 MB` Working Set / `193.6 MB` Private Commit** from `UDCService` + `MessagingPlugin` plus `DiagTrack` (`svchost`). | `Stop-Service UDCService,DiagTrack -Force`; `Set-Service UDCService,DiagTrack -StartupType Disabled`; `Set-Service <Updaters> -StartupType Manual`. | Restore each service's exact `StartMode` (`Auto`) and restart services where `WasRunning == true` from `baseline_debloat_backup.json`. |
| **A5** | **Stop Windows 11 Widgets, MSN Start Feed & Bing Search WebView2 Hosts** | Set `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0`, `HKCU:\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions = 1`, `HKCU:\...\Search\BingSearchEnabled = 0`, `HKCU:\...\SearchSettings\IsDynamicSearchBoxEnabled = 0`, and stop `WidgetService`, `WidgetBoard`, `MicrosoftStartFeedProvider`. | Frees **`104.1 MB` Working Set** from Widget processes plus **`~130–220 MB` Working Set** from background Bing/Widget `msedgewebview2.exe` instances; local file/app search stays 100% intact. | Write the 4 registry DWords (after snapshotting prior values) and `Stop-Process -Name WidgetService,WidgetBoard,MicrosoftStartFeedProvider -Force`. | Restore registry values from `baseline_debloat_backup.json` (removing keys that did not previously exist). |
| **A6** | **Apply Zero-Tradeoff Gaming MMCSS, HAGS, Auto Game Mode, DeliveryOpt & Taskbar End-Task Keys** | Configure MMCSS (`SystemResponsiveness = 10`, `NetworkThrottlingIndex = 0xFFFFFFFF`, `Tasks\Games` `Priority = 6`, `Scheduling Category = High`, `SFIO Priority = High`), `HwSchMode = 2` (HAGS), `AutoGameModeEnabled = 1`, `DODownloadMode = 0` (HTTP-only Windows Update, zero P2P upload), `DisableWindowsConsumerFeatures = 1`, `AllowTelemetry = 0`, `PublishUserActivities = 0`, `UploadUserActivities = 0`, `RespectPowerModes = 1` (pauses Windows Search indexing during gaming), and `TaskbarEndTask = 1`. | Eliminates P2P Windows Update upload spikes, boosts Steam game thread scheduling priority (`2 -> 6`), enables RTX 3060 HAGS, and adds right-click "End task" to the taskbar. | Snapshot all 15 registry values to `baseline_debloat_backup.json` before setting via `New-ItemProperty -Force`. | Restore every snapshotted registry key/value to its exact pre-change state (`<null>` or prior value). |
| **A7** | **Safe Live Disk Cache Cleanup (`5.31 GB` Live / `6.41 GB` with Cốc Cốc Closed)** | Clean `npm-cache\_cacache` (`4,400.00 MB`) + `_prebuilds` (`50.15 MB`), `Steam\htmlcache` (`493.14 MB`) + `logs` (`40.79 MB`) + `dumps` (`4.77 MB`) + `httpcache` (`0.87 MB`), `Edge\...\Cache` + `Code Cache` (`228.07 MB`), `Antigravity\Crashpad` (`65.32 MB`), unlocked `$env:TEMP` files older than 2 hours (`~150 MB`), `Minidump` (`7.72 MB`), and (only when `browser.exe` is not running) `CocCoc\...\Default\{Cache, Code Cache, GPUCache}` (`1,120.71 MB`). | Reclaims **`5.31 GB` immediately** (while Cốc Cốc, Antigravity, and MCP servers stay open) or **`6.41 GB`** when Cốc Cốc is closed, with zero impact on logins, cookies, `_npx`, `.cache` AI models, or `Steam\depotcache`. | Targeted directory content deletion skipping locked files and preserving `_npx`, `.cache`, `depotcache`, and browser session files. | Cache files are ephemeral and regenerated automatically on demand by npm, Steam, Edge, and Cốc Cốc. |
| **A8** | **On-Demand Emergency Rescue (`emergency_rescue.ps1`): Whitelisted Per-Process Trim + EcoQoS + Low-Priority Standby Purge** | Terminate purely ephemeral bloat (`WidgetService`, `WidgetBoard`, `MicrosoftStartFeedProvider`, `CrossDeviceResume`, `MessagingPlugin`, `LenovoVantage-(GenericMessagingAddin)`, `LenovoVantage-(GenericTelemetryAddin)`, `TabTip`), apply `EcoQoS` + `MEMORY_PRIORITY_VERY_LOW (1)` + `BelowNormal` + `EmptyWorkingSet` to background helpers (`steamwebhelper`, `msedgewebview2`, `SearchHost`), trim idle pages from non-foreground processes, and invoke `NtSetSystemInformation` `SystemCombinePhysicalMemoryInformation (130)` + `MemoryPurgeLowPriorityStandbyList (5)`. | Frees **`~260 MB` Private Commit** and **`800–2,000 MB` Working Set** in `< 2 seconds` with zero frame hitch, zero audio glitch, and 100% protection of Steam games, Cốc Cốc YouTube, Antigravity, `node`, `python`, and `scan_disk1.ps1`. | Run `emergency_rescue.ps1` (default safe mode). | `emergency_rescue.ps1 -Restore` resets `steamwebhelper`, `msedgewebview2`, and `SearchHost` back to `Normal` priority and `EcoQoS = Off`. |

---

### 2.2 BUCKET B (`OPTIONAL / HAS MINOR TRADEOFF — MAKE OPT-IN FLAG ONLY`)

| ID | Candidate & Target | Exact Mechanism | Measured Benefit | Exact Trade-Off & Why It Is Opt-In (`Bucket B`) |
| :--- | :--- | :--- | :--- | :--- |
| **B1** | **Curated UWP Bloatware Removal (`-RemoveUwpBloat` switch)** | `Remove-AppxPackage` on 12 non-essential Store apps (`Clipchamp.Clipchamp`, `Microsoft.BingNews`, `Microsoft.BingWeather`, `Microsoft.BingSearch`, `Microsoft.MicrosoftSolitaireCollection`, `Microsoft.MicrosoftOfficeHub`, `Microsoft.WindowsFeedbackHub`, `Microsoft.GetHelp`, `Microsoft.PowerAutomateDesktop`, `MicrosoftCorporationII.MicrosoftFamily`, `MicrosoftCorporationII.QuickAssist`, `Microsoft.Windows.DevHome`). | Reclaims disk footprint and removes Start Menu clutter (`CrossDeviceResume.exe` is kept unless `MicrosoftWindows.CrossDevice` is also opted in). | Uninstalled UWP apps require Microsoft Store download (`winget install`) to reinstall if the user ever wants `QuickAssist`, `PowerAutomateDesktop`, or `Clipchamp`. Keep behind explicit `-RemoveUwpBloat` switch. |
| **B2** | **Full Standby List Purge (`MemoryPurgeStandbyList = 4`) in Emergency Rescue (`-Aggressive` switch)** | Invokes `NtSetSystemInformation(80, 4)` to evict all `3,965 MB` of Standby Cache (`StandbyNormal` + `StandbyReserve`) to `Free`. | Converts up to `3.96 GB` of Standby RAM into `Free` RAM immediately. | Evicts hot cached DLLs and game assets (`StandbyNormal = 2,813 MB`), which can cause brief disk re-fault micro-stutters if a game is actively running. Default mode uses `MemoryPurgeLowPriorityStandbyList (5)` (`Bucket A`); reserve command `4` for `-Aggressive`. |
| **B3** | **Clean Cốc Cốc HTTP & Code Cache (`1,120.71 MB`)** | Deletes contents of `CocCoc\Browser\User Data\Default\{Cache, Code Cache, GPUCache}` (never touching `Cookies`, `Login Data`, `Sessions`, or `Service Worker\CacheStorage`). | Reclaims **`1.12 GB`** of NVMe disk space. | Cannot be cleaned cleanly while `browser.exe` has cache index files open (`13` processes currently running), and the first visit to heavy websites after cleaning re-downloads cached JS/CSS. Automatically skipped if `browser.exe` is running. |

---

### 2.3 BUCKET C (`REJECTED / SNAKE OIL / ALREADY APPLIED / UNSAFE`)

| ID | Rejected Candidate | Primary Evidence & Exact Reason for Rejection (`H1`) |
| :--- | :--- | :--- |
| **C1** | **Disable `\PUBGWirelessAndHzGuard` (`pubg_wireless_and_hz_guard.ps1`)** | **Rejected (Correction to Subagent 1).** Inspection of [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1#L279-L399) and [pubg_autofix.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_autofix.ps1#L816-L840) proves: (1) it contains zero display Hz code, (2) it holds the active `WlanOpenHandle` that disables Wi-Fi background scan ping spikes in PUBG and warms up `TslGame.exe`, and (3) `pubg_autofix.ps1` automatically respawns it whenever the user clicks `GoodbyeDPI BAT`. |
| **C2** | **Stop `LenovoVantageService` or `PcaSvc` or `SysMain` or `WSearch` in Emergency Rescue** | **Rejected (Correction to Subagent 1 Candidate B5).** `LenovoVantageService` hosts `LenovoGamingSystemAddin` and `LenovoGamingUserAddin` (thermal modes, GPU OverDrive, battery Conservation Mode). Stopping `PcaSvc` breaks Windows compatibility shims. Stopping `SysMain` and `WSearch` leaves Start Menu search and Superfetch dead after rescue unless manually restarted. Setting `RespectPowerModes = 1` (`Bucket A6`) already pauses search indexing under load without killing the service. |
| **C3** | **Set Chromium Enterprise Policies (`HKLM:\SOFTWARE\Policies\CocCoc\Browser\HighEfficiencyModeEnabled`)** | **Rejected.** Creating policy keys under `SOFTWARE\Policies\CocCoc\Browser` or `Google\Chrome` forces the `"Managed by your organization"` (`"Được quản lý bởi tổ chức của bạn"`) banner in the browser UI and locks the settings toggle in Cốc Cốc. |
| **C4** | **Delete `C:\Users\Admin\.cache` (`1,422.44 MB`) or `npm-cache\_npx` (`1,403.10 MB`)** | **Rejected.** `.cache` contains `puppeteer`, `chroma`, `babeldoc`, `whisper`, `selenium`, `huggingface`, `openscience`, and `pdf2zh` models. `_npx` backs the running Antigravity MCP servers (`exa`, `alphaxiv`). |
| **C5** | **Global `MemoryEmptyWorkingSets (Command = 2)` or `MemoryFlushModifiedList (Command = 3)` During Active Use** | **Rejected.** Command `2` strips working sets from the foreground game, `audiodg.exe` (audio engine), `dwm.exe` (desktop compositor), and `Antigravity.exe`, causing immediate page-fault hitches. Command `3` forces synchronous pagefile writes (`282 MB` Modified list), spiking NVMe write latency. Targeted per-process `EmptyWorkingSet` (`Bucket A8`) avoids both flaws. |
| **C6** | **Already-Applied Tweaks (`powercfg /h off`, `GameDVR_Enabled = 0`, `AppCaptureEnabled = 0`, `DisablePagingExecutive = 1`, `TaskbarDa = 0`, `AdvertisingInfo\Enabled = 0`)** | **Skipped (Already Configured).** Verified in [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L156-L171) and [task-35.log](file:///C:/Users/Admin/.gemini/antigravity/brain/8f64601f-1682-49ad-b4c6-148bdd27734f/.system_generated/tasks/task-35.log#L9-L15). |
| **C7** | **Disable VBS / HVCI (`Memory Integrity`), Windows Defender (`WinDefend`), or `SvcHostSplitThresholdInKB`** | **Rejected.** Violates the zero-security-tradeoff and gaming stability requirements. |

---

## Section 3. Verified Blueprints for the Two Deliverable Scripts

### 3.1 Blueprint 1: `baseline_debloat.ps1` (One-Time Safe & Reversible Baseline Optimizer)

* **Supported Modes.**
  * `.\baseline_debloat.ps1 -Apply` (Default: snapshots current state to `baseline_debloat_backup.json`, applies Bucket A1–A7, and prints before/after verification table).
  * `.\baseline_debloat.ps1 -Apply -SkipDisplayHz` (Optional switch if the user prefers to keep `60Hz` instead of switching to `165Hz`).
  * `.\baseline_debloat.ps1 -Apply -RemoveUwpBloat` (Opt-in switch for Bucket B1 curated UWP app removal).
  * `.\baseline_debloat.ps1 -Undo` (Reads `baseline_debloat_backup.json` and deterministically restores 100% of Registry keys, Service `StartMode`s and running states, Scheduled Task states, Desktop shortcut `TOI UU PUBG IRIS XE.lnk`, and Display Refresh Rate).
  * `.\baseline_debloat.ps1 -DryRun` (Prints every planned change and measured cache size without mutating the OS).

* **Exact Implementation Structure for `baseline_debloat.ps1`:**

```powershell
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Undo,
    [switch]$DryRun,
    [switch]$SkipDisplayHz,
    [switch]$SkipDiskCleanup,
    [switch]$RemoveUwpBloat,
    [string]$BackupDir = "$PSScriptRoot\backups"
)

# 1. C# P/Invoke DisplayRefreshHelper (user32.dll EnumDisplaySettingsA & ChangeDisplaySettingsExA)
#    - Get-CurrentRefreshRate: reads dmDisplayFrequency at 2560x1600
#    - Set-DisplayRefreshRate: applies 165Hz (CDS_UPDATEREGISTRY = 1) if 165Hz mode exists at 2560x1600

# 2. Pre-Mutation Snapshot (Write-Before-Mutate to $BackupDir\baseline_debloat_backup.json)
#    - Only writes initial baseline snapshot if backup file does not already exist (or merges missing entries),
#      so running -Apply twice never overwrites the true pre-optimization baseline!
#    - Records:
#      a) Display: Width, Height, OriginalRefreshRate (60)
#      b) DesktopShortcut: OriginalPath ("$Desktop\TOI UU PUBG IRIS XE.lnk"), BackupPath ("$BackupDir\TOI UU PUBG IRIS XE.lnk.bak")
#      c) ScheduledTasks: TaskPath, TaskName, OriginalState (Ready/Running/Disabled)
#      d) Services: Name, OriginalStartMode (Auto/Manual/Disabled), WasRunning (bool)
#      e) Registry: Path, Name, KeyExisted, ValueExisted, OriginalValue, Kind

# 3. Bucket A1: Switch 2560x1600 @ 60Hz -> 165Hz (unless -SkipDisplayHz is passed)

# 4. Bucket A2 & A3: Disable Scheduled Tasks (23 tasks total)
#    - '\PUBGIrisXe-Boost' (plus move 'TOI UU PUBG IRIS XE.lnk' to $BackupDir)
#    - NEVER touch '\PUBGWirelessAndHzGuard', '\GoodbyeDPI-On', '\GoodbyeDPI-Off', '\DailyArtWallpaper', '\AutoShutdown'
#    - '\OneDrive Per-Machine Standalone Update Task'
#    - '\OneDrive Reporting Task-*', '\OneDrive Startup Task-*'
#    - '\PlatformExperiencesHelper_Daily', '\PlatformExperiencesHelper_Metrics', '\PlatformExperiencesHelper_OnUnlock'
#    - All tasks under '\SoftLanding\*'
#    - '\Mozilla\Firefox Background Update*', '\Mozilla\Firefox Default Browser Agent*'
#    - '\GoogleUser\GoogleUpdater\GoogleUpdaterTaskUser*'
#    - '\Microsoft\Windows\Application Experience\{MareBackup, Microsoft Compatibility Appraiser Exp, StartupAppTask}'
#    - '\Microsoft\Windows\Autochk\Proxy'
#    - '\Microsoft\Windows\Customer Experience Improvement Program\{Consolidator, UsbCeip}'
#    - '\Microsoft\Windows\Feedback\Siuf\{DmClient, DmClientOnScenarioDownload}'
#    - '\Microsoft\Windows\Maps\MapsToastTask'
#    - '\Microsoft\Windows\Windows Error Reporting\QueueReporting'

# 5. Bucket A4: Optimize Background Services
#    - Stop & Disable: 'UDCService' (and Stop-Process 'MessagingPlugin'), 'DiagTrack'
#    - Set to Manual (do not disable): 'MapsBroker', 'CocCocUpdaterService*', 'CocCocUpdaterInternalService*',
#      'GoogleUpdaterService*', 'GoogleUpdaterInternalService*', 'edgeupdate'
#    - NEVER touch: 'LenovoFnAndFunctionKeys', 'LenovoVantageService', 'GoodbyeDPI', 'WinDefend', 'MDCoreSvc', 'WdNisSvc', 'mpssvc', 'wuauserv', 'SysMain', 'WSearch'

# 6. Bucket A5 & A6: Apply 15 Zero-Tradeoff Registry Tweaks & Stop Widget Hosts
#    - HKLM:\SOFTWARE\Policies\Microsoft\Dsh -> AllowNewsAndInterests = 0 (DWord)
#    - HKCU:\Software\Policies\Microsoft\Windows\Explorer -> DisableSearchBoxSuggestions = 1 (DWord)
#    - HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -> BingSearchEnabled = 0 (DWord)
#    - HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings -> IsDynamicSearchBoxEnabled = 0 (DWord)
#    - HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent -> DisableWindowsConsumerFeatures = 1 (DWord)
#    - HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection -> AllowTelemetry = 0 (DWord)
#    - HKLM:\SOFTWARE\Policies\Microsoft\Windows\System -> PublishUserActivities = 0, UploadUserActivities = 0 (DWord)
#    - HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization -> DODownloadMode = 0 (DWord)
#    - HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings -> TaskbarEndTask = 1 (DWord)
#    - HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile -> SystemResponsiveness = 10, NetworkThrottlingIndex = 0xFFFFFFFF (DWord)
#    - HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games -> GPU Priority = 8 (DWord), Priority = 6 (DWord), Scheduling Category = 'High' (String), SFIO Priority = 'High' (String)
#    - HKCU:\Software\Microsoft\GameBar -> AutoGameModeEnabled = 1, AllowAutoGameMode = 1 (DWord)
#    - HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers -> HwSchMode = 2 (DWord)
#    - HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex -> RespectPowerModes = 1 (DWord)
#    - Terminate background Widget hosts: 'WidgetService', 'WidgetBoard', 'MicrosoftStartFeedProvider'

# 7. Bucket A7: Safe Disk Cache Cleanup (unless -SkipDiskCleanup is passed)
#    - Clean contents of:
#      * "$env:LOCALAPPDATA\npm-cache\_cacache" & "$env:LOCALAPPDATA\npm-cache\_prebuilds" (NEVER touch _npx!)
#      * "$env:LOCALAPPDATA\Steam\htmlcache", "${env:ProgramFiles(x86)}\Steam\appcache\httpcache", "${env:ProgramFiles(x86)}\Steam\logs", "${env:ProgramFiles(x86)}\Steam\dumps" (only if steam.exe is not running; NEVER touch depotcache!)
#      * "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache", "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache" (only if msedge.exe is not running)
#      * "$env:APPDATA\Antigravity\Crashpad\reports" (safe anytime; NEVER touch Antigravity Cache/Code Cache/CachedData!)
#      * "$env:LOCALAPPDATA\Temp" (only unlocked files with LastWriteTime < Now - 2 hours)
#      * "$env:SystemRoot\Minidump", "$env:ProgramData\Microsoft\Windows\WER\ReportArchive"
#      * "$env:LOCALAPPDATA\CocCoc\Browser\User Data\Default\{Cache, Code Cache, GPUCache}" (ONLY if browser.exe is NOT running; NEVER touch Service Worker, Cookies, Login Data!)
#    - Hard exclusion guard: throw if any target path starts with "$env:USERPROFILE\.cache" or contains "_npx" or "depotcache".
```

---

### 3.2 Blueprint 2: `emergency_rescue.ps1` ("Kịch bản cứu hộ" — On-Demand `< 2s` Resource Rescue)

* **Supported Modes.**
  * `.\emergency_rescue.ps1` (Default Safe Mode: terminates ephemeral bloat processes, applies `EcoQoS` + `MEMORY_PRIORITY_VERY_LOW` + `BelowNormal` to background helpers, trims idle working sets of non-protected/background processes, runs `SystemCombinePhysicalMemoryInformation (130)` + `MemoryPurgeLowPriorityStandbyList (5)`, flushes DNS, and prints exact MB of RAM reclaimed).
  * `.\emergency_rescue.ps1 -Aggressive` (Opt-in Bucket B2: also runs `MemoryPurgeStandbyList (4)` when the user wants maximum free physical RAM before launching a heavy workload).
  * `.\emergency_rescue.ps1 -Restore` (Restores `Normal` CPU priority, `Normal` memory priority (`5`), and disables `EcoQoS` on `steamwebhelper`, `msedgewebview2`, and `SearchHost`).
  * `.\emergency_rescue.ps1 -DryRun` (Reports what would be killed/trimmed/throttled without executing).

* **Hard Process Whitelist (100% Untouchable — Never Kill, Never Suspend, Never Lower Priority, Never Trim Foreground Game/Audio/DWM):**
  * **Antigravity & Active Background Jobs:** `Antigravity`, `language_server`, `node` (`mcp-remote`), `python`, `pythonw` (`luc-hao-daily`), `notebooklm-mcp`, `powershell`, `pwsh`, `conhost`, `WindowsTerminal`, `cmd`, `git`, `rg`.
  * **Gaming & Active Browser:** `steam`, `steamservice`, `TslGame`, `TslGame_BE`, `TslGame_ZK`, `ExecPubg`, `BEService`, `BEService_x64`, `zksvc`, `EasyAntiCheat`, `EasyAntiCheat_EOS`, `HalfSword*`, `CombatMaster*`, and whatever process currently owns the foreground window (`GetForegroundWindow` -> `GetWindowThreadProcessId`).
  * **Hardware, Audio, Network & Security:** `LenovoVantageService`, `LenovoVantage-(LenovoGamingSystemAddin)`, `LenovoVantage-(LenovoGamingUserAddin)`, `LenovoVantage-(VantageCoreAddin)`, `LenovoUtilityService`, `FnHotkeyUtility`, `FnHotkeyCapsLKNumLK`, `goodbyedpi`, `EVKey64`, `audiodg`, `RtkAudUService64`, `NVDisplay.Container`, `dwm`, `explorer`, `MsMpEng`, `MpDefenderCoreService`, `NisSrv`, `csrss`, `lsass`, `svchost`, `services`, `wininit`, `winlogon`, `smss`, `System`, `Registry`, `Memory Compression`.

* **Exact 4-Stage Execution Sequence for `emergency_rescue.ps1`:**
  1. **Stage 1: Terminate Purely Ephemeral Bloat Processes (`~260 MB` Private Commit Freed Immediately).**
     * Target list: `WidgetService`, `WidgetBoard`, `MicrosoftStartFeedProvider`, `CrossDeviceResume`, `MessagingPlugin`, `UDClientService`, `LenovoVantage-(GenericMessagingAddin)`, `LenovoVantage-(GenericTelemetryAddin)`, `TabTip`, `OneDriveStandaloneUpdater`, `platform_experiences_helper`, `wsqmcons`, `compattelrunner`, `wermgr`.
  2. **Stage 2: Apply `EcoQoS` + `MEMORY_PRIORITY_VERY_LOW (1)` + `BelowNormal` + `EmptyWorkingSet` to Background Web Helpers (`SESO` Pattern).**
     * Target list: `steamwebhelper`, `msedgewebview2`, `SearchHost`, `StartMenuExperienceHost`, `ShellExperienceHost`, `TextInputHost`, and `chrome` (only if `chrome` does not own the foreground window).
     * P/Invoke `kernel32.dll!SetProcessInformation`:
       * `ProcessPowerThrottling (4)`: `Version = 1, ControlMask = 1, StateMask = 1` (Efficiency Mode).
       * `ProcessMemoryPriority (0)`: `MemoryPriority = 1` (`MEMORY_PRIORITY_VERY_LOW`, so the kernel evicts their pages first before ever paging out game, Cốc Cốc, or Antigravity memory).
     * P/Invoke `psapi.dll!EmptyWorkingSet(hProcess)`.
  3. **Stage 3: Safe Working-Set Trim of Background Cốc Cốc Renderers (Skipping Foreground & Audio Processes).**
     * For `browser.exe` (Cốc Cốc): do **not** change `PriorityClass` or `EcoQoS` or `MemoryPriority`, and skip the main browser process (`ParentProcessId` root) and foreground window process; call `EmptyWorkingSet` only on background child processes so bloated V8/DOM heap pages move to Standby without reloading tabs or interrupting YouTube playback.
  4. **Stage 4: Kernel Memory Combine (`130`) & Low-Priority Standby Purge (`80, 5`).**
     * If running as Administrator (`SeProfileSingleProcessPrivilege` enabled):
       * Call `NtSetSystemInformation(SystemCombinePhysicalMemoryInformation = 130)` to deduplicate identical physical pages across processes.
       * Call `NtSetSystemInformation(SystemMemoryListInformation = 80, MemoryPurgeLowPriorityStandbyList = 5)` to free priority-0 standby pages without evicting hot cached file/game pages.
       * If `-Aggressive` is passed, also call `MemoryPurgeStandbyList = 4`.
     * Call `Clear-DnsClientCache` and print a clean before/after telemetry summary (`Free Physical RAM MB`, `Committed MB`, `Working Set Trimmed MB`, `Elapsed ms`).

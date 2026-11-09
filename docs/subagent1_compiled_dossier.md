# System Baseline Reconnaissance & Optimization Candidate Dossier

**Primary Telemetry Artifact.** [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json)
**Collection Script.** [collect_baseline.ps1](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/collect_baseline.ps1)
**Throughput Checkpoint.** `throughput checkpoint: n/a, read-only investigation`

---

## Section 1. Exact Hardware, OS, Resource, Startup, Service, and Disk Cache Baseline

### 1.1 Hardware, OS, and Display Telemetry (Measured)
The target machine is a Lenovo Legion 5 Pro (`LENOVO 82JQ`, family `Legion R9000P2021H`) that runs Microsoft Windows 11 Home 64-bit (`10.0.26200`, Build `26200`). The system uptime is `4.03 days` (`96.79 hours`) since the last boot on `2026-11-05T22:41:41+07:00`.

| Subsystem | Measured Specification | Evidence / Notes |
| :--- | :--- | :--- |
| **System Model** | `LENOVO 82JQ` (`Legion R9000P2021H`) | Measured via `Win32_ComputerSystem` in [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L11-L15). |
| **OS Version** | Windows 11 Home `10.0.26200` (Build `26200`) | Measured via `Win32_OperatingSystem` in [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L4-L10). |
| **CPU** | AMD Ryzen 7 5800H (`8 Cores / 16 Threads`, Base `3201 MHz`, `4 MB` L2, `16 MB` L3) | Homogeneous Zen 3 Cezanne architecture. It has no hybrid P/E core split. |
| **Discrete GPU** | NVIDIA GeForce RTX 3060 Laptop GPU (`6,144 MB` GDDR6, Driver `546.30` / `31.0.15.4630`) | `nvidia-smi` reports `907 MiB` used, `5,102 MiB` free, and `38 C` GPU temp. |
| **Display** | `2560x1600` (16:10 QHD+) at `60 Hz` | Only the RTX 3060 is active in `Win32_VideoController` (dGPU MUX mode). |
| **Physical RAM** | `16,236 MB` (`2 x 8 GB` DDR4-3200 Kingston `LV32D4S2S8HD-8`, Dual-Channel) | Populated in `P0 CHANNEL A` and `P0 CHANNEL B` at `3200 MT/s`. |
| **RAM Utilization** | `8,573 MB` used (`52.8%`), `7,663 MB` free | Standby cache holds `3,965 MB` (`2,813 MB` Normal, `1,099 MB` Reserve, `53 MB` Core). Modified list holds `282 MB`. |
| **Commit & Pagefile** | `9,787 MB` committed / `22,892 MB` limit; `C:\pagefile.sys` allocated `6,656 MB` | Current pagefile usage is `26 MB` (`1,579 MB` peak). Memory Compression is enabled (`36.4 MB` WS). |
| **Primary Disk (Disk 0)** | `WDC PC SN730 SDBPNTY-512G-1101` (`476.94 GB` NVMe SSD, Healthy) | Partition `C:` (NTFS) has `134.08 GB` free out of `475.85 GB` (`28.2%` free). NVMe TRIM is enabled. |
| **External Disk (Disk 1)** | `ST950032 5AS` (`465.76 GB` USB HDD, Healthy) | Currently accessed by an active recovery script (`scan_disk1.ps1`). Do not touch Disk 1. |

### 1.2 Power Plan, Gaming, and Kernel Settings (Measured)
The system uses the default `Balanced` power plan (`381b4222-f694-41f0-9685-ff5bb260df2e`), which is the only power scheme registered in `powercfg /list`.

* **Hibernation (`C:\hiberfil.sys`).** Hibernation is disabled and `C:\hiberfil.sys` takes `0 MB`.
* **GameDVR and Captures.** `GameDVR_Enabled = 0` and `AppCaptureEnabled = 0` are already disabled. `GameDVR_FSEBehaviorMode` is set to `2`.
* **Hardware-Accelerated GPU Scheduling (HAGS).** `HwSchMode` under `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` is `null` (unset).
* **Virtualization-Based Security (VBS) and Memory Integrity (HVCI).** `VBS_Status = 2`, `SecurityServicesRunning = 2`, and `HVCI_RegistryEnabled = 1` are active. Per the zero-tradeoff security requirement, VBS and HVCI must remain enabled.
* **Multimedia Class Scheduler Service (MMCSS).** `SystemResponsiveness` is `20` (Windows default 20% background reservation), `NetworkThrottlingIndex` is `15`, and `Tasks\Games` has `GPU Priority = 8`, `Priority = 2` (Medium), and `Scheduling Category = "Medium"`.
* **Visual Effects.** `EnableTransparency = 1` is active in `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`.

### 1.3 Live Process Families by Memory and CPU (Measured)
Grouping all running processes by family in [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L630-L911) reveals which actors hold the memory footprint:

| Process Family | Count | Working Set (MB) | Private Mem (MB) | CPU (s) | Role & Optimization Classification |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Antigravity` + `language_server` | 8 | `1,445.6` | `1,303.8` | `528.6` | Core user IDE and agent runtime. **Protected (Never kill or throttle).** |
| `svchost` | 92 | `1,438.3` | `541.8` | `3.1` | Windows service hosts (`DiagTrack`, `SysMain`, `WSearch`, `DoSvc`, `PcaSvc`). |
| `browser` (Cốc Cốc) | 13 | `1,201.1` | `852.0` | `28.3` | Core daily browser for YouTube. **Protected (Trim working set / Memory Saver only).** |
| `chrome` (Google Chrome) | 8 | `561.1` | `315.1` | `8.8` | Secondary browser (`C:\Program Files\Google\Chrome\Application\chrome.exe`). |
| `MsMpEng` + `MpDefenderCoreService` + `NisSrv` | 3 | `424.3` | `466.6` | `0.0` | Windows Defender Antivirus. **Protected.** |
| `msedgewebview2` | 6 | `363.5` | `176.0` | `4.1` | Edge WebView2 children hosted by `SearchHost` and Windows Widgets. |
| `node` | 5 | `361.2` | `392.5` | `6.9` | **All 5 instances are Antigravity MCP proxies** (`jina`, `exa`, `alphaxiv`). **Protected.** |
| `explorer` | 1 | `361.0` | `269.5` | `37.2` | Windows Shell. |
| `powershell` | 4 | `340.4` | `342.2` | `11.6` | Includes PID `20332` (`pubg_wireless_and_hz_guard.ps1` infinite 5s loop) and PID `22916` (`scan_disk1.ps1`). |
| `StartMenuExperienceHost` + `SearchHost` + `ShellExperienceHost` | 3 | `414.0` | `241.0` | `8.3` | Windows 11 Start, Search, and Shell UWP hosts. |
| `WidgetService` + `WidgetBoard` + `MicrosoftStartFeedProvider` + `CrossDeviceResume` | 4 | `158.2` | `63.4` | `2.9` | Windows 11 Widgets board, MSN news feed provider, and CrossDevice resume bloat. |
| `MessagingPlugin` + `LenovoVantageService` + `LenovoVantage-(GenericMessagingAddin)` | 3 | `113.2` | `145.9` | `7.4` | Lenovo Universal Device Client (`UDCService`) and Vantage marketing/messaging add-ins. |
| `python` + `pythonw` + `notebooklm-mcp` | 3 | `128.9` | `97.8` | `5.2` | `notebooklm-mcp.exe` (`102.6 MB`) + `luc-hao-daily\app\server.py` (`21.9 MB`). **Protected.** |
| `TabTip` + `TextInputHost` | 3 | `189.1` | `104.2` | `5.8` | Touch Keyboard (`TabTip.exe`, 2 instances, `99.9 MB`) and Emoji/Input host (`89.2 MB`). |

### 1.4 Startup Items, Scheduled Tasks, and Background Services (Measured)
1. **Startup Items ([system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L1019-L1150)).**
   * Already disabled in Task Manager (`StartupApproved`): `OneDrive`, `Steam`, `CocCocBrowserAutoLaunch`, `CocCocBrowserStartup`, `Zalo`, `Mozilla-Firefox`, `DAREUDriver`, `MicrosoftEdgeAutoLaunch`, `Gemini`, `GoogleUpdaterTaskUser157.0.8089.0`, `Start-9Router.vbs`, `Tailscale.lnk`, and `SecurityHealth`.
   * Currently enabled at login: `EVKey.lnk` (`EVKey64.exe` Vietnamese input method, `19.9 MB` WS), `LucHaoCoBocDaily.cmd` (launches `luc-hao-daily\app\server.py` on port `8765`), and `RtkAudUService` (Realtek audio background service).
2. **Active Background Scheduled Tasks ([system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L1151-L1507)).**
   * **Mismatched / Redundant Custom Tasks.**
     * `\PUBGWirelessAndHzGuard` (`State: Running`, PID `20332`): Executes [pubg_wireless_and_hz_guard.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_wireless_and_hz_guard.ps1) in an infinite `while ($true)` loop with a 5-second sleep. Even when PUBG is closed, it consumes `83.1 MB` Private Memory (`28.3 MB` WS) and polls process tables and WLAN interfaces every 5 to 15 seconds.
     * `\PUBGIrisXe-Boost` (`State: Ready`): Executes [TOI_UU_PUBG_IRIS_XE.cmd](file:///C:/tools/goodbyedpi-0.2.3rc3-2/TOI_UU_PUBG_IRIS_XE.cmd) and [pubg_iris_xe_boost.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/pubg_iris_xe_boost.ps1). Inspection of the script proves it was designed for a **Dell Latitude 3450 (Intel Core i7-1355U Hybrid 2P+8E + Intel Iris Xe iGPU)**, not this **Lenovo Legion 5 Pro (AMD Ryzen 7 5800H + RTX 3060)**. When run on a non-hybrid 8-core CPU, its `DetectTopology()` fallback sets `BackgroundPinMask` to cores 4–7 ([iris_xe_lib_native_diag.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_native_diag.ps1#L237)), and its power plan caps `PROCFREQMAX` to `3700 MHz` ([iris_xe_lib_power_os.ps1](file:///C:/tools/goodbyedpi-0.2.3rc3-2/iris_xe_lib_power_os.ps1#L82-L91)), which throttles the Ryzen 7 5800H below its `4.4 GHz` boost clock.
   * **Third-Party & Edge/OneDrive Updater Tasks (`State: Ready`, all triggered on `2026-11-09`).**
     * `\OneDrive Per-Machine Standalone Update Task`, `\OneDrive Reporting Task-S-1-5-21-...`, `\OneDrive Startup Task-S-1-5-21-...` (even though OneDrive is disabled in Startup).
     * `\PlatformExperiencesHelper_Daily`, `\PlatformExperiencesHelper_Metrics`, `\PlatformExperiencesHelper_OnUnlock` (Edge metrics uploader).
     * `\GoogleUser\GoogleUpdater\GoogleUpdaterTaskUser157.0.8089.0...` (runs every hour).
     * `\Mozilla\Firefox Background Update...` and `\Mozilla\Firefox Default Browser Agent...` (runs daily even though Firefox is not the primary browser).
     * `\SoftLanding\S-1-5-21-...\SoftLandingCreativeManagementTask`, `SoftLandingDeferralTask`, `SoftLandingRefreshForExpirationTask` (Microsoft promotional tips/creative delivery tasks running every 15 minutes).
   * **Microsoft Telemetry Tasks (`State: Ready`).**
     * `\Microsoft\Windows\Application Experience\MareBackup`, `Microsoft Compatibility Appraiser Exp`, `StartupAppTask`
     * `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator`, `UsbCeip`
     * `\Microsoft\Windows\Feedback\Siuf\DmClient`, `DmClientOnScenarioDownload`
     * `\Microsoft\Windows\Windows Error Reporting\QueueReporting`
     * `\Microsoft\Windows\Maps\MapsToastTask`
     * `\Microsoft\Windows\Autochk\Proxy`
3. **Background Services ([system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L1508-L1989)).**
   * `DiagTrack` (Connected User Experiences and Telemetry): `Running`, `StartMode: Auto` (PID `18016`).
   * `UDCService` (Lenovo Universal Device Client Service): `Running`, `StartMode: Auto` (PID `4660`), spawns `MessagingPlugin.exe` (`61.2 MB` Private Memory).
   * `LenovoVantageService`: `Running`, `StartMode: Auto` (PID `4692`), spawns `LenovoVantage-(GenericMessagingAddin).exe` (`41.1 MB` Private Memory).
   * `LenovoFnAndFunctionKeys` (`LenovoUtilityService.exe` + `FnHotkeyUtility.exe`): `Running`, `StartMode: Auto` (PID `4676`). **Must stay enabled** to preserve Legion `Fn+Q` thermal mode and brightness/audio OSD hotkeys.
   * `MapsBroker` (Downloaded Maps Manager): `Stopped`, `StartMode: Auto` (should be `Manual` or `Disabled`).
   * `SysMain` (PID `15644`) and `WSearch` (PID `300`): `Running`, `StartMode: Auto`.
   * `GoodbyeDPI` (PID `14612`): `Running`, `StartMode: Manual`. **Must stay enabled** for network access.

### 1.5 Disk Cache and Temporary Folder Footprints (Measured)
Scanning 31 standard cache locations in [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L2256-L2533) measured **`10,434.03 MB` (`10.19 GB`)** across `89,658 files`:

| Cache Category | Path | Size (MB) | Files | Cleanup Safety & Condition |
| :--- | :--- | :--- | :--- | :--- |
| **NPM Local Cache** | `C:\Users\Admin\AppData\Local\npm-cache` | `5,853.27` | `67,214` | **Safe (`_cacache`)**. Do not delete `_npx` while Antigravity `mcp-remote` node processes are running, or run `npm cache clean --force` only on `_cacache/content-v2`. |
| **Cốc Cốc Browser Caches** | `...\CocCoc\Browser\User Data\Default\{Cache, Code Cache, GPUCache, Service Worker\CacheStorage}` | `1,675.35` | `9,604` | **Safe when Cốc Cốc is closed** (`Cache` `363.4 MB`, `Code Cache` `747.1 MB`, `GPUCache` `10.2 MB`). Keep `Service Worker\CacheStorage` (`554.6 MB`) or clean only HTTP/Code cache so offline PWA data and logins remain intact. |
| **User `.cache` Root** | `C:\Users\Admin\.cache` (includes `puppeteer` `683.86 MB` & `huggingface` `87.50 MB`) | `1,422.44` | `4,521` | **Do NOT blind-delete.** Deleting `puppeteer` or `huggingface` forces re-downloading browser binaries and ML weights. |
| **Steam Caches & Logs** | `...\Local\Steam\htmlcache` (`493.14 MB`), `...\Steam\logs` (`40.79 MB`), `depotcache` (`38.90 MB`), `dumps` (`4.77 MB`), `httpcache` (`0.87 MB`) | `578.47` | `4,247` | **`htmlcache`, `logs`, `dumps`, `httpcache` (`539.57 MB`) are 100% safe** to clean when Steam is closed or idle. Leave `depotcache` (`38.90 MB`) alone so pending game updates do not reset. |
| **Antigravity IDE Caches** | `...\Roaming\Antigravity\{Cache, Crashpad, CachedData, Code Cache, GPUCache, logs}` | `440.97` | `2,329` | **`Crashpad` (`65.32 MB`) is safe anytime.** Leave `Cache`/`Code Cache`/`CachedData` untouched while Antigravity is running. |
| **Microsoft Edge Caches** | `...\Local\Microsoft\Edge\User Data\Default\{Cache, Code Cache}` | `228.07` | `2,697` | **100% safe** (`181.53 MB` Cache + `46.54 MB` Code Cache). |
| **User Temp (`$env:TEMP`)** | `C:\Users\Admin\AppData\Local\Temp` | `162.33` | `735` | **Safe** for unlocked files older than 1 hour (`-ErrorAction SilentlyContinue`). |
| **Explorer Thumbnail Cache** | `C:\Users\Admin\AppData\Local\Microsoft\Windows\Explorer` | `57.81` | `33` | **Skip** in routine cleanup to avoid regenerating folder thumbnails in Explorer. |
| **Minidumps & Crash Reports** | `C:\Windows\Minidump` (`7.72 MB`), `WER\ReportArchive` (`0.21 MB`) | `7.93` | `8` | **Safe** once no BSOD debugging is needed. |
| **Chrome & Windows Update** | `Chrome\...\Default\Cache` (`5.92 MB`), `D3DSCache` (`1.43 MB`), `SoftwareDistribution\Download` (`0.77 MB`) | `8.12` | `53` | **Safe** (`SoftwareDistribution\Download` and `Chrome` cache). |

---

## Section 2. Catalog of Open-Source Repositories & Technical Optimization Mechanisms

### 2.1 Surveyed Open-Source Repositories
1. **[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) (`65.7k stars`, PowerShell).**
   * **Examined Files:** `config/preset.json#L1-L61` and `config/tweaks.json#L1-L1330`.
   * **Core Mechanisms:**
     * `WPFTweaksTelemetry`: Stops and disables `DiagTrack` and `WerSvc`; sets `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry = 0`; disables scheduled tasks `Microsoft Compatibility Appraiser`, `ProgramDataUpdater`, `Proxy`, `Consolidator`, `UsbCeip`, `Microsoft-Windows-DiskDiagnosticDataCollector`, `DmClient`, `DmClientOnScenarioDownload`, and `QueueReporting`; sets `POWERSHELL_TELEMETRY_OPTOUT = 1`.
     * `WPFTweaksConsumerFeatures`: Sets `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures = 1` to block silent promotional Store app installs.
     * `WPFTweaksActivity`: Sets `EnableActivityFeed = 1`, `PublishUserActivities = 0`, and `UploadUserActivities = 0` under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System` (stops cloud activity uploads while preserving `Win+V` clipboard history).
     * `WPFTweaksDeliveryOptimization`: Sets `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization\DODownloadMode = 0` (HTTP-only official Windows Updates, zero P2P background upload bandwidth).
     * `WPFTweaksServices`: Sets `DiagTrack` to `Disabled`, and `MapsBroker` and `StorSvc` to `Manual`.
     * `WPFTweaksEndTaskOnTaskbar`: Sets `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings\TaskbarEndTask = 1` for instant right-click "End task" on the Windows 11 taskbar.
     * `WPFTweaksDeleteTempFiles`: Purges unlocked files in `$env:TEMP` and `C:\Windows\Temp`.
2. **[Raphire/Win11Debloat](https://github.com/Raphire/Win11Debloat) (`62.2k stars`, PowerShell).**
   * **Examined Files:** `Scripts/Features/Invoke-Changes.ps1#L1-L200`, `Config/Features.json#L1-L250`, and `Tests/Telemetry-ScheduledTasks.Tests.ps1#L1-L120`.
   * **Core Mechanisms:**
     * `DisableWidgets`: Stops `*Widget*` processes and disables taskbar Widgets via policy (`HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0`) or removes `Microsoft.StartExperiencesApp` and `MicrosoftWindows.Client.WebExperience`.
     * `DisableBing` / `DisableStoreSearchSuggestions`: Disables Bing web results in Windows Search (`HKCU:\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions = 1`) so `SearchHost.exe` does not spawn background `msedgewebview2.exe` instances for web queries.
     * `DisableTelemetry`: Disables the 8 Compatibility Appraiser, CEIP, DiskDiagnostic, and Autochk Proxy tasks.
     * Curated UWP Bloat Removal (`RemoveApps`): Removes non-essential preinstalled Store bloat (`Microsoft.BingNews`, `Microsoft.BingWeather`, `Clipchamp.Clipchamp`, `Microsoft.MicrosoftSolitaireCollection`, `Microsoft.WindowsFeedbackHub`, `Microsoft.GetHelp`, `Microsoft.Todos`, `Microsoft.PowerAutomateDesktop`, `Microsoft.MicrosoftOfficeHub`, `MicrosoftCorporationII.MicrosoftFamily`, `MicrosoftCorporationII.QuickAssist`) while preserving `Microsoft.WindowsStore`, `Microsoft.XboxGamingOverlay`, `Microsoft.GamingApp`, `NVIDIACorp.NVIDIAControlPanel`, and `RealtekSemiconductorCorp.RealtekAudioControl`.
3. **[hellzerg/optimizer](https://github.com/hellzerg/optimizer) (`18.2k stars`, C#).**
   * **Examined Files:** `Optimizer/CleanHelper.cs#L1-L250` and `Optimizer/OptimizeHelper.cs#L180-L250`.
   * **Core Mechanisms:**
     * Browser cache directory targeting (`Default\Cache`, `Default\Code Cache`, `Default\GPUCache`, `ShaderCache`, `GrShaderCache\GPUCache`) strictly separated from `Cookies`, `Login Data`, `Sessions`, and `History`.
     * Telemetry & Error Reporting keys: `HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat\DisablePCA = 1`, `DisableUAR = 1`, `HKLM:\SYSTEM\CurrentControlSet\Control\WMI\AutoLogger\SQMLogger\Start = 0`.
     * Network throttling & gaming profile (`DisableNetworkThrottling`): `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\NetworkThrottlingIndex = 0xFFFFFFFF` and `SystemResponsiveness = 10`.
4. **[henrypp/memreduct](https://github.com/henrypp/memreduct) (`11.2k stars`, C) & [nusu-github/WinMemClean](https://github.com/nusu-github/WinMemClean).**
   * **Examined Files:** `src/main.c#L270-L477`.
   * **Core Mechanisms (Windows Native Memory Management APIs via `ntdll.dll` and `psapi.dll`):**
     * **Per-Process Working Set Trim (`EmptyWorkingSet(hProcess)`):** Safe, user-mode accessible API that moves idle pages from target process working sets to the Standby/Modified lists without requiring kernel locks.
     * **System-Wide Working Set Trim (`NtSetSystemInformation(SystemMemoryListInformation=80, MemoryEmptyWorkingSets=2)`):** Requires `SeProfileSingleProcessPrivilege` (Admin). Empties working sets across all processes, including foreground apps and games.
     * **Modified Page List Flush (`MemoryFlushModifiedList=3`):** Writes dirty pages in RAM to `pagefile.sys` so they transition to the Standby list.
     * **Low-Priority Standby List Purge (`MemoryPurgeLowPriorityStandbyList=5`):** Purges only priority-0 standby pages, preserving high-priority cached file/DLL pages (`StandbyNormal` and `StandbyCore`).
     * **Full Standby List Purge (`MemoryPurgeStandbyList=4`):** Purges all standby pages (`3,965 MB` on this PC) to `Free`. As documented in `WinMemClean`, purging the full standby list and modified page list while a heavy workload is running can cause a brief I/O hitch when evicted pages are re-faulted from disk, whereas `MemoryPurgeLowPriorityStandbyList (5)` + targeted `EmptyWorkingSet` on non-foreground bloat avoids re-fault stutters.
     * **Memory Combine (`SystemCombinePhysicalMemoryInformation=130`):** Combines identical physical pages across processes (`MEMORY_COMBINE_INFORMATION_EX`).
5. **[nikita-yr/Steam-EcoSystem-Optimizer](https://github.com/nikita-yr/Steam-EcoSystem-Optimizer) (PowerShell + Win32 P/Invoke).**
   * **Examined Files:** `src/Common.ps1#L150-L230` and `src/SteamWatchdog.ps1#L155-L260`.
   * **Core Mechanisms:**
     * Empirical finding in repo: **Killing `steamwebhelper.exe` renderers is counterproductive** because Steam respawns them within seconds and increases total RAM by `+160 MB`.
     * Instead, applying **Background Mode** to `steamwebhelper.exe` via documented Win32 APIs cuts Steam's RAM footprint from `~1.6 GB` to `0.2–0.6 GB` (`60–88%` reduction) with zero loss of Steam Overlay or Friends chat:
       1. `SetProcessInformation(hProcess, ProcessPowerThrottling=4)` with `ControlMask=1, StateMask=1` (enables Windows 11 **Efficiency Mode / EcoQoS**).
       2. `SetProcessInformation(hProcess, ProcessMemoryPriority=0)` with `Priority=1` (`MEMORY_PRIORITY_VERY_LOW`, so the kernel evicts Steam's pages first before touching game/IDE pages).
       3. `PriorityClass = BelowNormal`.
       4. `EmptyWorkingSet(hProcess)` to immediately reclaim idle Chromium renderer pages.
6. **Chromium / Cốc Cốc Enterprise Policy & Flags ([BrowserDesk Policy Explorer](https://browserdesk.io/policy-explorer/HighEfficiencyModeEnabled) & Chromium Commit `883e3e9`).**
   * **Core Mechanisms:**
     * Setting `HighEfficiencyModeEnabled = 1` (or `HighEfficiencyModeState`) in Registry policies (`HKLM:\SOFTWARE\Policies\CocCoc\Browser` / `HKCU:\Software\Policies\CocCoc\Browser` and `Google\Chrome`) enables **Memory Saver** (automatically discards inactive background tabs while keeping active YouTube/audio tabs untouched).
     * Disabling `BackgroundModeEnabled = 0` prevents Chromium browsers (Cốc Cốc and Chrome) from keeping background processes alive after all browser windows are closed.

---

## Section 3. Symmetric Hypothesis Evaluation (`H0` vs `H1`) & Candidate Mapping to This PC

Every candidate optimization is evaluated against the primary baseline in [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json) under symmetric hypotheses:
* **`H0` (Adopt):** Provides measurable resource relief (RAM, CPU wakeups, disk space, or scheduling latency) with zero functional trade-off for Steam, Cốc Cốc (YouTube), Antigravity IDE/MCPs, Windows Defender, Windows Update, or laptop hardware controls.
* **`H1` (Reject / Skip):** Already configured on this PC, inapplicable to this hardware/OS, snake oil / harmful to caching, or risks breaking a protected workflow.

### 3.1 Rejected / Skipped Candidates (`H1` Holds on This PC)

| Candidate Tweak / Tip | Verdict | Primary Evidence from `system_baseline.json` & Repo Audit |
| :--- | :--- | :--- |
| **1. Disable Hibernation (`powercfg /h off`)** | **REJECT (`H1`: Already Configured)** | `HiberfilSizeMB = 0` in [system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L171). `C:\hiberfil.sys` is already absent. |
| **2. Disable GameDVR / Background Recording** | **REJECT (`H1`: Already Configured)** | `GameDVR_Enabled = 0` and `AppCaptureEnabled = 0` are already set ([system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L156-L158)). |
| **3. Disable VBS / Memory Integrity (HVCI) or Spectre/Meltdown Mitigations** | **REJECT (`H1`: Security Trade-off)** | `VBS_Status = 2` and `HVCI_RegistryEnabled = 1` are active. Disabling kernel isolation or CPU security mitigations violates the zero-security-tradeoff constraint. |
| **4. Disable `svchost.exe` Splitting (`SvcHostSplitThresholdInKB`)** | **REJECT (`H1`: Inapplicable / Risky)** | `winutil` (`config/tweaks.json#L180-L199`) documents this is only for systems with `<= 12 GB` RAM and warns it can interfere with Xbox/Gaming services. This PC has `16 GB` RAM (`7.66 GB` free). |
| **5. Permanently Disable `SysMain` (Superfetch) or `WSearch` (Windows Search)** | **REJECT for Baseline (`H1`: Functional Trade-off)** | On an NVMe SSD (`WDC PC SN730`), `SysMain` pre-populates the `3.96 GB` Standby Cache for zero-latency app launches, and `WSearch` powers Start Menu file search (`46 MB` WS). Permanently disabling them degrades daily UX. |
| **6. Keep or Run `\PUBGIrisXe-Boost` (`pubg_iris_xe_boost.ps1`)** | **REJECT (`H1`: Wrong Hardware Target)** | Designed for a Dell Latitude 3450 (`i7-1355U` 2P+8E + Intel Iris Xe). On this AMD Ryzen 7 5800H + RTX 3060 laptop, its power plan caps CPU clock to `3700 MHz` (below the 5800H's `4400 MHz` boost) and its fallback topology pins processes to cores 4–7 as fake E-cores. |
| **7. Kill `steamwebhelper.exe`, `node.exe`, or `python.exe` in Rescue Script** | **REJECT (`H1`: Breaks Protected Apps)** | Killing `steamwebhelper.exe` causes Steam to respawn them at `+160 MB` higher RAM. Killing `node.exe` or `python.exe` kills Antigravity's active MCP servers (`exa`, `jina`, `alphaxiv`, `notebooklm-mcp`) and `luc-hao-daily\app\server.py`. |
| **8. Stop `LenovoFnAndFunctionKeys` (`FnHotkeyUtility.exe`) or `GoodbyeDPI`** | **REJECT (`H1`: Breaks Hardware/Network)** | `LenovoFnAndFunctionKeys` drives the Legion `Fn+Q` thermal mode indicator and OSD hotkeys. `GoodbyeDPI` (PID `14612`) is the user's active DPI bypass service. |
| **9. Blindly Delete `C:\Users\Admin\.cache` (`HuggingFace` & `Puppeteer`)** | **REJECT (`H1`: Destroys Local Models/Browsers)** | `C:\Users\Admin\.cache` holds `puppeteer` (`683.86 MB`) and `huggingface` (`87.50 MB`). Deleting them breaks offline browser automation and forces gigabyte re-downloads. |

---

### 3.2 Part A: Baseline Zero-Tradeoff Debloat Candidates (`H0` Holds — One-Time Safe & Reversible)

Each candidate below is backed by a concrete baseline anomaly on this PC, has zero functional trade-off, and can be snapshotted to a JSON/reg backup file for 1-command rollback:

#### Candidate A1. Stop and Disable Mismatched / Polling Scheduled Tasks & Stale Updater Tasks
* **Target Tasks on This PC:**
  1. `\PUBGWirelessAndHzGuard` (Currently `Running` as PID `20332`, `83.1 MB` Private Memory, polling every 5 seconds even when PUBG is closed) and `\PUBGIrisXe-Boost` (`Ready`, Dell i7-1355U Iris Xe script on an AMD Ryzen 7 5800H + RTX 3060 laptop). *Note for Subagent 2:* Check whether the user wants `\PUBGWirelessAndHzGuard` disabled in Baseline (and moved into an on-demand gaming/rescue toggle) or converted to event-driven/manual.
  2. **OneDrive Background Tasks** (since OneDrive is already disabled in `StartupApproved`):
     * `\OneDrive Per-Machine Standalone Update Task`
     * `\OneDrive Reporting Task-S-1-5-21-4103410102-500614160-3074263882-1001`
     * `\OneDrive Startup Task-S-1-5-21-4103410102-500614160-3074263882-1001`
  3. **Edge & Promotional SoftLanding Tasks:**
     * `\PlatformExperiencesHelper_Daily`, `\PlatformExperiencesHelper_Metrics`, `\PlatformExperiencesHelper_OnUnlock`
     * `\SoftLanding\S-1-5-21-4103410102-500614160-3074263882-1001\SoftLandingCreativeManagementTask`
     * `\SoftLanding\S-1-5-21-4103410102-500614160-3074263882-1001\SoftLandingDeferralTask-{3b6ad30b-994c-4c73-af20-0e1fea31f48d}`
     * `\SoftLanding\S-1-5-21-4103410102-500614160-3074263882-1001\SoftLandingRefreshForExpirationTask-{db1a8137-8b55-4edd-81e0-2b26d9ecc719}`
  4. **Unused Browser Background Tasks** (Firefox is disabled in Startup):
     * `\Mozilla\Firefox Background Update S-1-5-21-4103410102-500614160-3074263882-1001 308046B0AF4A39CB`
     * `\Mozilla\Firefox Default Browser Agent 308046B0AF4A39CB`
  5. **Microsoft Telemetry Scheduled Tasks (`winutil` / `Win11Debloat` standard list):**
     * `\Microsoft\Windows\Application Experience\MareBackup`
     * `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp`
     * `\Microsoft\Windows\Application Experience\StartupAppTask`
     * `\Microsoft\Windows\Autochk\Proxy`
     * `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator`
     * `\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip`
     * `\Microsoft\Windows\Feedback\Siuf\DmClient`
     * `\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload`
     * `\Microsoft\Windows\Maps\MapsToastTask`
     * `\Microsoft\Windows\Windows Error Reporting\QueueReporting`
* **Mechanism:** `Stop-ScheduledTask` + `Disable-ScheduledTask` (recording original `State` in backup JSON for exact restore).
* **Estimated Impact:** Frees `~83 MB` Private RAM immediately (from PID `20332`) and eliminates `22` periodic background process spawns (`compattelrunner.exe`, `wsqmcons.exe`, `platform_experiences_helper.exe`, `OneDriveStandaloneUpdater.exe`).

#### Candidate A2. Disable Telemetry & Lenovo UDC Marketing Services (Preserving Legion Hotkeys)
* **Target Services on This PC:**
  1. `DiagTrack` (Connected User Experiences and Telemetry — currently `Running`, `Auto`, PID `18016`): Stop and set `StartupType = Disabled` (or `Manual`).
  2. `UDCService` (Lenovo Universal Device Client Service — currently `Running`, `Auto`, PID `4660`, spawning `MessagingPlugin.exe` taking `57.2 MB` WS / `61.2 MB` Private): Stop `UDCService`, terminate `MessagingPlugin.exe`, and set `UDCService` `StartupType = Disabled` (matches the user's already-disabled `\Lenovo\UDC\Lenovo UDC Diagnostic Scan` task).
  3. `MapsBroker` (Downloaded Maps Manager — currently `Stopped`, `StartMode = Auto`): Set `StartupType = Manual` (per `winutil` `WPFTweaksServices`).
  4. `CocCocUpdaterService154.0.8037.108`, `CocCocUpdaterInternalService154.0.8037.108`, `GoogleUpdaterService157.0.8089.0`, `GoogleUpdaterInternalService157.0.8089.0`, `edgeupdate`: Set `StartupType = Manual` instead of `Auto` so they only run when the browser checks for updates via its UI, not at boot.
* **Protected Services (Do NOT Touch):** `LenovoFnAndFunctionKeys` (Legion Fn+Q/OSD hotkeys), `WinDefend`, `WdNisSvc`, `MDCoreSvc`, `mpssvc`, `wuauserv`, `BITS`, `Audiosrv`, `AudioEndpointBuilder`, `bthserv`, `WSLService`, `GoodbyeDPI`.
* **Estimated Impact:** Frees `~80–110 MB` RAM continuously (`UDCService` + `MessagingPlugin.exe` + `DiagTrack`) and reduces boot service overhead.

#### Candidate A3. Disable Windows 11 Widgets & MSN Start Feed Background Hosts (`158.2 MB` RAM)
* **Baseline Evidence:** `WidgetService.exe` (`26.1 MB`), `WidgetBoard.exe` (`30.4 MB`), `MicrosoftStartFeedProvider.exe` (`47.6 MB`), and `CrossDeviceResume.exe` (`54.1 MB`), plus their hosted `msedgewebview2.exe` processes (`~150+ MB`), are running in the background right now.
* **Mechanism (Reversible Policy Key — No Appx Uninstall Required):**
  * Set `HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0` (DWord) and `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDa = 0` (DWord), then stop `WidgetService`, `WidgetBoard`, and `MicrosoftStartFeedProvider`.
  * Set `HKCU:\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions = 1` (DWord) and `HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsDynamicSearchBoxEnabled = 0` (DWord) to stop Start Menu web search from spawning background Bing `msedgewebview2` instances while keeping local file/app search 100% functional.
* **Estimated Impact:** Frees **`~150–280 MB` RAM** (`WidgetService` + `WidgetBoard` + `MicrosoftStartFeedProvider` + associated `msedgewebview2` processes) with zero impact on local Windows Search or Microsoft Store.

#### Candidate A4. Zero-Tradeoff Registry Tweaks (`winutil` Standard + Gaming MMCSS & Taskbar End Task)
* **Mechanisms:**
  1. **Consumer Features & Telemetry Policies:**
     * `HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures = 1`
     * `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry = 0`
     * `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo\Enabled = 0`
     * `HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\PublishUserActivities = 0` & `UploadUserActivities = 0`
  2. **Delivery Optimization (HTTP-Only, Zero P2P Upload):**
     * `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization\DODownloadMode = 0` (Windows Update still downloads normally via HTTP from Microsoft CDN, but never uses local disk/bandwidth as a P2P peer).
  3. **Taskbar Developer End-Task Option:**
     * `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings\TaskbarEndTask = 1`
  4. **MMCSS Gaming Profile & Game Mode (`HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`):**
     * Set `SystemResponsiveness = 10` (currently `20`) and `NetworkThrottlingIndex = 0xFFFFFFFF` (`4294967295`, currently `15`).
     * Under `Tasks\Games`: Set `GPU Priority = 8`, `Priority = 6` (currently `2`), `Scheduling Category = "High"` (currently `"Medium"`), `SFIO Priority = "High"`.
     * Under `HKCU:\Software\Microsoft\GameBar`: Set `AutoGameModeEnabled = 1` and `AllowAutoGameMode = 1` (currently `null`).
     * Under `HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`: Set `HwSchMode = 2` (Hardware-Accelerated GPU Scheduling enabled for RTX 3060; takes effect on next reboot).
* **Estimated Impact:** Eliminates background P2P update uploads, prevents silent bloatware re-installation, and gives Steam games (`PUBG`, `Half Sword`, `Combat Master`) higher scheduler & GPU priority.

#### Candidate A5. Safe Baseline Disk Cache Cleanup (`~6.6 GB` Immediate Reclaim, Zero Active-App Disruption)
* **Targets Safe to Clean Even While Cốc Cốc & Antigravity Are Open:**
  1. **NPM Content Cache (`C:\Users\Admin\AppData\Local\npm-cache\_cacache`):** **`5,853.27 MB` (`5.72 GB`)**! Cleaning `_cacache` (while leaving `_npx` intact so running `mcp-remote` node servers are untouched) immediately reclaims **`5.7+ GB`** on `C:`.
  2. **Steam HTML Cache, Old Logs & Crash Dumps:** `C:\Users\Admin\AppData\Local\Steam\htmlcache` (`493.14 MB`), `C:\Program Files (x86)\Steam\logs` (`40.79 MB`), `C:\Program Files (x86)\Steam\dumps` (`4.77 MB`), and `httpcache` (`0.87 MB`) = **`539.57 MB`** (since Steam is not currently running!).
  3. **Microsoft Edge Caches:** `C:\Users\Admin\AppData\Local\Microsoft\Edge\User Data\Default\Cache` (`181.53 MB`) and `Code Cache` (`46.54 MB`) = **`228.07 MB`**.
  4. **Antigravity Crashpad Dumps:** `C:\Users\Admin\AppData\Roaming\Antigravity\Crashpad\reports` (`65.32 MB`).
  5. **User Temp (`$env:TEMP`):** Unlocked files older than 2 hours (`~162.33 MB`).
  6. **Windows Minidumps & WER Archive:** `C:\Windows\Minidump` (`7.72 MB`) + `WER\ReportArchive` (`0.21 MB`) = **`7.93 MB`**.
  * *Optional Offline Addition (only when Cốc Cốc is closed):* `CocCoc\Browser\User Data\Default\Cache` (`363.39 MB`) + `Code Cache` (`747.09 MB`) + `GPUCache` (`10.23 MB`) = **`1,120.71 MB` (`1.12 GB`)** without touching logins, cookies, history, or Service Worker storage.
* **Total Baseline Disk Reclaim:** **`~6.85 GB`** immediately while apps are open, or **`~7.97 GB`** if Cốc Cốc cache is also cleaned while Cốc Cốc is closed.

#### Candidate A6. Optional Curated UWP Bloatware Removal (`Win11Debloat` Safe Subset)
* **Installed Non-Essential UWP Packages on This PC ([system_baseline.json](file:///C:/Users/Admin/.gemini/antigravity/brain/76e381ca-2151-460a-a259-6f6f64d3bf30/scratch/system_baseline.json#L1990-L2255)):**
  * `Clipchamp.Clipchamp`, `Microsoft.BingNews`, `Microsoft.BingWeather`, `Microsoft.BingSearch`, `Microsoft.MicrosoftSolitaireCollection`, `Microsoft.MicrosoftOfficeHub`, `Microsoft.WindowsFeedbackHub`, `Microsoft.GetHelp`, `Microsoft.PowerAutomateDesktop`, `MicrosoftCorporationII.MicrosoftFamily`, `MicrosoftCorporationII.QuickAssist`, `Microsoft.Windows.DevHome`.
* **Protected UWP Packages (Never Remove):** `NVIDIACorp.NVIDIAControlPanel`, `RealtekSemiconductorCorp.RealtekAudioControl`, `Microsoft.WindowsStore`, `Microsoft.DesktopAppInstaller` (`winget`), `Microsoft.WindowsTerminal`, `Microsoft.XboxGamingOverlay`, `Microsoft.GamingApp`, `Microsoft.Xbox.TCUI`, `Microsoft.XboxIdentityProvider`, `CanonicalGroupLimited.Ubuntu24.04LTS`, `MicrosoftCorporationII.WindowsSubsystemForLinux`, all media codec extensions (`HEVC`, `AV1`, `VP9`, `MPEG2`, `Webp`, `HEIF`, `RawImage`), `E046963F.LenovoCompanion` (Lenovo Vantage UI).

---

### 3.3 Part B: On-Demand Emergency Rescue Script Candidates ("Kịch bản cứu hộ" — Fast Runtime Relief)

When the user experiences sudden RAM, CPU, or Disk I/O congestion during heavy multitasking (e.g., Steam game + Cốc Cốc YouTube + Antigravity IDE), the Emergency Rescue Script (`Rescue-SystemResources.ps1`) should execute in `< 3 seconds` with **zero disruption to active work**:

#### Candidate B1. Safe Process Exclusion List (Hard Guardrail)
* **Never Kill, Suspend, or Starve:**
  * **Antigravity & Agent Toolchain:** `Antigravity`, `language_server`, `node` (hosts `mcp-remote` for `exa`, `jina`, `alphaxiv`), `python` / `pythonw` / `notebooklm-mcp`, `rg`, `git`, `conhost`, `WindowsTerminal`, `powershell`, `pwsh`.
  * **Browsers & Gaming:** `browser` (Cốc Cốc), `steam`, `steamservice`, `TslGame*`, `ExecPubg`, `BEService*`, `zksvc`, `EasyAntiCheat*`, and any foreground game process.
  * **OS, Audio, Security & Network:** `MsMpEng`, `MpDefenderCoreService`, `NisSrv`, `audiodg`, `RtkAudUService64`, `FnHotkeyUtility`, `LenovoUtilityService`, `NVDisplay.Container`, `dwm`, `explorer`, `csrss`, `lsass`, `svchost`, `goodbyedpi`, `EVKey64`.

#### Candidate B2. Targeted `EmptyWorkingSet` + EcoQoS + `MEMORY_PRIORITY_VERY_LOW` on Background Bloat (`SESO` Pattern)
* **Mechanism (Works With or Without Admin):**
  1. For background Chromium helpers and secondary web views (`steamwebhelper`, `msedgewebview2`, `chrome` if not the active foreground window, `SearchHost`, `StartMenuExperienceHost`, `ShellExperienceHost`, `TextInputHost`, `LenovoVantage-(GenericMessagingAddin)`):
     * Call `EmptyWorkingSet(hProcess)` via `psapi.dll` to immediately move idle pages out of active Working Set into Standby (active pages fault back in microseconds from RAM if touched).
     * For `steamwebhelper`, `msedgewebview2`, and `SearchHost`: Apply `SetProcessInformation(ProcessPowerThrottling)` (`EcoQoS` / Efficiency Mode), `SetProcessInformation(ProcessMemoryPriority = 1)` (`MEMORY_PRIORITY_VERY_LOW`), and `PriorityClass = BelowNormal`.
  2. For `browser.exe` (Cốc Cốc) and `Antigravity.exe`:
     * Call `EmptyWorkingSet(hProcess)` **only** on background renderer/utility processes (or skip the active audio/foreground process and retain `Normal` priority and `Normal` memory priority), reclaiming 300–600 MB of bloated V8/DOM working set without tab reloads or audio stutter.
* **Why This Beats `MemoryEmptyWorkingSets (Command=2)`:** Global `NtSetSystemInformation(80, 2)` trims the foreground game, audio engine (`audiodg.exe`), and DWM (`dwm.exe`), which can cause a 1-second micro-stutter. Targeted per-process `EmptyWorkingSet` skips foreground games, `audiodg.exe`, and `dwm.exe`!

#### Candidate B3. Safe Standby List & Memory Combine Purge (`NtSetSystemInformation` Tiered Mode)
* **Mechanism (When Elevated as Admin):**
  1. Invoke `NtSetSystemInformation(SystemCombinePhysicalMemoryInformation=130)` to deduplicate identical zero/shared pages across processes.
  2. Invoke `NtSetSystemInformation(SystemMemoryListInformation=80, MemoryPurgeLowPriorityStandbyList=5)` by default (zero disk re-fault hitch), and optionally `MemoryPurgeStandbyList=4` (only when no latency-sensitive game is actively rendering or when `-Aggressive` is passed or Free RAM `< 2048 MB`).
* **Estimated Impact:** Reclaims **`1,000–3,500 MB`** of physical RAM within `300 ms`.

#### Candidate B4. Terminate Purely Ephemeral Background Bloat Processes
* **Safe-to-Kill Ephemeral Processes (Respawn only on demand, hold zero user state):**
  * `WidgetService.exe`, `WidgetBoard.exe`, `MicrosoftStartFeedProvider.exe`, `CrossDeviceResume.exe` (`~158 MB` WS)
  * `MessagingPlugin.exe`, `LenovoVantage-(GenericMessagingAddin).exe` (`~102 MB` Private)
  * `TabTip.exe` (`~100 MB` WS — touch keyboard on a non-touch Legion laptop!)
  * `GameBar.exe`, `GameBarFTServer.exe` (if idle)
  * Orphaned updater processes (`OneDriveStandaloneUpdater.exe`, `GoogleUpdate.exe`, `updater.exe` from Cốc Cốc/Google, `platform_experiences_helper.exe`, `compattelrunner.exe`, `wermgr.exe`).
* **Estimated Impact:** Immediately frees **`250–400 MB` of Private Committed Memory** (which reduces commit charge, not just working set).

#### Candidate B5. Temporary Pause (and `-Restore` Resume) of Heavy Disk/CPU Background Indexers & Updaters
* **Mechanism (When Elevated as Admin):**
  * Temporarily stop non-essential disk/CPU background services: `SysMain`, `WSearch`, `DiagTrack`, `DoSvc` (Delivery Optimization), `UDCService`, `LenovoVantageService`, `MapsBroker`, `WerSvc`, `PcaSvc`.
  * Do **NOT** stop `wuauserv` if an update is actively installing, and never touch `WinDefend`, `Audiosrv`, `bthserv`, `GoodbyeDPI`, or `LenovoFnAndFunctionKeys`.
  * Provide a `-Restore` flag (and automatic state file) to restart `SysMain` and `WSearch` after the tight situation ends.
* **Estimated Impact:** Eliminates background NVMe disk queue spikes and `svchost` CPU bursts during tight gaming or compilation sessions.

#### Candidate B6. Instant Non-Blocking Temp & DNS Flush
* **Mechanism:**
  * Delete unlocked files in `$env:TEMP` (`C:\Users\Admin\AppData\Local\Temp`) and `C:\Windows\Temp` with `-ErrorAction SilentlyContinue`.
  * Run `Clear-DnsClientCache` (`ipconfig /flushdns`).
  * Run `[System.GC]::Collect()` inside PowerShell and exit cleanly.

---

## Section 4. Audit Checklist for Subagent 2

1. **Verify Process Protections:** Confirm that `node.exe` (`mcp-remote`), `python.exe` (`notebooklm-mcp`), `pythonw.exe` (`luc-hao-daily`), `Antigravity.exe`, `language_server.exe`, `browser.exe` (Cốc Cốc), `steam.exe`, `EVKey64.exe`, `goodbyedpi.exe`, and `FnHotkeyUtility.exe` are on the hard exclusion list for process termination and CPU starvation.
2. **Verify Hardware Architecture Fit:** Confirm that no Intel Hybrid P/E core affinity masks (`0xF0` / cores 4–7) or `3700 MHz` clock caps from `pubg_iris_xe_boost.ps1` are carried over to this homogeneous 8C/16T AMD Ryzen 7 5800H + RTX 3060 system.
3. **Verify Cache Path Precision:** Confirm that `npm-cache` cleanup targets `_cacache` (preserving `_npx` for running MCP servers), `C:\Users\Admin\.cache` (`huggingface` and `puppeteer`) is excluded from deletion, and `Steam\depotcache` is excluded so game updates are not interrupted.
4. **Verify Full Reversibility:** Confirm that the Part A Baseline Debloat script writes a pre-change state snapshot (`baseline_debloat_backup.json`) recording every modified Registry key, Service `StartMode`, and Scheduled Task `State` so `-Restore` reverts 100% of changes deterministically.

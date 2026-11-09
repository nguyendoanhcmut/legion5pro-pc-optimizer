#Requires -Version 5.1
<#
.SYNOPSIS
    Chế Độ Đi Học & Cứu Hộ RAM Tức Thì (Lenovo Legion 5 Pro 16ACH6H / 82JQ)
.DESCRIPTION
    1 Script Duy Nhất tích hợp:
      [1] -DiHoc        : Chế độ Đi Học Tiêu Chuẩn (6h12p - 7h32p khi bật Hybrid Mode)
      [2] -DiHocUltra   : Chế độ Đi Học Siêu Trâu 8h - 9.5h (4 nhân 1.7GHz, tắt đèn phím, 12% sáng, EcoQoS)
      [3] -SacDay100    : Chuẩn bị đi học - Sạc đầy 100% mát máy (Normal Mode, tắt sạc nhanh)
      [4] -VeNha        : Về nhà / Cắm sạc chơi game bền pin (Conservation Mode 55-60%, bật lại PUBG Guard)
      [5] -CuuHoRAM     : Cứu hộ xả RAM tức thì < 2 giây (EcoQoS + Trim Working Set + Kill Bloat)
      [6] -UndoBaseline : Khôi phục cài đặt gốc ban đầu (gọi baseline_setup.ps1 -Undo)
      [*] -Status       : Xem trạng thái Pin (%, mV, °C, Wh), Card rời RTX 3060, RAM và dự báo số giờ dùng pin
#>
[CmdletBinding()]
param(
    [switch]$Status,
    [switch]$DiHoc,
    [switch]$DiHocUltra,
    [switch]$SacDay100,
    [switch]$VeNha,
    [switch]$CuuHoRAM,
    [switch]$UndoBaseline
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectDir   = "C:\Users\Admin\.gemini\antigravity\scratch\pc-optimizer"
$BackupDir    = Join-Path $ProjectDir "backup"
$RuntimeState = Join-Path $BackupDir "runtime_state.json"
$BaselineFile = Join-Path $BackupDir "baseline_backup.json"

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# ============================================================================
# 1. C# P/Invoke Native Helpers (EcoQoS, MemoryPriority, EmptyWorkingSet, OverlayScheme, NtSetSystemInformation)
# ============================================================================
$nativeCode = @"
using System;
using System.Runtime.InteropServices;

public static class PcOptNative {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint processAccess, bool bInheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetProcessInformation(IntPtr hProcess, int ProcessInformationClass, IntPtr ProcessInformation, uint ProcessInformationSize);

    [DllImport("psapi.dll", SetLastError = true)]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("powrprof.dll", EntryPoint = "PowerSetActiveOverlayScheme")]
    public static extern uint PowerSetActiveOverlayScheme( ref Guid OverlaySchemeGuid );

    [DllImport("ntdll.dll")]
    public static extern int NtSetSystemInformation(int SystemInformationClass, IntPtr SystemInfo, int SystemInfoLength);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool OpenProcessToken(IntPtr ProcessHandle, uint DesiredAccess, out IntPtr TokenHandle);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern bool LookupPrivilegeValue(string lpSystemName, string lpName, out long lpLuid);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern bool AdjustTokenPrivileges(IntPtr TokenHandle, bool DisableAllPrivileges, ref TOKEN_PRIVILEGES NewState, int BufferLength, IntPtr PreviousState, IntPtr ReturnLength);

    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_POWER_THROTTLING_STATE {
        public uint Version;
        public uint ControlMask;
        public uint StateMask;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_PRIORITY_INFORMATION {
        public uint MemoryPriority;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct TOKEN_PRIVILEGES {
        public int PrivilegeCount;
        public long Luid;
        public int Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_COMBINE_INFORMATION_EX {
        public IntPtr Handle;
        public UIntPtr PagesCombined;
        public ulong Flags;
    }

    public const uint PROCESS_SET_INFORMATION = 0x0200;
    public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    public const uint PROCESS_SET_QUOTA = 0x0100;

    public static bool SetEcoQoSAndMemoryPriority(int pid, bool enableEcoQoS, uint memPriority) {
        IntPtr hProc = OpenProcess(PROCESS_SET_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (hProc == IntPtr.Zero) return false;
        try {
            // ProcessPowerThrottling = 4
            PROCESS_POWER_THROTTLING_STATE throttle = new PROCESS_POWER_THROTTLING_STATE();
            throttle.Version = 1;
            throttle.ControlMask = 1; // PROCESS_POWER_THROTTLING_EXECUTION_SPEED
            throttle.StateMask = enableEcoQoS ? 1u : 0u;
            int szT = Marshal.SizeOf(throttle);
            IntPtr pT = Marshal.AllocHGlobal(szT);
            try {
                Marshal.StructureToPtr(throttle, pT, false);
                SetProcessInformation(hProc, 4, pT, (uint)szT);
            } finally {
                Marshal.FreeHGlobal(pT);
            }

            // ProcessMemoryPriority = 0
            MEMORY_PRIORITY_INFORMATION mp = new MEMORY_PRIORITY_INFORMATION();
            mp.MemoryPriority = memPriority; // 1 = Very Low, 5 = Normal
            int szM = Marshal.SizeOf(mp);
            IntPtr pM = Marshal.AllocHGlobal(szM);
            try {
                Marshal.StructureToPtr(mp, pM, false);
                SetProcessInformation(hProc, 0, pM, (uint)szM);
            } finally {
                Marshal.FreeHGlobal(pM);
            }
            return true;
        } finally {
            CloseHandle(hProc);
        }
    }

    public static bool TrimProcessWorkingSet(int pid) {
        IntPtr hProc = OpenProcess(PROCESS_SET_QUOTA | PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
        if (hProc == IntPtr.Zero) return false;
        try {
            return EmptyWorkingSet(hProc);
        } finally {
            CloseHandle(hProc);
        }
    }

    public static int GetForegroundProcessId() {
        IntPtr hWnd = GetForegroundWindow();
        if (hWnd == IntPtr.Zero) return 0;
        uint pid = 0;
        GetWindowThreadProcessId(hWnd, out pid);
        return (int)pid;
    }

    public static bool SetOverlayScheme(string guidStr) {
        try {
            Guid g = new Guid(guidStr);
            return PowerSetActiveOverlayScheme(ref g) == 0;
        } catch {
            return false;
        }
    }

    public static bool EnableProfilePrivilege() {
        IntPtr hToken;
        if (!OpenProcessToken(System.Diagnostics.Process.GetCurrentProcess().Handle, 0x0020 | 0x0008, out hToken))
            return false;
        try {
            long luid;
            if (!LookupPrivilegeValue(null, "SeProfileSingleProcessPrivilege", out luid))
                return false;
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.PrivilegeCount = 1;
            tp.Luid = luid;
            tp.Attributes = 0x00000002; // SE_PRIVILEGE_ENABLED
            return AdjustTokenPrivileges(hToken, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        } finally {
            CloseHandle(hToken);
        }
    }

    public static void CombineAndPurgeLowPriorityStandby() {
        if (!EnableProfilePrivilege()) return;
        // SystemCombinePhysicalMemoryInformation = 130
        MEMORY_COMBINE_INFORMATION_EX combineInfo = new MEMORY_COMBINE_INFORMATION_EX();
        int szC = Marshal.SizeOf(combineInfo);
        IntPtr pC = Marshal.AllocHGlobal(szC);
        try {
            Marshal.StructureToPtr(combineInfo, pC, false);
            NtSetSystemInformation(130, pC, szC);
        } finally {
            Marshal.FreeHGlobal(pC);
        }
        // SystemMemoryListInformation = 80, MemoryPurgeLowPriorityStandbyList = 5
        IntPtr pCmd = Marshal.AllocHGlobal(4);
        try {
            Marshal.WriteInt32(pCmd, 5);
            NtSetSystemInformation(80, pCmd, 4);
        } finally {
            Marshal.FreeHGlobal(pCmd);
        }
    }
}
"@

if (-not ("PcOptNative" -as [type])) {
    Add-Type -TypeDefinition $nativeCode -Language CSharp -ErrorAction SilentlyContinue
}

# ============================================================================
# 2. Hardware Telemetry & Helper Functions
# ============================================================================
function Initialize-IdeaBatteryAgent {
    $dllDir = "C:\ProgramData\Lenovo\Vantage\Addins\IdeaNotebookAddin\1.0.13.114"
    if (-not (Test-Path "$dllDir\IdeaBatteryAgent.dll")) { return $null }
    try {
        if (-not ("IdeaNotebookAddin.BatteryAgent" -as [type])) {
            Add-Type -Path "$dllDir\BatteryManagementContract.dll" -ErrorAction SilentlyContinue
            Add-Type -Path "$dllDir\BatteryInformationContract.dll" -ErrorAction SilentlyContinue
            Add-Type -Path "$dllDir\IdeaBatteryAgent.dll" -ErrorAction Stop
        }
        return [IdeaNotebookAddin.BatteryAgent]::GetInstance()
    } catch {
        return $null
    }
}

function Get-BatteryLiveTelemetry {
    $agent = Initialize-IdeaBatteryAgent
    $wmiBat = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus -ErrorAction SilentlyContinue
    if ($agent) {
        try {
            $cm = $agent.GetBatteryChargeMode()
            $bi = $agent.GetBatteryInformation().BatteryInformationList[0]
            $cellV = [math]::Round($bi.Voltage / 4000.0, 3)
            $powerOnline = if ($wmiBat) { [bool]$wmiBat.PowerOnline } else { [bool]$agent.IsACIn() }
            $dischargeW = if ($wmiBat -and $wmiBat.DischargeRate -gt 0) { [math]::Round($wmiBat.DischargeRate / 1000.0, 2) } else { 0.0 }
            $chargeW    = if ($wmiBat -and $wmiBat.ChargeRate -gt 0) { [math]::Round($wmiBat.ChargeRate / 1000.0, 2) } else { 0.0 }
            return [PSCustomObject]@{
                Percent          = [int]$bi.RemainingPercent
                RemainingWh      = [math]::Round($bi.RemainingCapacity / 1000.0, 2)
                FullCapWh        = [math]::Round($bi.FullChargeCapacity / 1000.0, 2)
                DesignCapWh      = [math]::Round($bi.DesignCapacity / 1000.0, 2)
                HealthPct        = [math]::Round(($bi.FullChargeCapacity / [double]$bi.DesignCapacity) * 100.0, 2)
                VoltageMV        = [int]$bi.Voltage
                CellVoltageV     = $cellV
                TemperatureC     = [int]$bi.Temperature
                CycleCount       = [int]$bi.CycleCount
                ChargeMode       = $cm.BatteryChargeMode.ToString()
                IsRapidCharge    = [bool]$bi.IsExpressCharging
                PowerOnline      = $powerOnline
                DischargeRateW   = $dischargeW
                ChargeRateW      = $chargeW
            }
        } catch {}
    }
    return $null
}

function Set-BatteryChargeModeSafe {
    param([ValidateSet('Normal', 'Storage')][string]$Mode)
    $agent = Initialize-IdeaBatteryAgent
    if (-not $agent) { return $false }
    try {
        $req = New-Object Lenovo.Modern.Contracts.BatteryManagement.BatteryMgmtRequest
        $req.BatteryChargeMode = [Lenovo.Modern.Contracts.BatteryManagement.BatteryChargeModeType]::$Mode
        $null = $agent.SetBatteryChargeMode($req)
        return ($agent.GetBatteryChargeMode().BatteryChargeMode.ToString() -eq $Mode)
    } catch {
        return $false
    }
}

function Get-GpuHybridStatus {
    $amdDev = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VEN_1002' }
    $hybridOn = ($null -ne $amdDev -and $amdDev.Present -eq $true -and $amdDev.Status -eq 'OK')
    $dgpuPowerW = "N/A"
    $dgpuState  = "Unknown"
    $nvSmi = Get-Command "nvidia-smi.exe" -ErrorAction SilentlyContinue
    if ($nvSmi) {
        $nvOut = & nvidia-smi.exe --query-gpu=pstate,power.draw,temperature.gpu --format=csv,noheader,nounits 2>$null
        if ($nvOut -and $nvOut -match '([^,]+),\s*([^,]+),\s*(.+)') {
            $dgpuState  = $matches[1].Trim()
            $dgpuPowerW = "$($matches[2].Trim()) W ($($matches[3].Trim()) C)"
        }
    }
    return [PSCustomObject]@{
        HybridModeOn = $hybridOn
        AmdStatus    = if ($amdDev) { "$($amdDev.FriendlyName) [Present=$($amdDev.Present), Status=$($amdDev.Status)]" } else { "Disconnected (MUX = dGPU-Only)" }
        RtxState     = $dgpuState
        RtxPower     = $dgpuPowerW
    }
}

function Get-PowerIndex {
    param([string]$Subgroup, [string]$Setting)
    $out = powercfg /qh SCHEME_CURRENT $Subgroup $Setting 2>$null
    $ac = $null; $dc = $null
    foreach ($line in $out) {
        if ($line -match 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)') { $ac = [Convert]::ToInt32($matches[1], 16) }
        elseif ($line -match 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)') { $dc = [Convert]::ToInt32($matches[1], 16) }
    }
    return [PSCustomObject]@{ AC = $ac; DC = $dc }
}

function Get-CurrentBrightness {
    $bm = Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue
    if ($bm) { return [int]$bm.CurrentBrightness }
    return 20
}

function Set-ScreenBrightness {
    param([int]$Level)
    $bm = Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue
    if ($bm) {
        try {
            Invoke-CimMethod -InputObject $bm -MethodName WmiSetBrightness -Arguments @{ Timeout = 1; Brightness = [byte]$Level } -ErrorAction SilentlyContinue | Out-Null
            return $true
        } catch {}
    }
    return $false
}

function Save-PriorBrightnessIfNeeded {
    $cur = Get-CurrentBrightness
    $state = [PSCustomObject]@{ PriorBrightness = $cur; InCampusMode = $true; UpdatedAt = (Get-Date).ToString("o") }
    if (Test-Path $RuntimeState) {
        try {
            $existing = Get-Content $RuntimeState -Raw | ConvertFrom-Json
            if ($existing.InCampusMode -eq $true -and $null -ne $existing.PriorBrightness) {
                $state.PriorBrightness = [int]$existing.PriorBrightness
            }
        } catch {}
    }
    $state | ConvertTo-Json | Set-Content -Path $RuntimeState -Encoding UTF8
}

function Set-LenovoThermalAndLight {
    param(
        [int]$SmartFanMode = 0,     # 1 = Quiet, 2 = Balanced, 3 = Performance
        [int]$KeyboardLight = -1    # 0 = Off
    )
    $gz = Get-CimInstance -Namespace root\WMI -ClassName LENOVO_GAMEZONE_DATA -ErrorAction SilentlyContinue
    if ($gz) {
        if ($SmartFanMode -gt 0) {
            try { Invoke-CimMethod -InputObject $gz -MethodName SetSmartFanMode -Arguments @{ Data = [uint32]$SmartFanMode } -ErrorAction SilentlyContinue | Out-Null } catch {}
        }
        if ($KeyboardLight -ge 0) {
            try { Invoke-CimMethod -InputObject $gz -MethodName SetKeyboardLight -Arguments @{ Data = [uint32]$KeyboardLight } -ErrorAction SilentlyContinue | Out-Null } catch {}
        }
    }
}

function Stop-PubgWirelessGuardForCampus {
    # Pause task and terminate ONLY the powershell.exe running pubg_wireless_and_hz_guard.ps1
    try { Stop-ScheduledTask -TaskPath '\' -TaskName 'PUBGWirelessAndHzGuard' -ErrorAction SilentlyContinue | Out-Null } catch {}
    $null = schtasks /End /TN "\PUBGWirelessAndHzGuard" 2>$null

    $psProcs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue
    foreach ($p in $psProcs) {
        if ($p.CommandLine -match 'pubg_wireless_and_hz_guard\.ps1' -and $p.ProcessId -ne $PID) {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Đã tạm dừng vòng lặp Wi-Fi CAM của PUBGWirelessAndHzGuard (PID $($p.ProcessId))." -ForegroundColor Green
        }
    }
}

function Start-PubgWirelessGuardForHome {
    try { Start-ScheduledTask -TaskPath '\' -TaskName 'PUBGWirelessAndHzGuard' -ErrorAction SilentlyContinue | Out-Null } catch {}
    $null = schtasks /Run /TN "\PUBGWirelessAndHzGuard" 2>$null
    Write-Host "  -> Đã khôi phục tác vụ \PUBGWirelessAndHzGuard cho PUBG." -ForegroundColor Green
}

# ============================================================================
# 3. Mode Implementations
# ============================================================================

function Invoke-CuuHoRAM {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $osBefore = Get-CimInstance Win32_OperatingSystem
    $freeBeforeMB = [math]::Round($osBefore.FreePhysicalMemory / 1024.0, 0)

    Write-Host "`n=== [CỨU HỘ RAM TỨC THÌ < 2 GIÂY] ===" -ForegroundColor Cyan

    # Hard Whitelist: NEVER touch or kill any of these
    $hardProtected = @(
        'steam', 'steamservice', 'TslGame', 'TslGame_BE', 'TslGame_ZK', 'ExecPubg', 'BEService', 'BEService_x64', 'zksvc',
        'Antigravity', 'language_server_windows_x64', 'rg', 'node', 'python', 'pythonw', 'notebooklm-mcp',
        'powershell', 'pwsh', 'conhost', 'WindowsTerminal', 'cmd',
        'goodbyedpi', 'EVKey64', 'FnHotkeyUtility', 'FnHotkeyCapsLKNumLK', 'LenovoUtilityService',
        'LenovoVantageService', 'LenovoVantage-(LenovoGamingSystemAddin)', 'LenovoVantage-(LenovoGamingUserAddin)', 'LenovoVantage-(VantageCoreAddin)',
        'audiodg', 'RtkAudUService64', 'NVDisplay.Container', 'dwm', 'explorer', 'MsMpEng', 'csrss', 'lsass', 'svchost', 'System', 'Registry', 'Memory Compression'
    )

    # 1. Kill ephemeral bloat processes
    $ephemeralBloat = @(
        'WidgetService', 'WidgetBoard', 'Widgets', 'MicrosoftStartFeedProvider',
        'CrossDeviceResume', 'PhoneExperienceHost', 'GameBar', 'GameBarFTServer',
        'LenovoVantage-(GenericMessagingAddin)', 'LenovoVantage-(GenericTelemetryAddin)',
        'MessagingPlugin', 'UDClientService'
    )
    [double]$killedMB = 0
    foreach ($name in $ephemeralBloat) {
        if ($name -in $hardProtected) { continue }
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            $ws = [math]::Round(($procs | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 1)
            Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
            $killedMB += $ws
            Write-Host "  [Kill Bloat] Đã đóng $name ($ws MB)" -ForegroundColor Green
        }
    }

    # 2. Apply Win32 EcoQoS + MEMORY_PRIORITY_VERY_LOW (1) + EmptyWorkingSet to background helpers
    $fgPid = [PcOptNative]::GetForegroundProcessId()
    $bgHelpers = @('steamwebhelper', 'msedgewebview2', 'SearchHost', 'RuntimeBroker', 'StartMenuExperienceHost', 'ShellExperienceHost', 'TextInputHost')
    [double]$trimmedBytes = 0
    $throttledCount = 0

    foreach ($hName in $bgHelpers) {
        $procs = Get-Process -Name $hName -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            if ($p.Id -eq $fgPid) { continue }
            $beforeWS = $p.WorkingSet64
            $null = [PcOptNative]::SetEcoQoSAndMemoryPriority($p.Id, $true, 1)
            if ([PcOptNative]::TrimProcessWorkingSet($p.Id)) {
                $trimmedBytes += ($beforeWS * 0.65)
                $throttledCount++
            }
        }
    }

    # 3. Safe EcoQoS + EmptyWorkingSet on inactive background browser.exe --type=renderer processes (without windows/audio)
    $coccocRenderers = Get-CimInstance Win32_Process -Filter "Name='browser.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match '--type=renderer' -and $_.CommandLine -notmatch '--extension-process' }
    $coccocTrimmed = 0
    foreach ($r in $coccocRenderers) {
        if ($r.ProcessId -eq $fgPid) { continue }
        $procObj = Get-Process -Id $r.ProcessId -ErrorAction SilentlyContinue
        if ($procObj -and $procObj.MainWindowHandle -eq 0) {
            $beforeWS = $procObj.WorkingSet64
            $null = [PcOptNative]::SetEcoQoSAndMemoryPriority([int]$r.ProcessId, $true, 1)
            if ([PcOptNative]::TrimProcessWorkingSet([int]$r.ProcessId)) {
                $trimmedBytes += ($beforeWS * 0.50)
                $coccocTrimmed++
            }
        }
    }

    # 4. Kernel Memory Combine (130) & Low-Priority Standby Purge (5)
    [PcOptNative]::CombineAndPurgeLowPriorityStandby()

    Start-Sleep -Milliseconds 150
    $osAfter = Get-CimInstance Win32_OperatingSystem
    $freeAfterMB = [math]::Round($osAfter.FreePhysicalMemory / 1024.0, 0)
    $netFreedMB  = [math]::Max(0, ($freeAfterMB - $freeBeforeMB))
    $estTrimMB   = [math]::Round(($trimmedBytes / 1MB) + $killedMB, 0)
    $sw.Stop()

    Write-Host ("  [EcoQoS]     Đã chuyển {0} tiến trình nền + {1} renderer Cốc Cốc ẩn sang EcoQoS & MemoryPriority=1" -f $throttledCount, $coccocTrimmed) -ForegroundColor Green
    Write-Host ("  [RAM Free]   Trước: {0:N0} MB -> Sau: {1:N0} MB (Tăng trực tiếp +{2:N0} MB | Working Set thu hồi ~{3:N0} MB)" -f $freeBeforeMB, $freeAfterMB, $netFreedMB, $estTrimMB) -ForegroundColor Yellow
    Write-Host ("  [Thời gian]  Hoàn tất trong {0} ms (Bảo vệ 100% Cốc Cốc, Steam, Antigravity, Python, Node)" -f $sw.ElapsedMilliseconds) -ForegroundColor Cyan
}

function Invoke-CheDoDiHoc {
    param([switch]$Ultra)
    $modeLabel = if ($Ultra) { "CHẾ ĐỘ [2] ĐI HỌC SIÊU TRÂU (8h - 9.5h)" } else { "CHẾ ĐỘ [1] ĐI HỌC TIÊU CHUẨN (6h12p - 7h32p)" }
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " ĐANG KÍCH HOẠT: $modeLabel" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan

    Save-PriorBrightnessIfNeeded

    $freqCap    = if ($Ultra) { 1700 } else { 2400 }
    $eppVal     = if ($Ultra) { 100 }  else { 90 }
    $maxCores   = if ($Ultra) { 50 }   else { 100 }
    $targetBri  = if ($Ultra) { 12 }   else { 20 }

    # 1. Configure DC powercfg parameters (leaving AC untouched for gaming!)
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 0          # DC PERFBOOSTMODE = 0 (Disabled)
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 75b0ae3f-bce0-45a7-8c89-c9611c25e100 $freqCap   # DC PROCFREQMAX
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $eppVal    # DC PERFEPP
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 10         # DC CPMINCORES = 10%
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 $maxCores  # DC CPMAXCORES (100% or 50%)
    powercfg /setdcvalueindex SCHEME_CURRENT 5fb4938d-1ee8-4b0f-9a3c-5036b0ab995c dd848b2a-8a5d-4451-9ae2-39cd41658f6c 1          # DC GPUPREFERENCEPOLICY = 1 (Low Power iGPU)
    powercfg /setdcvalueindex SCHEME_CURRENT de830923-a562-41af-a086-e3a2c6bad2da e69653ca-cf7f-4f05-aa73-cb833fa90ad4 100        # DC ESBATTTHRESHOLD = 100%
    powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3          # DC Wireless Saving = 3 (Max Saving)
    powercfg /setdcvalueindex SCHEME_CURRENT 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4 2          # DC Multimedia Video = 2 (Power Savings)
    powercfg /setdcvalueindex SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 180        # DC Display Off = 180s
    powercfg /setdcvalueindex SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 600        # DC Sleep = 600s
    powercfg /setactive SCHEME_CURRENT

    # Activate Windows Best Power Efficiency Overlay Scheme
    $null = [PcOptNative]::SetOverlayScheme("961cc777-2547-4f9d-8174-7d86181b8a7a")
    Write-Host "  -> Đã cấu hình DC Power Plan: Boost=OFF, MaxFreq=${freqCap}MHz, EPP=${eppVal}%, MaxCores=${maxCores}%, Wi-Fi Saving=3" -ForegroundColor Green

    # 2. Pause PUBGWirelessAndHzGuard while on battery
    Stop-PubgWirelessGuardForCampus

    # 3. Lenovo EC Quiet Mode (1) & Keyboard Backlight Off in Ultra
    if ($Ultra) {
        Set-LenovoThermalAndLight -SmartFanMode 1 -KeyboardLight 0
        Write-Host "  -> Đã đặt quạt Lenovo Quiet Mode (1) & tắt đèn nền bàn phím (SetKeyboardLight=0)." -ForegroundColor Green
        try { Stop-Service -Name 'WSearch' -Force -ErrorAction SilentlyContinue } catch {}
        foreach ($polRoot in @('HKCU:\Software\CocCoc\Browser', 'HKCU:\Software\Policies\CocCoc\Browser', 'HKLM:\SOFTWARE\Policies\CocCoc\Browser')) {
            try {
                if (-not (Test-Path $polRoot)) { New-Item -Path $polRoot -Force -ErrorAction Stop | Out-Null }
                New-ItemProperty -Path $polRoot -Name 'HighEfficiencyModeEnabled' -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
                New-ItemProperty -Path $polRoot -Name 'BatterySaverModeAvailability' -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            } catch {}
        }
        Write-Host "  -> Đã bật chính sách Cốc Cốc Memory Saver & Energy Saver + tạm dừng Windows Search trên pin." -ForegroundColor Green
    } else {
        Set-LenovoThermalAndLight -SmartFanMode 1
        Write-Host "  -> Đã đặt quạt Lenovo Quiet Mode (1)." -ForegroundColor Green
    }

    # 4. Dim screen brightness (keep 60Hz default)
    if (Set-ScreenBrightness -Level $targetBri) {
        Write-Host "  -> Đã hạ độ sáng màn hình xuống ${targetBri}% (giữ nguyên 2560x1600 @ 60Hz)." -ForegroundColor Green
    }

    # 5. Conditional RTX 3060 D3cold reset ONLY if Hybrid Mode is active
    $gpu = Get-GpuHybridStatus
    if ($gpu.HybridModeOn) {
        Write-Host "  -> Hybrid Mode đang BẬT: Đang đưa RTX 3060 vào trạng thái ngủ sâu D3cold (0.0W)..." -ForegroundColor Green
        $null = pnputil /restart-device "PCI\VEN_10DE&DEV_2560*" 2>$null
    } else {
        Write-Host "  -> [Lưu ý MUX Switch] Máy đang ở chế độ dGPU-Only (Hybrid Mode TẮT). Nếu muốn đạt 7h30p - 9h30p khi đi học, hãy bật Hybrid Mode trong Lenovo Vantage và khởi động lại 1 lần." -ForegroundColor Yellow
    }

    # 6. Run Safe RAM Rescue
    Invoke-CuuHoRAM
}

function Invoke-SacDay100 {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " CHẾ ĐỘ [3]: CHUẨN BỊ ĐI HỌC - NẠP ĐẦY 100% MÁT MÁY" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan
    if (Set-BatteryChargeModeSafe -Mode 'Normal') {
        $bat = Get-BatteryLiveTelemetry
        Write-Host "  -> Đã chuyển mạch sạc Lenovo sang Normal (100%), RapidCharge = $($bat.IsRapidCharge)." -ForegroundColor Green
        Write-Host "  -> Pin hiện tại: $($bat.Percent)% ($($bat.VoltageMV) mV | $($bat.TemperatureC) °C)." -ForegroundColor Cyan
        Write-Host "  -> Lời khuyên: Hãy cắm sạc trước khi đi học 45-60 phút khi máy đang nghỉ mát (không vừa sạc lên 100% vừa chơi game nặng)." -ForegroundColor Yellow
    } else {
        Write-Warning "Không thể đổi chế độ sạc qua IdeaBatteryAgent.dll."
    }
}

function Invoke-VeNha {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " CHẾ ĐỘ [4]: VỀ NHÀ / CẮM SẠC CHƠI GAME BỀN PIN (STORAGE 60%)" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Cyan

    # 1. Enable Storage (Conservation Mode 55-60%)
    if (Set-BatteryChargeModeSafe -Mode 'Storage') {
        Write-Host "  -> Đã BẬT khóa bảo vệ pin Conservation Mode (Storage 55% - 60%, RapidCharge = False)." -ForegroundColor Green
    }

    # 2. Restore DC power settings and confirm AC Efficient Aggressive (4)
    powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 4
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 2
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 75b0ae3f-bce0-45a7-8c89-c9611c25e100 3500
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 60
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 25
    powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 100
    powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0
    powercfg /setactive SCHEME_CURRENT
    $null = [PcOptNative]::SetOverlayScheme("00000000-0000-0000-0000-000000000000")
    Write-Host "  -> Đã khôi phục xung CPU (100% nhân, AC Boost = Efficient Aggressive mát máy -8°C đến -12°C)." -ForegroundColor Green

    # 3. Restore brightness
    $restoreBri = 60
    if (Test-Path $RuntimeState) {
        try {
            $st = Get-Content $RuntimeState -Raw | ConvertFrom-Json
            if ($null -ne $st.PriorBrightness -and $st.PriorBrightness -ge 0) {
                $restoreBri = [int]$st.PriorBrightness
            }
            $st | Add-Member -NotePropertyName InCampusMode -NotePropertyValue $false -Force
            $st | ConvertTo-Json | Set-Content -Path $RuntimeState -Encoding UTF8
        } catch {}
    } elseif (Test-Path $BaselineFile) {
        try {
            $bl = Get-Content $BaselineFile -Raw | ConvertFrom-Json
            if ($null -ne $bl.OriginalBrightness) { $restoreBri = [int]$bl.OriginalBrightness }
        } catch {}
    }
    $null = Set-ScreenBrightness -Level $restoreBri
    Write-Host "  -> Đã khôi phục độ sáng màn hình ($restoreBri%) và giữ nguyên 2560x1600 @ 60Hz." -ForegroundColor Green

    # 4. Resume WSearch & remove temporary Cốc Cốc campus policy if present
    try { Start-Service -Name 'WSearch' -ErrorAction SilentlyContinue } catch {}
    foreach ($polRoot in @('HKCU:\Software\CocCoc\Browser', 'HKCU:\Software\Policies\CocCoc\Browser', 'HKLM:\SOFTWARE\Policies\CocCoc\Browser')) {
        try {
            if (Test-Path $polRoot) {
                Remove-ItemProperty -Path $polRoot -Name 'HighEfficiencyModeEnabled' -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $polRoot -Name 'BatterySaverModeAvailability' -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    # 5. Restart PUBGWirelessAndHzGuard & Lenovo Balanced Mode (2)
    Start-PubgWirelessGuardForHome
    Set-LenovoThermalAndLight -SmartFanMode 2

    # 6. Clear EcoQoS on background helpers
    foreach ($hName in @('steamwebhelper', 'msedgewebview2', 'SearchHost', 'RuntimeBroker')) {
        $procs = Get-Process -Name $hName -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            $null = [PcOptNative]::SetEcoQoSAndMemoryPriority($p.Id, $false, 5)
        }
    }

    $bat = Get-BatteryLiveTelemetry
    if ($bat -and $bat.ChargeMode -eq 'Storage' -and $bat.Percent -gt 65) {
        Write-Host "`n  [NHẮC NHỞ QUAN TRỌNG - BẪY 100% PIN]:" -ForegroundColor Yellow
        Write-Host "  Pin đang ở mức $($bat.Percent)% ($($bat.CellVoltageV) V/cell). Dù đã bật Conservation Mode (60%), mạch sạc Lenovo không tự xả pin khi đang cắm sạc." -ForegroundColor Yellow
        Write-Host "  -> Bạn hãy rút sạc dùng bình thường cho tới khi pin hạ xuống 55% - 60% (~3.89 V/cell) rồi cắm sạc lại để bảo vệ pin tối đa khi chơi game nóng!" -ForegroundColor Yellow
    }
}

function Get-InCampusModeState {
    param([int]$DCMaxFreqMHz = 3500)
    $inCampus = $false
    if (Test-Path $RuntimeState) {
        try {
            $st = Get-Content $RuntimeState -Raw | ConvertFrom-Json
            if ($null -ne $st.InCampusMode) {
                $inCampus = [bool]$st.InCampusMode
            }
        } catch {}
    }
    if ($DCMaxFreqMHz -gt 0 -and $DCMaxFreqMHz -le 2400) {
        $inCampus = $true
    }
    return $inCampus
}

function Get-SmartAdvisorRecommendations {
    param(
        [int]$ACLineStatus,
        [int]$BatteryPercent,
        [string]$ChargeMode,
        [bool]$InCampusMode,
        [int]$RamUsedPct
    )
    $tips = New-Object System.Collections.Generic.List[PSCustomObject]

    if ($ACLineStatus -eq 1 -and $ChargeMode -eq 'Storage' -and $BatteryPercent -gt 65) {
        $tips.Add([PSCustomObject]@{
            Case  = 'A'
            Color = 'Yellow'
            Text  = "-> [Ở NHÀ - CHỐNG CHAI PIN]: Máy đã bật Khóa sạc 60% (Storage), nhưng pin đang ở ${BatteryPercent}% (> 65%). Bạn nên RÚT SẠC dùng cho pin hạ xuống 58%-60% một lần rồi cắm sạc lại để pin nghỉ ở 3.89V/cell khi chơi game nóng!"
        })
    }

    if ($ACLineStatus -eq 1 -and $InCampusMode) {
        $tips.Add([PSCustomObject]@{
            Case  = 'B'
            Color = 'Magenta'
            Text  = "-> [MỚI ĐI HỌC VỀ]: Máy đang cắm sạc nhưng vẫn ở Chế độ Đi Học. Hãy bấm phím [4] (Về Nhà) để bật lại Khóa sạc 60%, khôi phục độ sáng màn hình gốc và bật lại bảo vệ Wi-Fi PUBG!"
        })
    }

    if ($ACLineStatus -eq 0 -and (-not $InCampusMode)) {
        $tips.Add([PSCustomObject]@{
            Case  = 'C'
            Color = 'Yellow'
            Text  = "-> [ĐANG DÙNG PIN]: Máy đang rút sạc! Nếu đi học lướt Cốc Cốc/YouTube bình thường hãy chọn [1] (Đi Học Tiêu Chuẩn ~6-7h). Nếu cần trụ cả ngày hãy chọn [2] (Đi Học Siêu Trâu ~8-9h)."
        })
    }

    if ($ACLineStatus -eq 1) {
        $tips.Add([PSCustomObject]@{
            Case  = 'D'
            Color = 'Cyan'
            Text  = "-> [NẾU SẮP ĐI HỌC]: Trước khi đi học 45-60 phút, bấm phím [3] để mở khóa nạp đầy 100% pin, sau đó bấm [1] hoặc [2] trước khi rút sạc bỏ vào balo."
        })
    }

    if ($RamUsedPct -ge 75) {
        $tips.Add([PSCustomObject]@{
            Case  = 'E'
            Color = 'Red'
            Text  = "-> [CẢNH BÁO RAM]: RAM đang dùng ${RamUsedPct}%. Hãy bấm phím [5] để xả RAM rác tức thì trong < 1 giây!"
        })
    }

    return $tips
}

function Show-SystemStatus {
    $bat   = Get-BatteryLiveTelemetry
    $gpu   = Get-GpuHybridStatus
    $os    = Get-CimInstance Win32_OperatingSystem
    $cDrv  = Get-PSDrive -Name C
    $boost = Get-PowerIndex -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting 'be337238-0d82-4146-a960-4f3749d470c7'
    $freq  = Get-PowerIndex -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting '75b0ae3f-bce0-45a7-8c89-c9611c25e100'
    $cores = Get-PowerIndex -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting 'ea062031-0e34-4ff1-9b6d-eb1059334028'
    $wifi  = Get-PowerIndex -Subgroup '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1' -Setting '12bbebe6-58d6-4636-95bb-3217ef867c1a'
    $bri   = Get-CurrentBrightness
    $guard = Get-ScheduledTask -TaskName 'PUBGWirelessAndHzGuard' -ErrorAction SilentlyContinue
    $usbHdd = Get-PnpDevice -Class DiskDrive -Status OK -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -match 'ST950032' }

    $ramTotalMB = [math]::Round($os.TotalVisibleMemorySize / 1024.0, 0)
    $ramFreeMB  = [math]::Round($os.FreePhysicalMemory / 1024.0, 0)
    $ramUsedMB  = $ramTotalMB - $ramFreeMB
    $ramUsedPct = [int][math]::Round(($ramUsedMB / [double]$ramTotalMB) * 100.0, 0)
    $inCampus   = Get-InCampusModeState -DCMaxFreqMHz ([int]$freq.DC)
    $acLine     = if ($bat -and $bat.PowerOnline) { 1 } else { 0 }

    Write-Host "`n======================================================================" -ForegroundColor Cyan
    Write-Host "   BẢNG ĐIỀU KHIỂN ĐI HỌC & CỨU HỘ - LENOVO LEGION 5 PRO (82JQ)" -ForegroundColor Yellow
    Write-Host "======================================================================" -ForegroundColor Cyan

    if ($bat) {
        $modeDesc = if ($bat.ChargeMode -eq 'Storage') { "Storage (Khóa bảo vệ pin 55%-60%)" } else { "Normal (Sạc đầy 100%)" }
        $acStr    = if ($bat.PowerOnline) { "Đang cắm sạc AC (ACLineStatus=1)" } else { "Đang dùng Pin DC (ACLineStatus=0 | Xả $($bat.DischargeRateW) W)" }
        Write-Host ("  [Pin & Nhiệt độ]  : {0}% ({1} Wh / {2} Wh) | {3} mV ({4} V/cell) | Nhiệt độ: {5} °C" -f $bat.Percent, $bat.RemainingWh, $bat.FullCapWh, $bat.VoltageMV, $bat.CellVoltageV, $bat.TemperatureC) -ForegroundColor Green
        Write-Host ("  [Chế độ Sạc]      : {0} | Sạc nhanh: {1} | Chu kỳ: {2} ({3}% Sức khỏe) | {4}" -f $modeDesc, $bat.IsRapidCharge, $bat.CycleCount, $bat.HealthPct, $acStr) -ForegroundColor Green
    }
    Write-Host ("  [Đồ họa MUX/GPU]  : Hybrid Mode = {0} | RTX 3060: {1} ({2})" -f $(if ($gpu.HybridModeOn) { "BẬT (Tiết kiệm pin)" } else { "TẮT (dGPU-Only)" }), $gpu.RtxState, $gpu.RtxPower) -ForegroundColor Cyan
    Write-Host ("  [Cấu hình Nguồn]  : AC Boost={0} | DC Boost={1} | DC MaxFreq={2} MHz | DC MaxCores={3}% | DC Wi-Fi={4} | InCampusMode={5}" -f $boost.AC, $boost.DC, $freq.DC, $cores.DC, $wifi.DC, $inCampus)
    Write-Host ("  [Màn hình & PUBG] : 2560x1600 @ 60Hz | Độ sáng: {0}% | PUBGWirelessGuard: {1}" -f $bri, $guard.State)
    Write-Host ("  [Bộ nhớ & Ổ đĩa]  : RAM Trống: {0:N0} MB / {1:N0} MB (Đang dùng {2:N0} MB = {3}%) | Ổ C: Trống {4:N2} GB" -f $ramFreeMB, $ramTotalMB, $ramUsedMB, $ramUsedPct, ($cDrv.Free / 1GB)) -ForegroundColor Yellow

    if ($usbHdd) {
        Write-Host "  [Cảnh báo USB]    : Đang cắm ổ cứng cơ USB (ST950032 5AS tốn ~2.2W). Nhớ rút ra trước khi mang máy đi học!" -ForegroundColor Yellow
    }

    if ($bat) {
        $availWh = $bat.RemainingWh
        $safeWh  = [math]::Max(0.0, $availWh - ($bat.FullCapWh * 0.15))
        Write-Host "`n  --- DỰ BÁO THỜI LƯỢNG PIN VỚI MỨC PIN HIỆN TẠI ($($bat.Percent)% = $availWh Wh) ---" -ForegroundColor Cyan
        Write-Host ("  * Chế độ [1]/[2] (Không bật Hybrid Mode, RTX 3060 thức ~14.6W) : ~{0:N1} giờ (Dừng an toàn 15%: ~{1:N1} giờ)" -f ($availWh / 14.6), ($safeWh / 14.6))
        Write-Host ("  * Chế độ [1] Đi Học Tiêu Chuẩn + Hybrid Mode BẬT (~9.6W)       : ~{0:N1} giờ (Dừng an toàn 15%: ~{1:N1} giờ)" -f ($availWh / 9.6), ($safeWh / 9.6)) -ForegroundColor Green
        Write-Host ("  * Chế độ [2] Đi Học Siêu Trâu + Hybrid Mode BẬT + Wi-Fi (~8.6W): ~{0:N1} giờ (Dừng an toàn 15%: ~{1:N1} giờ)" -f ($availWh / 8.6), ($safeWh / 8.6)) -ForegroundColor Green
        Write-Host ("  * Chế độ [2] Đi Học Siêu Trâu + Hybrid BẬT + Tắt Wi-Fi (~7.5W) : ~{0:N1} giờ (Dừng an toàn 15%: ~{1:N1} giờ)" -f ($availWh / 7.5), ($safeWh / 7.5)) -ForegroundColor Green
    }

    $batPct     = if ($bat) { [int]$bat.Percent } else { 0 }
    $chargeMode = if ($bat) { [string]$bat.ChargeMode } else { 'Unknown' }
    $advisorTips = Get-SmartAdvisorRecommendations -ACLineStatus $acLine -BatteryPercent $batPct -ChargeMode $chargeMode -InCampusMode $inCampus -RamUsedPct $ramUsedPct

    Write-Host "`n  ====================================================================" -ForegroundColor Yellow
    Write-Host "   [GỢI Ý HÀNH ĐỘNG TIẾP THEO] (SMART ADVISOR)" -ForegroundColor Yellow
    Write-Host "  ====================================================================" -ForegroundColor Yellow
    foreach ($tip in $advisorTips) {
        Write-Host "  $($tip.Text)" -ForegroundColor $tip.Color
    }
    Write-Host "======================================================================`n" -ForegroundColor Cyan
}

# ============================================================================
# 4. CLI Parameter Router vs Interactive Menu
# ============================================================================
if ($Status) {
    Show-SystemStatus
    exit 0
}
if ($DiHoc) {
    Invoke-CheDoDiHoc
    exit 0
}
if ($DiHocUltra) {
    Invoke-CheDoDiHoc -Ultra
    exit 0
}
if ($SacDay100) {
    Invoke-SacDay100
    exit 0
}
if ($VeNha) {
    Invoke-VeNha
    exit 0
}
if ($CuuHoRAM) {
    Invoke-CuuHoRAM
    exit 0
}
if ($UndoBaseline) {
    $baselineScript = Join-Path $ProjectDir "baseline_setup.ps1"
    if (Test-Path $baselineScript) {
        & $baselineScript -Undo
    }
    exit 0
}

# Interactive Menu when launched without switches
while ($true) {
    Show-SystemStatus
    Write-Host "  CHỌN CHẾ ĐỘ (Nhập số từ 1 đến 6 hoặc 0 để thoát):" -ForegroundColor Yellow
    Write-Host "    [1] Đi Học Tiêu Chuẩn (Tắt Boost trên pin, 2.4GHz, sáng 20%, tạm dừng PUBG Wi-Fi Guard, xả RAM)"
    Write-Host "    [2] Đi Học Siêu Trâu 8h-9.5h (Ép 4 nhân 1.7GHz, tắt đèn phím & Search, sáng 12%, Cốc Cốc Saver)"
    Write-Host "    [3] Chuẩn Bị Đi Học: Nạp Đầy 100% Mát Máy (Mở khóa 100% Normal Mode, tắt sạc nhanh)"
    Write-Host "    [4] Về Nhà / Cắm Sạc Chơi Game (Bật khóa bảo vệ pin 60% Storage, khôi phục PUBG Guard & độ sáng)"
    Write-Host "    [5] Cứu Hộ Xả RAM Tức Thì < 2 Giây (Đóng bloat ngầm + EcoQoS + thu hồi RAM, giữ nguyên nguồn)"
    Write-Host "    [6] Khôi Phục Cài Đặt Gốc Ban Đầu (Undo Baseline)"
    Write-Host "    [0] Thoát"
    Write-Host ""
    $choice = Read-Host "  Nhập lựa chọn của bạn [0-6]"
    switch ($choice.Trim()) {
        '1' { Invoke-CheDoDiHoc; Pause }
        '2' { Invoke-CheDoDiHoc -Ultra; Pause }
        '3' { Invoke-SacDay100; Pause }
        '4' { Invoke-VeNha; Pause }
        '5' { Invoke-CuuHoRAM; Pause }
        '6' {
            $baselineScript = Join-Path $ProjectDir "baseline_setup.ps1"
            if (Test-Path $baselineScript) { & $baselineScript -Undo }
            Pause
        }
        '0' { break }
        default { Write-Host "  Lựa chọn không hợp lệ, vui lòng nhập từ 0 đến 6." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}

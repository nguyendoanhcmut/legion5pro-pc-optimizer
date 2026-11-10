#Requires -Version 5.1
<#
.SYNOPSIS
    Chế Độ Đi Học & Cứu Hộ RAM Tức Thì (Lenovo Legion 5 Pro 16ACH6H / 82JQ)
.DESCRIPTION
    1 Script Duy Nhất tích hợp:
      [1] -DiHoc             : Chế độ Đi Học Tiêu Chuẩn (6h12p - 7h32p khi bật Hybrid Mode)
      [2] -DiHocUltra        : Chế độ Đi Học Siêu Trâu 8h - 9.5h (4 nhân 1.7GHz, tắt đèn phím, 12% sáng, EcoQoS)
      [3] -SacDay100         : Chuẩn bị đi học - Sạc đầy 100% mát máy (Normal Mode, tắt sạc nhanh)
      [4] -VeNha             : Về nhà / Cắm sạc chơi game bền pin (Conservation Mode 55-60%, bật lại PUBG Guard)
      [5] -CuuHoRAM          : Cứu hộ xả RAM tức thì < 2 giây (EcoQoS + Trim Working Set + Kill Bloat)
      [6] -BedtimePrompt     : Nhắc chọn chế độ pin lúc 22:15 (chờ thoát game Steam/PUBG -> hỏi sạc 100% hoặc giữ 60%)
      [7] -UndoBaseline      : Khôi phục cài đặt gốc ban đầu (gọi baseline_setup.ps1 -Undo)
      [*] -Status            : Xem trạng thái Pin (%, mV, °C, Wh), Card rời RTX 3060, RAM và dự báo số giờ dùng pin
#>
[CmdletBinding()]
param(
    [switch]$Status,
    [switch]$DiHoc,
    [switch]$DiHocUltra,
    [switch]$SacDay100,
    [switch]$VeNha,
    [switch]$CuuHoRAM,
    [switch]$UndoBaseline,
    [switch]$BedtimePrompt,
    [switch]$TestBedtimePrompt,
    [switch]$CheckReturnHome,
    [switch]$RegisterBedtimeTask,
    [switch]$DisableBedtimeTask,
    [switch]$BedtimeTaskStatus,
    [ValidateSet('', '1', '2', '3', 'Timeout')]
    [string]$AutoSelectForTest = '',
    [string]$CaptureGuiScreenshot = '',
    [string]$SteamRegistryPathOverride = '',
    [int]$SimulateGameWaitMs = 0
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

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetProcessWorkingSetSize(IntPtr hProcess, IntPtr dwMinimumWorkingSetSize, IntPtr dwMaximumWorkingSetSize);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("powrprof.dll", EntryPoint = "PowerSetActiveOverlayScheme")]
    public static extern uint PowerSetActiveOverlayScheme( ref Guid OverlaySchemeGuid );

    [DllImport("powrprof.dll")]
    public static extern uint PowerGetActiveScheme(IntPtr UserRootPowerKey, out IntPtr ActivePolicyGuid);

    [DllImport("powrprof.dll")]
    public static extern uint PowerWriteDCValueIndex(IntPtr RootPowerKey, IntPtr SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, uint DcValueIndex);

    [DllImport("powrprof.dll")]
    public static extern uint PowerWriteACValueIndex(IntPtr RootPowerKey, IntPtr SchemeGuid, ref Guid SubGroupOfPowerSettingsGuid, ref Guid PowerSettingGuid, uint AcValueIndex);

    [DllImport("powrprof.dll")]
    public static extern uint PowerSetActiveScheme(IntPtr UserRootPowerKey, IntPtr SchemeGuid);

    [DllImport("kernel32.dll")]
    public static extern IntPtr LocalFree(IntPtr hMem);

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

    public static void TrimSelfAndSleep(int sleepMs) {
        try {
            SetEcoQoSAndMemoryPriority(System.Diagnostics.Process.GetCurrentProcess().Id, true, 1);
        } catch {}
        GC.Collect();
        GC.WaitForPendingFinalizers();
        IntPtr h = GetCurrentProcess();
        SetProcessWorkingSetSize(h, new IntPtr(-1), new IntPtr(-1));
        EmptyWorkingSet(h);
        if (sleepMs > 0) {
            System.Threading.Thread.Sleep(sleepMs);
        }
    }

    private static void WriteDc(IntPtr pScheme, string subStr, string setStr, uint val) {
        Guid sub = new Guid(subStr);
        Guid set = new Guid(setStr);
        PowerWriteDCValueIndex(IntPtr.Zero, pScheme, ref sub, ref set, val);
    }

    private static void WriteAc(IntPtr pScheme, string subStr, string setStr, uint val) {
        Guid sub = new Guid(subStr);
        Guid set = new Guid(setStr);
        PowerWriteACValueIndex(IntPtr.Zero, pScheme, ref sub, ref set, val);
    }

    public static bool ApplyCampusDcProfileFast(bool isCampus, uint freqCap, uint eppVal, uint maxCores) {
        IntPtr pScheme = IntPtr.Zero;
        if (PowerGetActiveScheme(IntPtr.Zero, out pScheme) != 0 || pScheme == IntPtr.Zero) return false;
        try {
            if (isCampus) {
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "be337238-0d82-4146-a960-4f3749d470c7", 0u);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "75b0ae3f-bce0-45a7-8c89-c9611c25e100", freqCap);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "36687f9e-e3a5-4dbf-b1dc-15eb381c6863", eppVal);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "0cc5b647-c1df-4637-891a-dec35c318583", 10u);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "ea062031-0e34-4ff1-9b6d-eb1059334028", maxCores);
                WriteDc(pScheme, "5fb4938d-1ee8-4b0f-9a3c-5036b0ab995c", "dd848b2a-8a5d-4451-9ae2-39cd41658f6c", 1u);
                WriteDc(pScheme, "de830923-a562-41af-a086-e3a2c6bad2da", "e69653ca-cf7f-4f05-aa73-cb833fa90ad4", 100u);
                WriteDc(pScheme, "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1", "12bbebe6-58d6-4636-95bb-3217ef867c1a", 3u);
                WriteDc(pScheme, "9596fb26-9850-41fd-ac3e-f7c3c00afd4b", "34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4", 2u);
                WriteDc(pScheme, "7516b95f-f776-4464-8c53-06167f40cc99", "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e", 180u);
                WriteDc(pScheme, "238c9fa8-0aad-41ed-83f4-97be242c8f20", "29f6c1db-86da-48c5-9fdb-f2b67b1f44da", 600u);
            } else {
                WriteAc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "be337238-0d82-4146-a960-4f3749d470c7", 4u);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "be337238-0d82-4146-a960-4f3749d470c7", 2u);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "75b0ae3f-bce0-45a7-8c89-c9611c25e100", 3500u);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "36687f9e-e3a5-4dbf-b1dc-15eb381c6863", 60u);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "0cc5b647-c1df-4637-891a-dec35c318583", 25u);
                WriteDc(pScheme, "54533251-82be-4824-96c1-47b60b740d00", "ea062031-0e34-4ff1-9b6d-eb1059334028", 100u);
                WriteDc(pScheme, "19cbb8fa-5279-450e-9fac-8a3d5fedd0c1", "12bbebe6-58d6-4636-95bb-3217ef867c1a", 0u);
            }
            return PowerSetActiveScheme(IntPtr.Zero, pScheme) == 0;
        } finally {
            LocalFree(pScheme);
        }
    }
}
"@

if (-not ("PcOptNative" -as [type])) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashHex = ([System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($nativeCode))) -replace '-', '').Substring(0, 12)
    $sha.Dispose()
    $cachedDll = Join-Path $BackupDir "PcOptNative_$hashHex.dll"
    if (Test-Path $cachedDll) {
        try { Add-Type -Path $cachedDll -ErrorAction Stop } catch {}
    }
    if (-not ("PcOptNative" -as [type])) {
        try {
            Get-ChildItem -Path $BackupDir -Filter "PcOptNative_*.dll" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Add-Type -TypeDefinition $nativeCode -Language CSharp -OutputAssembly $cachedDll -ErrorAction Stop
            Add-Type -Path $cachedDll -ErrorAction Stop
        } catch {
            Add-Type -TypeDefinition $nativeCode -Language CSharp -ErrorAction SilentlyContinue
        }
    }
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
    param([switch]$SkipWmiRates)
    $agent = Initialize-IdeaBatteryAgent
    $wmiBat = if ($SkipWmiRates) { $null } else { Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus -ErrorAction SilentlyContinue }
    if ($agent) {
        try {
            $cm = $agent.GetBatteryChargeMode()
            $bi = $agent.GetBatteryInformation().BatteryInformationList[0]
            $cellV = [math]::Round($bi.Voltage / 4000.0, 3)
            $powerOnline = if ($null -ne $wmiBat) { [bool]$wmiBat.PowerOnline } else { [bool]$agent.IsACIn() }
            $dischargeW = if ($wmiBat -and $wmiBat.DischargeRate -gt 0) { [math]::Round($wmiBat.DischargeRate / 1000.0, 2) } else { 0.0 }
            $chargeMW   = if ($wmiBat -and $wmiBat.ChargeRate -gt 0) { [int]$wmiBat.ChargeRate } else { 0 }
            $currentMA  = [int]$bi.Current
            $chargeW    = if ($chargeMW -gt 0) {
                [math]::Round($chargeMW / 1000.0, 2)
            } elseif ($powerOnline -and $currentMA -gt 0 -and $bi.Voltage -gt 0) {
                [math]::Round(($currentMA * [double]$bi.Voltage) / 1000000.0, 2)
            } else {
                0.0
            }
            return [PSCustomObject]@{
                Percent          = [int]$bi.RemainingPercent
                RemainingWh      = [math]::Round($bi.RemainingCapacity / 1000.0, 2)
                RemainingMWh     = [int]$bi.RemainingCapacity
                FullCapWh        = [math]::Round($bi.FullChargeCapacity / 1000.0, 2)
                DesignCapWh      = [math]::Round($bi.DesignCapacity / 1000.0, 2)
                HealthPct        = [math]::Round(($bi.FullChargeCapacity / [double]$bi.DesignCapacity) * 100.0, 2)
                VoltageMV        = [int]$bi.Voltage
                CellVoltageV     = $cellV
                CurrentMA        = $currentMA
                ChargeStatus     = $bi.ChargeStatus.ToString()
                TemperatureC     = [int]$bi.Temperature
                CycleCount       = [int]$bi.CycleCount
                ChargeMode       = $cm.BatteryChargeMode.ToString()
                IsRapidCharge    = [bool]$bi.IsExpressCharging
                PowerOnline      = $powerOnline
                WmiCharging      = if ($null -ne $wmiBat) { [bool]$wmiBat.Charging } else { ($bi.ChargeStatus.ToString() -eq 'Charging') }
                ChargeRateMW     = $chargeMW
                DischargeRateW   = $dischargeW
                ChargeRateW      = $chargeW
            }
        } catch {}
    }
    return $null
}

function Set-BatteryChargeModeSafe {
    param(
        [ValidateSet('Normal', 'Storage')][string]$Mode,
        [switch]$VerifyChargeRate,
        [switch]$PumpUiEvents,
        [int]$MaxVerifyWaitMs = 11000
    )
    $agent = Initialize-IdeaBatteryAgent
    if (-not $agent) { return $false }
    try {
        $req = New-Object Lenovo.Modern.Contracts.BatteryManagement.BatteryMgmtRequest
        $req.BatteryChargeMode = [Lenovo.Modern.Contracts.BatteryManagement.BatteryChargeModeType]::$Mode
        $null = $agent.SetBatteryChargeMode($req)
        $modeOk = ($agent.GetBatteryChargeMode().BatteryChargeMode.ToString() -eq $Mode)
        if (-not $modeOk) {
            Start-Sleep -Milliseconds 250
            $null = $agent.SetBatteryChargeMode($req)
            $modeOk = ($agent.GetBatteryChargeMode().BatteryChargeMode.ToString() -eq $Mode)
        }
        if (-not $modeOk) { return $false }

        $script:LastVerifiedChargeRateMW = 0
        if ($Mode -eq 'Normal' -and $VerifyChargeRate) {
            $swVerify = [Diagnostics.Stopwatch]::StartNew()
            $retriedApply = $false
            while ($swVerify.ElapsedMilliseconds -lt $MaxVerifyWaitMs) {
                $wmiNow = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus -ErrorAction SilentlyContinue
                $biNow  = $agent.GetBatteryInformation().BatteryInformationList[0]
                $pctNow = if ($biNow) { [int]$biNow.RemainingPercent } else { 100 }
                $acNow  = if ($null -ne $wmiNow) { [bool]$wmiNow.PowerOnline } else { [bool]$agent.IsACIn() }

                # Only require positive ChargeRate when AC is online and SoC < 98%
                if ((-not $acNow) -or ($pctNow -ge 98)) {
                    if ($null -ne $wmiNow) { $script:LastVerifiedChargeRateMW = [int]$wmiNow.ChargeRate }
                    return $true
                }
                if ($null -ne $wmiNow -and [int]$wmiNow.ChargeRate -gt 0) {
                    $script:LastVerifiedChargeRateMW = [int]$wmiNow.ChargeRate
                    return $true
                }
                if (-not $retriedApply -and $swVerify.ElapsedMilliseconds -ge 4000) {
                    $retriedApply = $true
                    $null = $agent.SetBatteryChargeMode($req)
                }
                if ($PumpUiEvents) {
                    for ($i = 0; $i -lt 4; $i++) {
                        [System.Windows.Forms.Application]::DoEvents()
                        Start-Sleep -Milliseconds 100
                    }
                } else {
                    Start-Sleep -Milliseconds 400
                }
            }

            # Fallback: if WMI ChargeRate is still 0 mW on AC with SoC < 98% and running non-elevated interactively, self-elevate once
            $wmiCheck = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus -ErrorAction SilentlyContinue
            $biCheck  = $agent.GetBatteryInformation().BatteryInformationList[0]
            if ($null -ne $wmiCheck -and $wmiCheck.PowerOnline -and [int]$biCheck.RemainingPercent -lt 98 -and [int]$wmiCheck.ChargeRate -le 0) {
                $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
                if ((-not $isAdmin) -and [string]::IsNullOrEmpty($AutoSelectForTest)) {
                    try {
                        $selfPath = Join-Path $ProjectDir 'CheDoDiHoc_CuuHo.ps1'
                        Start-Process -FilePath 'powershell.exe' -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$selfPath`" -SacDay100" -ErrorAction Stop
                        $swElev = [Diagnostics.Stopwatch]::StartNew()
                        while ($swElev.ElapsedMilliseconds -lt 8000) {
                            $wmiPost = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus -ErrorAction SilentlyContinue
                            if ($null -ne $wmiPost -and [int]$wmiPost.ChargeRate -gt 0) { return $true }
                            Start-Sleep -Milliseconds 400
                        }
                    } catch {}
                }
                $wmiLast = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus -ErrorAction SilentlyContinue
                return ($null -ne $wmiLast -and ([int]$wmiLast.ChargeRate -gt 0 -or [bool]$wmiLast.Charging))
            }
        }
        return $true
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

function Get-RuntimeState {
    $model = [ordered]@{
        PriorBrightness       = 20
        InCampusMode          = $false
        PreArmedCampusMode    = 'None'
        LastBedtimePromptDate = ''
        LastBedtimeChoice     = ''
        UpdatedAt             = (Get-Date).ToString('o')
    }
    if (Test-Path $RuntimeState) {
        try {
            $raw = Get-Content $RuntimeState -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $raw.PriorBrightness)       { $model.PriorBrightness       = [int]$raw.PriorBrightness }
            if ($null -ne $raw.InCampusMode)          { $model.InCampusMode          = [bool]$raw.InCampusMode }
            if ($raw.PreArmedCampusMode)              { $model.PreArmedCampusMode    = [string]$raw.PreArmedCampusMode }
            if ($null -ne $raw.LastBedtimePromptDate) { $model.LastBedtimePromptDate = [string]$raw.LastBedtimePromptDate }
            if ($null -ne $raw.LastBedtimeChoice)     { $model.LastBedtimeChoice     = [string]$raw.LastBedtimeChoice }
            if ($raw.UpdatedAt)                       { $model.UpdatedAt             = [string]$raw.UpdatedAt }
        } catch {}
    }
    return [PSCustomObject]$model
}

function Save-RuntimeState {
    param([Parameter(Mandatory = $true)][psobject]$State)
    $State.UpdatedAt = (Get-Date).ToString('o')
    $tmpPath = "$RuntimeState.tmp.$PID"
    $State | ConvertTo-Json -Depth 4 | Set-Content -Path $tmpPath -Encoding UTF8
    Move-Item -LiteralPath $tmpPath -Destination $RuntimeState -Force
}

function Save-PriorBrightnessIfNeeded {
    param([string]$CampusVariant = 'Standard')
    $cur = Get-CurrentBrightness
    $st = Get-RuntimeState
    if (-not $st.InCampusMode) {
        $st.PriorBrightness = $cur
    }
    $st.InCampusMode       = $true
    $st.PreArmedCampusMode = $CampusVariant
    Save-RuntimeState -State $st
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

    Save-PriorBrightnessIfNeeded -CampusVariant $(if ($Ultra) { 'Ultra' } else { 'Standard' })

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
    Write-Host "  -> Đang mở mạch sạc Normal (100%) và kiểm tra công suất nạp thực tế trên WMI SMBus..." -ForegroundColor Gray
    if (Set-BatteryChargeModeSafe -Mode 'Normal' -VerifyChargeRate) {
        $bat = Get-BatteryLiveTelemetry
        Write-Host "  -> Đã chuyển mạch sạc Lenovo sang Normal (100%), RapidCharge = $($bat.IsRapidCharge)." -ForegroundColor Green
        if ($bat.PowerOnline -and $bat.Percent -lt 98) {
            Write-Host "  -> Xác nhận đang nạp điện thực tế: +$($bat.ChargeRateW) W ($($bat.ChargeRateMW) mW | $($bat.CurrentMA) mA)." -ForegroundColor Green
        }
        Write-Host "  -> Pin hiện tại: $($bat.Percent)% ($($bat.RemainingWh) Wh | $($bat.VoltageMV) mV | $($bat.TemperatureC) °C)." -ForegroundColor Cyan
        Write-Host "  -> Lời khuyên: Hãy cắm sạc trước khi đi học 45-60 phút khi máy đang nghỉ mát (không vừa sạc lên 100% vừa chơi game nặng)." -ForegroundColor Yellow
    } else {
        Write-Warning "Không thể xác nhận dòng nạp Normal qua IdeaBatteryAgent.dll / WMI BatteryStatus."
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

    # 3. Restore brightness idempotently (only restore PriorBrightness when exiting active InCampusMode)
    $st = Get-RuntimeState
    $restoreBri = Get-CurrentBrightness
    if ($st.InCampusMode -eq $true -and $null -ne $st.PriorBrightness -and $st.PriorBrightness -ge 0) {
        $restoreBri = [int]$st.PriorBrightness
    }
    $st.InCampusMode       = $false
    $st.PreArmedCampusMode = 'None'
    Save-RuntimeState -State $st

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

# ============================================================================
# 3B. Smart Post-Game Bedtime Reminder (22:15), Pre-Arm DC & Task Management
# ============================================================================

function Get-BedtimeCycleInfo {
    param([datetime]$Now = (Get-Date))
    if ($Now.Hour -ge 0 -and $Now.Hour -lt 4) {
        return [PSCustomObject]@{
            NightCycleDate  = $Now.Date.AddDays(-1).ToString('yyyy-MM-dd')
            MaxWaitDeadline = $Now.Date.AddHours(2)
            IsNightWindow   = $true
        }
    } elseif ($Now.Hour -ge 20) {
        return [PSCustomObject]@{
            NightCycleDate  = $Now.Date.ToString('yyyy-MM-dd')
            MaxWaitDeadline = $Now.Date.AddDays(1).AddHours(2)
            IsNightWindow   = $true
        }
    } else {
        return [PSCustomObject]@{
            NightCycleDate  = $Now.Date.ToString('yyyy-MM-dd')
            MaxWaitDeadline = $Now.Date
            IsNightWindow   = $false
        }
    }
}

function Get-ActiveGameStatus {
    param([string]$SteamRegPath = 'HKCU:\Software\Valve\Steam')
    if (-not [string]::IsNullOrWhiteSpace($SteamRegistryPathOverride)) {
        $SteamRegPath = $SteamRegistryPathOverride
    }

    $reasons = New-Object System.Collections.Generic.List[string]
    $runningAppId = 0

    # 1. Official Valve Steam RunningAppID flag (resets to 0 the instant any Steam game exits)
    if (Test-Path $SteamRegPath) {
        try {
            $steamProps = Get-ItemProperty -Path $SteamRegPath -ErrorAction SilentlyContinue
            if ($null -ne $steamProps -and $null -ne $steamProps.RunningAppID) {
                $candidateId = [int]$steamProps.RunningAppID
                $isOverrideTest = ($SteamRegPath -ne 'HKCU:\Software\Valve\Steam')
                $steamClientAlive = ($null -ne (Get-Process -Name 'steam' -ErrorAction SilentlyContinue))
                if ($candidateId -gt 0 -and ($steamClientAlive -or $isOverrideTest)) {
                    $runningAppId = $candidateId
                    $appName = "SteamApp:$runningAppId"
                    $appKey = Join-Path $SteamRegPath "Apps\$runningAppId"
                    if (Test-Path $appKey) {
                        $appProp = Get-ItemProperty -Path $appKey -ErrorAction SilentlyContinue
                        if ($appProp -and $appProp.Name) { $appName = "$($appProp.Name) (AppID $runningAppId)" }
                    }
                    $reasons.Add($appName)
                }
            }
        } catch {}
    }

    # 2. Standalone / Riot / Anti-Cheat / AAA game process patterns
    $gamePatterns = @(
        'TslGame', 'ExecPubg', 'TslGame_BE', 'TslGame_ZK',
        'cs2', 'valorant*', 'dota2', 'League of Legends',
        'eldenring', 'HalfSword*', 'CombatMaster*', 'StrikersClub*',
        'r5apex*', 'ApexLegends', 'Overwatch', 'FortniteClient*',
        'GenshinImpact', 'StarRail', 'GTA5', 'Cyberpunk2077', 'b1-Win64-Shipping'
    )
    $sysSkip = @{
        'System' = 1; 'Idle' = 1; 'Registry' = 1; 'Memory Compression' = 1; 'Secure System' = 1
        'smss' = 1; 'csrss' = 1; 'wininit' = 1; 'services' = 1; 'lsass' = 1; 'svchost' = 1
        'winlogon' = 1; 'dwm' = 1; 'fontdrvhost' = 1; 'WmiPrvSE' = 1; 'MsMpEng' = 1; 'NisSrv' = 1
        'audiodg' = 1; 'spoolsv' = 1; 'conhost' = 1; 'RuntimeBroker' = 1; 'dllhost' = 1; 'sihost' = 1
        'taskhostw' = 1; 'explorer' = 1; 'SearchHost' = 1; 'StartMenuExperienceHost' = 1
        'powershell' = 1; 'pwsh' = 1; 'cmd' = 1; 'browser' = 1; 'msedgewebview2' = 1
        'node' = 1; 'python' = 1; 'pythonw' = 1; 'rg' = 1; 'Antigravity' = 1; 'language_server_windows_x64' = 1
        'steam' = 1; 'steamwebhelper' = 1; 'steamservice' = 1
    }

    $allProcs = Get-Process -ErrorAction SilentlyContinue
    foreach ($p in $allProcs) {
        $pName = $p.ProcessName
        if ($sysSkip.ContainsKey($pName)) { continue }
        foreach ($pat in $gamePatterns) {
            if ($pName -like $pat) {
                $tag = "Proc:$pName"
                if (-not $reasons.Contains($tag)) { $reasons.Add($tag) }
                break
            }
        }
        # 3. Any game executable running from *\Steam\steamapps\common\*
        try {
            $pPath = $p.Path
            if ($pPath -and ($pPath -like '*\steamapps\common\*')) {
                if ($pPath -notmatch 'Steamworks Shared|crashreporter|CrashHandler|cefprocess|UnityCrashHandler') {
                    $tag = "SteamCommon:$pName"
                    if (-not $reasons.Contains($tag)) { $reasons.Add($tag) }
                }
            }
        } catch {}
    }

    return [PSCustomObject]@{
        IsGameRunning = ($reasons.Count -gt 0)
        SteamAppId    = $runningAppId
        MatchedGames  = @($reasons)
        Summary       = if ($reasons.Count -gt 0) { $reasons -join ', ' } else { 'None' }
    }
}

function Set-PreArmedCampusDcPower {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Standard', 'Ultra', 'None')]
        [string]$Mode
    )

    if ($Mode -in @('Standard', 'Ultra')) {
        $isUltra  = ($Mode -eq 'Ultra')
        $freqCap  = if ($isUltra) { [uint32]1700 } else { [uint32]2400 }
        $eppVal   = if ($isUltra) { [uint32]100 }  else { [uint32]90 }
        $maxCores = if ($isUltra) { [uint32]50 }   else { [uint32]100 }

        # Configure DC-only power settings via native powrprof.dll (< 1 ms) with powercfg fallback, WITHOUT touching AC screen brightness
        if (-not [PcOptNative]::ApplyCampusDcProfileFast($true, $freqCap, $eppVal, $maxCores)) {
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 0
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 75b0ae3f-bce0-45a7-8c89-c9611c25e100 $freqCap
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $eppVal
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 10
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 $maxCores
            powercfg /setdcvalueindex SCHEME_CURRENT 5fb4938d-1ee8-4b0f-9a3c-5036b0ab995c dd848b2a-8a5d-4451-9ae2-39cd41658f6c 1
            powercfg /setdcvalueindex SCHEME_CURRENT de830923-a562-41af-a086-e3a2c6bad2da e69653ca-cf7f-4f05-aa73-cb833fa90ad4 100
            powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3
            powercfg /setdcvalueindex SCHEME_CURRENT 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4 2
            powercfg /setdcvalueindex SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 180
            powercfg /setdcvalueindex SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 600
            powercfg /setactive SCHEME_CURRENT
        }

        if ($isUltra) {
            foreach ($polRoot in @('HKCU:\Software\CocCoc\Browser', 'HKCU:\Software\Policies\CocCoc\Browser', 'HKLM:\SOFTWARE\Policies\CocCoc\Browser')) {
                try {
                    if (-not (Test-Path $polRoot)) { New-Item -Path $polRoot -Force -ErrorAction Stop | Out-Null }
                    New-ItemProperty -Path $polRoot -Name 'HighEfficiencyModeEnabled' -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
                    New-ItemProperty -Path $polRoot -Name 'BatterySaverModeAvailability' -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
                } catch {}
            }
        } else {
            foreach ($polRoot in @('HKCU:\Software\CocCoc\Browser', 'HKCU:\Software\Policies\CocCoc\Browser', 'HKLM:\SOFTWARE\Policies\CocCoc\Browser')) {
                try {
                    if (Test-Path $polRoot) {
                        Remove-ItemProperty -Path $polRoot -Name 'HighEfficiencyModeEnabled' -ErrorAction SilentlyContinue
                        Remove-ItemProperty -Path $polRoot -Name 'BatterySaverModeAvailability' -ErrorAction SilentlyContinue
                    }
                } catch {}
            }
        }
    } else {
        # Home / Storage default DC profile without touching tonight's AC screen brightness
        if (-not [PcOptNative]::ApplyCampusDcProfileFast($false, [uint32]3500, [uint32]60, [uint32]100)) {
            powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 4
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 2
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 75b0ae3f-bce0-45a7-8c89-c9611c25e100 3500
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 60
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 25
            powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 ea062031-0e34-4ff1-9b6d-eb1059334028 100
            powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0
            powercfg /setactive SCHEME_CURRENT
        }

        foreach ($polRoot in @('HKCU:\Software\CocCoc\Browser', 'HKCU:\Software\Policies\CocCoc\Browser', 'HKLM:\SOFTWARE\Policies\CocCoc\Browser')) {
            try {
                if (Test-Path $polRoot) {
                    Remove-ItemProperty -Path $polRoot -Name 'HighEfficiencyModeEnabled' -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $polRoot -Name 'BatterySaverModeAvailability' -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    }
}

function Get-BedtimeReminderTaskStatus {
    $task = Get-ScheduledTask -TaskPath '\' -TaskName 'LegionBedtimeBatteryReminder' -ErrorAction SilentlyContinue
    $info = if ($task) { Get-ScheduledTaskInfo -TaskPath '\' -TaskName 'LegionBedtimeBatteryReminder' -ErrorAction SilentlyContinue } else { $null }
    $rt   = Get-RuntimeState
    return [PSCustomObject]@{
        Exists                = ($null -ne $task)
        State                 = if ($task) { $task.State.ToString() } else { 'NotRegistered' }
        LogonType             = if ($task) { $task.Principal.LogonType.ToString() } else { 'N/A' }
        NextRunTime           = if ($info -and $info.NextRunTime) { $info.NextRunTime } else { $null }
        LastRunTime           = if ($info -and $info.LastRunTime) { $info.LastRunTime } else { $null }
        LastTaskResult        = if ($info) { $info.LastTaskResult } else { $null }
        PreArmedCampusMode    = $rt.PreArmedCampusMode
        LastBedtimePromptDate = $rt.LastBedtimePromptDate
        LastBedtimeChoice     = $rt.LastBedtimeChoice
    }
}

function Register-BedtimeReminderTask {
    $scriptFull = Join-Path $ProjectDir 'CheDoDiHoc_CuuHo.ps1'
    $argStr     = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptFull`" -BedtimePrompt"
    $action     = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argStr
    $trigger    = New-ScheduledTaskTrigger -Daily -At '22:15'
    $settings   = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -DontStopOnIdleEnd `
        -ExecutionTimeLimit (New-TimeSpan -Hours 4) `
        -MultipleInstances IgnoreNew
    $userId     = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { $env:USERNAME }
    $principal  = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited

    $task = Register-ScheduledTask `
        -TaskPath '\' `
        -TaskName 'LegionBedtimeBatteryReminder' `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description 'Nhac chon che do pin di hoc hoac khoa 60% sau khi choi game xong moi toi (22:15)' `
        -Force `
        -ErrorAction Stop
    $null = Enable-ScheduledTask -TaskPath '\' -TaskName 'LegionBedtimeBatteryReminder' -ErrorAction SilentlyContinue
    Write-Host "  -> Đã đăng ký & BẬT lịch nhắc đi ngủ tự động \LegionBedtimeBatteryReminder lúc 22:15 hằng ngày (State=$($task.State), InteractiveToken)." -ForegroundColor Green
    return $true
}

function Disable-BedtimeReminderTask {
    $task = Get-ScheduledTask -TaskPath '\' -TaskName 'LegionBedtimeBatteryReminder' -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Warning "Tác vụ \LegionBedtimeBatteryReminder chưa được đăng ký."
        return $false
    }
    $null = Disable-ScheduledTask -TaskPath '\' -TaskName 'LegionBedtimeBatteryReminder' -ErrorAction Stop
    Write-Host "  -> Đã TẠM TẮT (Disabled) lịch nhắc đi ngủ 22:15 (\LegionBedtimeBatteryReminder)." -ForegroundColor Yellow
    return $true
}

function Invoke-CheckReturnHome {
    $bat = Get-BatteryLiveTelemetry
    $rt  = Get-RuntimeState
    $freq = Get-PowerIndex -Subgroup '54533251-82be-4824-96c1-47b60b740d00' -Setting '75b0ae3f-bce0-45a7-8c89-c9611c25e100'
    $inCampus = Get-InCampusModeState -DCMaxFreqMHz ([int]$freq.DC)

    if (-not $bat) {
        Write-Warning "Không đọc được trạng thái pin từ IdeaBatteryAgent.dll."
        return
    }

    if ($bat.ChargeMode -eq 'Normal') {
        Write-Host "Lưu ý: Máy đang mở sạc 100% từ lần đi học trước. Nếu mai ở nhà, hãy bấm nút [3] để khóa lại 60% chống chai pin!" -ForegroundColor Yellow
    }
    if ($bat.PowerOnline -and ($bat.ChargeMode -eq 'Normal' -or $inCampus -or $rt.PreArmedCampusMode -ne 'None')) {
        Write-Host ("  [Return-Home Check] AC=Online | ChargeMode={0} | Pin={1}% | InCampus={2} | PreArmed={3} -> Khuyến nghị khóa lại Storage 60% (Chế độ [4] Về Nhà hoặc nút [3] lúc 22:15)." -f $bat.ChargeMode, $bat.Percent, $inCampus, $rt.PreArmedCampusMode) -ForegroundColor Cyan
    } else {
        Write-Host ("  [Return-Home Check] An toàn: ChargeMode={0} | Pin={1}% | PreArmed={2}." -f $bat.ChargeMode, $bat.Percent, $rt.PreArmedCampusMode) -ForegroundColor Green
    }
}

function Invoke-BedtimePrompt {
    param([switch]$IsTestMode)

    # Optional test hook to verify ultra-low (< 8 MB) sleeping Working Set from external observer
    if ($SimulateGameWaitMs -gt 0) {
        [PcOptNative]::TrimSelfAndSleep($SimulateGameWaitMs)
    }

    $now   = Get-Date
    $cycle = Get-BedtimeCycleInfo -Now $now
    $rt    = Get-RuntimeState

    if (-not $IsTestMode) {
        # Guard 1: Ignore stale daytime StartWhenAvailable catch-ups (04:00 - 19:59) so it never pops up in morning class
        if (-not $cycle.IsNightWindow) {
            exit 0
        }
        # Guard 2: Once-per-night guard (00:00 - 03:59 belongs to previous evening's night cycle)
        if ($rt.LastBedtimePromptDate -eq $cycle.NightCycleDate) {
            exit 0
        }

        # Smart Game-Exit Wait Loop (22:15 up to 02:00 max wait; 100% invisible & < 8 MB Working Set)
        $waitedForGame = $false
        while ($true) {
            $gameState = Get-ActiveGameStatus
            if (-not $gameState.IsGameRunning) {
                break
            }
            if ((Get-Date) -ge $cycle.MaxWaitDeadline) {
                # Past 02:00 AM while still gaming -> never interrupt mid-game; exit silently
                exit 0
            }
            $waitedForGame = $true
            [PcOptNative]::TrimSelfAndSleep(15000)
        }

        if ($waitedForGame) {
            # Wait 8 seconds after game exit so Steam Cloud sync and GPU mode switch settle cleanly
            [PcOptNative]::TrimSelfAndSleep(8000)
            $recheck = Get-ActiveGameStatus
            if ($recheck.IsGameRunning -and (Get-Date) -ge $cycle.MaxWaitDeadline) {
                exit 0
            }
            while ($recheck.IsGameRunning -and (Get-Date) -lt $cycle.MaxWaitDeadline) {
                [PcOptNative]::TrimSelfAndSleep(15000)
                $recheck = Get-ActiveGameStatus
            }
            if ($recheck.IsGameRunning) { exit 0 }
        }
    }

    $initialGameCheck = Get-ActiveGameStatus
    $bat = Get-BatteryLiveTelemetry -SkipWmiRates
    $batPct        = if ($bat) { $bat.Percent } else { 60 }
    $batWh         = if ($bat) { "$($bat.RemainingWh) / $($bat.FullCapWh) Wh" } else { "N/A" }
    $batTemp       = if ($bat) { "$($bat.TemperatureC)°C" } else { "N/A" }
    $chargeModeRaw = if ($bat) { $bat.ChargeMode } else { 'Storage' }
    $chargeLabel   = if ($chargeModeRaw -eq 'Normal') { 'Normal 100% (Đang mở sạc đầy)' } else { 'Storage 60% (Khóa chống chai 55-60%)' }
    $acLabel       = if ($bat -and $bat.PowerOnline) { 'Đang cắm sạc AC' } else { 'Đang dùng Pin DC' }

    # Enable crisp native DPI rendering on 2560x1600 (150% scaling) before creating WinForms controls
    $null = [PcOptNative]::SetProcessDPIAware()
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $gScreen = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    $dpiScale = $gScreen.DpiX / 96.0
    $gScreen.Dispose()
    if ($dpiScale -lt 1.0) { $dpiScale = 1.0 }
    $S = { param([double]$px) [int][math]::Round($px * $dpiScale) }

    $bgDark       = [System.Drawing.Color]::FromArgb(15, 23, 42)    # #0F172A
    $bgCard       = [System.Drawing.Color]::FromArgb(30, 41, 59)    # #1E293B
    $accentCyan   = [System.Drawing.Color]::FromArgb(56, 189, 248)  # #38BDF8
    $textPrimary  = [System.Drawing.Color]::FromArgb(248, 250, 252) # #F8FAFC
    $textMuted    = [System.Drawing.Color]::FromArgb(148, 163, 184) # #94A3B8

    $btn1Bg       = [System.Drawing.Color]::FromArgb(12, 74, 110)   # #0C4A6E
    $btn1Hover    = [System.Drawing.Color]::FromArgb(3, 105, 161)   # #0369A1
    $btn1Border   = [System.Drawing.Color]::FromArgb(56, 189, 248)  # #38BDF8

    $btn2Bg       = [System.Drawing.Color]::FromArgb(49, 46, 129)   # #312E81
    $btn2Hover    = [System.Drawing.Color]::FromArgb(67, 56, 202)   # #4338CA
    $btn2Border   = [System.Drawing.Color]::FromArgb(129, 140, 248) # #818CF8

    $btn3Bg       = [System.Drawing.Color]::FromArgb(6, 78, 59)     # #064E3B
    $btn3Hover    = [System.Drawing.Color]::FromArgb(4, 120, 87)    # #047857
    $btn3Border   = [System.Drawing.Color]::FromArgb(52, 211, 153)  # #34D399

    $warnBg       = [System.Drawing.Color]::FromArgb(69, 26, 3)     # #451A03
    $warnText     = [System.Drawing.Color]::FromArgb(253, 230, 138) # #FDE68A
    $safeBg       = [System.Drawing.Color]::FromArgb(6, 58, 46)
    $safeText     = [System.Drawing.Color]::FromArgb(167, 243, 208) # #A7F3D0

    $fontTitle    = New-Object System.Drawing.Font('Segoe UI', 14.5, [System.Drawing.FontStyle]::Bold)
    $fontSub      = New-Object System.Drawing.Font('Segoe UI', 9.5,  [System.Drawing.FontStyle]::Regular)
    $fontTelem    = New-Object System.Drawing.Font('Segoe UI', 9.5,  [System.Drawing.FontStyle]::Bold)
    $fontBanner   = New-Object System.Drawing.Font('Segoe UI', 9.5,  [System.Drawing.FontStyle]::Bold)
    $fontBtn      = New-Object System.Drawing.Font('Segoe UI', 10.0, [System.Drawing.FontStyle]::Bold)
    $fontTimer    = New-Object System.Drawing.Font('Segoe UI', 10.0, [System.Drawing.FontStyle]::Bold)

    $cardWidth = & $S 768
    $padX      = & $S 24
    $innerW    = $cardWidth - (2 * $padX)
    $curY      = 0

    $form = New-Object System.Windows.Forms.Form
    $form.Text            = 'Legion 5 Pro - Nhắc Chế Độ Pin Ngày Mai (22:15)'
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $form.MaximizeBox     = $false
    $form.MinimizeBox     = $false
    $form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost         = $true
    $form.KeyPreview      = $true
    $form.BackColor       = $bgDark
    $form.ForeColor       = $textPrimary
    $form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::None

    # Top accent bar
    $topBar = New-Object System.Windows.Forms.Panel
    $topBar.Location  = New-Object System.Drawing.Point(0, 0)
    $topBar.Size      = New-Object System.Drawing.Size($cardWidth, (& $S 5))
    $topBar.BackColor = $accentCyan
    $form.Controls.Add($topBar)
    $curY += (& $S 18)

    # Header Title
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.UseMnemonic = $false
    $lblTitle.Location    = New-Object System.Drawing.Point($padX, $curY)
    $lblTitle.Size        = New-Object System.Drawing.Size($innerW, (& $S 34))
    $lblTitle.Font        = $fontTitle
    $lblTitle.ForeColor   = $textPrimary
    $lblTitle.Text        = 'Chế Độ Pin Cho Ngày Mai — Lenovo Legion 5 Pro'
    $form.Controls.Add($lblTitle)
    $curY += $lblTitle.Height + (& $S 2)

    # Subtitle
    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.UseMnemonic = $false
    $lblSub.Location    = New-Object System.Drawing.Point($padX, $curY)
    $lblSub.Size        = New-Object System.Drawing.Size($innerW, (& $S 24))
    $lblSub.Font        = $fontSub
    $lblSub.ForeColor   = $textMuted
    $lblSub.Text        = 'Chọn 1 chạm trước khi ngủ • Máy tự sạc êm lên 100% kể cả khi bạn Shutdown máy ngay sau đó.'
    $form.Controls.Add($lblSub)
    $curY += $lblSub.Height + (& $S 12)

    # Live Telemetry Strip
    $pnlTelem = New-Object System.Windows.Forms.Panel
    $pnlTelem.Location  = New-Object System.Drawing.Point($padX, $curY)
    $pnlTelem.Size      = New-Object System.Drawing.Size($innerW, (& $S 40))
    $pnlTelem.BackColor = $bgCard

    $lblTelem = New-Object System.Windows.Forms.Label
    $lblTelem.UseMnemonic = $false
    $lblTelem.Location    = New-Object System.Drawing.Point((& $S 12), 0)
    $lblTelem.Size        = New-Object System.Drawing.Size(($innerW - (& $S 24)), (& $S 40))
    $lblTelem.TextAlign   = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblTelem.Font        = $fontTelem
    $lblTelem.ForeColor   = $accentCyan
    $lblTelem.Text        = "Pin hiện tại: ${batPct}% (${batWh})  |  Mạch sạc: ${chargeLabel}  |  ${acLabel} (${batTemp})"
    $pnlTelem.Controls.Add($lblTelem)
    $form.Controls.Add($pnlTelem)
    $curY += $pnlTelem.Height + (& $S 10)

    # Return-Home / Charge Mode Safety Banner
    $pnlBanner = New-Object System.Windows.Forms.Panel
    $pnlBanner.Location  = New-Object System.Drawing.Point($padX, $curY)
    $pnlBanner.Size      = New-Object System.Drawing.Size($innerW, (& $S 48))
    $lblBanner = New-Object System.Windows.Forms.Label
    $lblBanner.UseMnemonic = $false
    $lblBanner.Location    = New-Object System.Drawing.Point((& $S 12), (& $S 4))
    $lblBanner.Size        = New-Object System.Drawing.Size(($innerW - (& $S 24)), (& $S 40))
    $lblBanner.TextAlign   = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblBanner.Font        = $fontBanner

    if ($chargeModeRaw -eq 'Normal') {
        $pnlBanner.BackColor = $warnBg
        $lblBanner.ForeColor = $warnText
        $lblBanner.Text      = 'Lưu ý: Máy đang mở sạc 100% từ lần đi học trước. Nếu mai ở nhà, hãy bấm nút [3] để khóa lại 60% chống chai pin!'
    } else {
        $pnlBanner.BackColor = $safeBg
        $lblBanner.ForeColor = $safeText
        $lblBanner.Text      = 'Đang khóa bảo vệ pin 60% (Storage Mode). Nếu sáng mai đi học, hãy bấm [1] hoặc [2] để sạc đầy 100% đêm nay.'
    }
    $pnlBanner.Controls.Add($lblBanner)
    $form.Controls.Add($pnlBanner)
    $curY += $pnlBanner.Height + (& $S 14)

    # Helper to build big sleek 1-click buttons
    $NewModeButton = {
        param([string]$Text, [int]$YPos, [System.Drawing.Color]$Bg, [System.Drawing.Color]$Hover, [System.Drawing.Color]$Border)
        $b = New-Object System.Windows.Forms.Button
        $b.UseMnemonic = $false
        $b.Location    = New-Object System.Drawing.Point($padX, $YPos)
        $b.Size        = New-Object System.Drawing.Size($innerW, (& $S 64))
        $b.FlatStyle   = [System.Windows.Forms.FlatStyle]::Flat
        $b.FlatAppearance.BorderSize         = 2
        $b.FlatAppearance.BorderColor        = $Border
        $b.FlatAppearance.MouseOverBackColor = $Hover
        $b.BackColor   = $Bg
        $b.ForeColor   = $textPrimary
        $b.Font        = $fontBtn
        $b.TextAlign   = [System.Drawing.ContentAlignment]::MiddleLeft
        $b.Padding     = New-Object System.Windows.Forms.Padding((& $S 14), 0, (& $S 10), 0)
        $b.Cursor      = [System.Windows.Forms.Cursors]::Hand
        $b.Text        = $Text
        return $b
    }

    $btn1 = & $NewModeButton `
        "[1] Mai Đi Học — Tiêu Chuẩn (Sạc đầy 100% + Cài sẵn Đi Học 6-7h)`r`n      Mở sạc êm 100% • Cài sẵn DC 2.4GHz, tắt Boost trên pin • Giữ nguyên độ sáng tối nay" `
        $curY $btn1Bg $btn1Hover $btn1Border
    $form.Controls.Add($btn1)
    $curY += $btn1.Height + (& $S 10)

    $btn2 = & $NewModeButton `
        "[2] Mai Đi Học — Siêu Trâu 8h+ (Sạc đầy 100% + Cài sẵn Siêu Trâu)`r`n      Mở sạc êm 100% • Cài sẵn DC 4 nhân 1.7GHz + Cốc Cốc Saver • Giữ nguyên độ sáng tối nay" `
        $curY $btn2Bg $btn2Hover $btn2Border
    $form.Controls.Add($btn2)
    $curY += $btn2.Height + (& $S 10)

    $btn3 = & $NewModeButton `
        "[3] Mai Ở Nhà / Không Đi Học (Giữ Khóa Pin 60% Chống Chai)`r`n      Mặc định khi hết giờ / nhấn phím Esc • Giữ khóa mạch sạc Storage 55%-60% chống chai pin" `
        $curY $btn3Bg $btn3Hover $btn3Border
    $form.Controls.Add($btn3)
    $curY += $btn3.Height + (& $S 14)

    # Footer row: shortcuts + live 120s countdown
    $lblHint = New-Object System.Windows.Forms.Label
    $lblHint.UseMnemonic = $false
    $lblHint.Location    = New-Object System.Drawing.Point($padX, $curY)
    $lblHint.Size        = New-Object System.Drawing.Size(([int]($innerW * 0.55)), (& $S 26))
    $lblHint.TextAlign   = [System.Drawing.ContentAlignment]::MiddleLeft
    $lblHint.Font        = $fontSub
    $lblHint.ForeColor   = $textMuted
    $lblHint.Text        = 'Phím tắt: [1]  [2]  [3]  hoặc  [Esc]'
    $form.Controls.Add($lblHint)

    $lblCountdown = New-Object System.Windows.Forms.Label
    $lblCountdown.UseMnemonic = $false
    $lblCountdown.Location    = New-Object System.Drawing.Point(($padX + [int]($innerW * 0.55)), $curY)
    $lblCountdown.Size        = New-Object System.Drawing.Size(($innerW - [int]($innerW * 0.55)), (& $S 26))
    $lblCountdown.TextAlign   = [System.Drawing.ContentAlignment]::MiddleRight
    $lblCountdown.Font        = $fontTimer
    $lblCountdown.ForeColor   = [System.Drawing.Color]::FromArgb(251, 191, 36)
    $lblCountdown.Text        = 'Tự đóng sau 120s... (Mặc định [3])'
    $form.Controls.Add($lblCountdown)
    $curY += $lblCountdown.Height + (& $S 18)

    $form.ClientSize = New-Object System.Drawing.Size($cardWidth, $curY)

    # State inside form closure
    $uiState = @{
        SecondsLeft          = 120
        SelectionMade        = $false
        SelectedOption       = ''
        ConfirmMessage       = ''
        VerifiedPostMode     = $chargeModeRaw
        VerifiedChargeRateMW = 0
    }

    $countdownTimer = New-Object System.Windows.Forms.Timer
    $countdownTimer.Interval = 1000

    $closeTimer = New-Object System.Windows.Forms.Timer
    $closeTimer.Interval = if ([string]::IsNullOrEmpty($AutoSelectForTest)) { 2500 } else { 25 }

    $ApplySelection = {
        param([string]$ChoiceKey)
        if ($uiState.SelectionMade) { return }
        $uiState.SelectionMade  = $true
        $uiState.SelectedOption = $ChoiceKey
        $countdownTimer.Stop()

        # Visually highlight active button while dimming non-selected buttons cleanly (keeping crisp white/slate text)
        $dimColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
        $btn1.ForeColor = if ($ChoiceKey -eq '1') { $textPrimary } else { $dimColor }
        $btn2.ForeColor = if ($ChoiceKey -eq '2') { $textPrimary } else { $dimColor }
        $btn3.ForeColor = if ($ChoiceKey -notin @('1', '2')) { $textPrimary } else { $dimColor }

        if ($ChoiceKey -in @('1', '2')) {
            $lblBanner.Text = 'Đang mở khóa sạc 100% và xác nhận dòng nạp phần cứng...'
            $lblCountdown.Text = 'Đang kiểm tra WMI...'
            $form.Refresh()
        }

        $stNow = Get-RuntimeState
        switch ($ChoiceKey) {
            '1' {
                if (Set-BatteryChargeModeSafe -Mode 'Normal' -VerifyChargeRate -PumpUiEvents) { $uiState.VerifiedPostMode = 'Normal' }
                $uiState.VerifiedChargeRateMW = [int]$script:LastVerifiedChargeRateMW
                Set-PreArmedCampusDcPower -Mode 'Standard'
                $stNow.PreArmedCampusMode = 'Standard'
                $stNow.LastBedtimeChoice  = '1_Standard'
                $wattTag = if ($uiState.VerifiedChargeRateMW -gt 0) { " (+$([math]::Round($uiState.VerifiedChargeRateMW / 1000.0, 1)) W)" } else { '' }
                $uiState.ConfirmMessage   = "Đã bật sạc êm 100%${wattTag} + Cài sẵn Đi Học Tiêu Chuẩn (DC 2.4GHz) cho sáng mai!"
            }
            '2' {
                if (Set-BatteryChargeModeSafe -Mode 'Normal' -VerifyChargeRate -PumpUiEvents) { $uiState.VerifiedPostMode = 'Normal' }
                $uiState.VerifiedChargeRateMW = [int]$script:LastVerifiedChargeRateMW
                Set-PreArmedCampusDcPower -Mode 'Ultra'
                $stNow.PreArmedCampusMode = 'Ultra'
                $stNow.LastBedtimeChoice  = '2_Ultra'
                $wattTag = if ($uiState.VerifiedChargeRateMW -gt 0) { " (+$([math]::Round($uiState.VerifiedChargeRateMW / 1000.0, 1)) W)" } else { '' }
                $uiState.ConfirmMessage   = "Đã bật sạc êm 100%${wattTag} + Cài sẵn Đi Học Siêu Trâu 8h+ (DC 4 nhân 1.7GHz)!"
            }
            default {
                if (Set-BatteryChargeModeSafe -Mode 'Storage') { $uiState.VerifiedPostMode = 'Storage' }
                Set-PreArmedCampusDcPower -Mode 'None'
                $stNow.PreArmedCampusMode = 'None'
                $stNow.InCampusMode       = $false
                $stNow.LastBedtimeChoice  = if ($ChoiceKey -eq 'Timeout') { 'Timeout_HomeStorage' } else { '3_HomeStorage' }
                $uiState.ConfirmMessage   = 'Đã khóa bảo vệ pin 60% (Storage Mode) chống chai pin cho ngày mai ở nhà!'
            }
        }

        if (-not $IsTestMode) {
            $stNow.LastBedtimePromptDate = $cycle.NightCycleDate
        }
        Save-RuntimeState -State $stNow

        $pnlBanner.BackColor    = [System.Drawing.Color]::FromArgb(6, 95, 70)
        $lblBanner.ForeColor    = [System.Drawing.Color]::FromArgb(236, 253, 245)
        $lblBanner.Text         = "HOÀN TẤT: $($uiState.ConfirmMessage)"
        $lblCountdown.ForeColor = [System.Drawing.Color]::FromArgb(52, 211, 153)
        $lblCountdown.Text      = 'Đang lưu & tự đóng...'
        $form.Refresh()

        if (-not [string]::IsNullOrWhiteSpace($CaptureGuiScreenshot) -and ($CaptureGuiScreenshot -notmatch 'preclick')) {
            try {
                $bmp = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
                $form.DrawToBitmap($bmp, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
                $bmp.Save($CaptureGuiScreenshot, [System.Drawing.Imaging.ImageFormat]::Png)
                $bmp.Dispose()
            } catch {}
        }

        $closeTimer.Start()
    }

    $btn1.Add_Click({ & $ApplySelection '1' })
    $btn2.Add_Click({ & $ApplySelection '2' })
    $btn3.Add_Click({ & $ApplySelection '3' })

    $form.Add_KeyDown({
        param($sender, $e)
        if ($uiState.SelectionMade) { return }
        switch ($e.KeyCode) {
            'D1'      { & $ApplySelection '1' }
            'NumPad1' { & $ApplySelection '1' }
            'D2'      { & $ApplySelection '2' }
            'NumPad2' { & $ApplySelection '2' }
            'D3'      { & $ApplySelection '3' }
            'NumPad3' { & $ApplySelection '3' }
            'Escape'  { & $ApplySelection '3' }
        }
    })

    $countdownTimer.Add_Tick({
        if ($uiState.SelectionMade) { return }
        $uiState.SecondsLeft--
        if ($uiState.SecondsLeft -le 0) {
            & $ApplySelection 'Timeout'
        } else {
            $lblCountdown.Text = "Tự đóng sau $($uiState.SecondsLeft)s... (Mặc định [3])"
        }
    })

    $closeTimer.Add_Tick({
        $closeTimer.Stop()
        $form.Close()
    })

    $autoTestTimer = $null
    if (-not [string]::IsNullOrEmpty($AutoSelectForTest)) {
        $autoTestTimer = New-Object System.Windows.Forms.Timer
        $autoTestTimer.Interval = 40
        $autoTestTimer.Add_Tick({
            $autoTestTimer.Stop()
            if (-not [string]::IsNullOrWhiteSpace($CaptureGuiScreenshot) -and ($CaptureGuiScreenshot -match 'preclick')) {
                try {
                    $form.Refresh()
                    $bmpPre = New-Object System.Drawing.Bitmap($form.Width, $form.Height)
                    $form.DrawToBitmap($bmpPre, (New-Object System.Drawing.Rectangle(0, 0, $form.Width, $form.Height)))
                    $bmpPre.Save($CaptureGuiScreenshot, [System.Drawing.Imaging.ImageFormat]::Png)
                    $bmpPre.Dispose()
                } catch {}
            }
            switch ($AutoSelectForTest) {
                '1'       { $btn1.PerformClick() }
                '2'       { $btn2.PerformClick() }
                '3'       { $btn3.PerformClick() }
                'Timeout' { & $ApplySelection 'Timeout' }
            }
        })
    }

    $form.Add_Shown({
        $form.Activate()
        $btn3.Focus()
        $countdownTimer.Start()
        if ($null -ne $autoTestTimer) {
            $autoTestTimer.Start()
        }
    })

    $form.Add_FormClosing({
        param($sender, $e)
        $countdownTimer.Stop()
        $closeTimer.Stop()
        if ($null -ne $autoTestTimer) { $autoTestTimer.Stop() }
        # Never block Windows shutdown or Task Manager close; if user clicked X manually without choosing, lock safe Storage 60%
        if (-not $uiState.SelectionMade -and
            $e.CloseReason -ne [System.Windows.Forms.CloseReason]::WindowsShutDown -and
            $e.CloseReason -ne [System.Windows.Forms.CloseReason]::TaskManagerClosing) {
            $uiState.SelectionMade  = $true
            $uiState.SelectedOption = 'Close_Default3'
            $null = Set-BatteryChargeModeSafe -Mode 'Storage'
            Set-PreArmedCampusDcPower -Mode 'None'
            $stClose = Get-RuntimeState
            $stClose.PreArmedCampusMode = 'None'
            $stClose.InCampusMode       = $false
            $stClose.LastBedtimeChoice  = '3_HomeStorage'
            if (-not $IsTestMode) { $stClose.LastBedtimePromptDate = $cycle.NightCycleDate }
            Save-RuntimeState -State $stClose
        }
    })

    [void]$form.ShowDialog()

    $postRt  = Get-RuntimeState
    $resultSummary = [PSCustomObject]@{
        Mode                 = if ($IsTestMode) { 'TestBedtimePrompt' } else { 'BedtimePrompt' }
        NightCycleDate       = $cycle.NightCycleDate
        InitialChargeMode    = $chargeModeRaw
        ReturnHomeBanner     = ($chargeModeRaw -eq 'Normal')
        GameCheckRunning     = $initialGameCheck.IsGameRunning
        GameCheckSummary     = $initialGameCheck.Summary
        SelectedOption       = $uiState.SelectedOption
        PostChargeMode       = $uiState.VerifiedPostMode
        VerifiedChargeRateMW = [int]$uiState.VerifiedChargeRateMW
        IsExpressCharging    = if ($bat) { [bool]$bat.IsRapidCharge } else { $false }
        PreArmedCampusMode   = $postRt.PreArmedCampusMode
    }

    $fontTitle.Dispose(); $fontSub.Dispose(); $fontTelem.Dispose()
    $fontBanner.Dispose(); $fontBtn.Dispose(); $fontTimer.Dispose()
    $form.Dispose()

    Write-Output ("BEDTIME_PROMPT_RESULT=" + ($resultSummary | ConvertTo-Json -Compress))
}

function Invoke-BedtimeScheduleMenu {
    while ($true) {
        $ts = Get-BedtimeReminderTaskStatus
        Write-Host "`n======================================================================" -ForegroundColor Cyan
        Write-Host "   QUẢN LÝ LỊCH NHẮC ĐI NGỦ TỰ ĐỘNG 22:15 (\LegionBedtimeBatteryReminder)" -ForegroundColor Yellow
        Write-Host "======================================================================" -ForegroundColor Cyan
        $stateColor = if ($ts.State -eq 'Ready' -or $ts.State -eq 'Running') { 'Green' } else { 'Yellow' }
        Write-Host ("  * Trạng thái lịch 22:15    : {0} (LogonType={1})" -f $ts.State, $ts.LogonType) -ForegroundColor $stateColor
        Write-Host ("  * Lần chạy kế tiếp         : {0}" -f $(if ($ts.NextRunTime) { $ts.NextRunTime } else { 'N/A' }))
        Write-Host ("  * Đêm nhắc gần nhất        : {0} (Lựa chọn: {1})" -f $(if ($ts.LastBedtimePromptDate) { $ts.LastBedtimePromptDate } else { 'Chưa chạy' }), $(if ($ts.LastBedtimeChoice) { $ts.LastBedtimeChoice } else { 'N/A' }))
        Write-Host ("  * Chế độ cài sẵn sáng mai  : PreArmedCampusMode = {0}" -f $ts.PreArmedCampusMode) -ForegroundColor Cyan
        Write-Host "  * Cơ chế chống làm phiền   : Tự động chờ thoát sạch game Steam (RunningAppID=0) & PUBG + 8s đồng bộ rồi mới hiện bảng." -ForegroundColor Gray
        Write-Host ""
        Write-Host "    [1] Xem thử & Test ngay bảng nhắc đi ngủ (-TestBedtimePrompt)"
        Write-Host "    [2] BẬT / Đăng ký lại lịch tự động 22:15 mỗi tối"
        Write-Host "    [3] TẠM TẮT lịch nhắc 22:15 (Disable Task)"
        Write-Host "    [0] Quay lại Menu chính"
        Write-Host ""
        $sub = Read-Host "  Nhập lựa chọn [0-3]"
        switch ($sub.Trim()) {
            '1' { Invoke-BedtimePrompt -IsTestMode }
            '2' { $null = Register-BedtimeReminderTask; Pause }
            '3' { $null = Disable-BedtimeReminderTask; Pause }
            '0' { return }
            default { Write-Host "  Lựa chọn không hợp lệ." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Get-InCampusModeState {
    param([int]$DCMaxFreqMHz = 3500)
    $st = Get-RuntimeState
    $inCampus = [bool]$st.InCampusMode
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
            Text  = "-> [Ở NHÀ - CHỐNG CHAI PIN]: Máy đã bật Khóa sạc 60% (Storage), nhưng pin đang ở ${BatteryPercent}% (> 65%). Bạn nên RÚT SẠC dùng cho pin hạ xuống 58%-60% một lần rồi cắm sạc lại để pin nghỉ ở ~3.95V/cell khi chơi game nóng!"
        })
    }

    if ($ACLineStatus -eq 1 -and ($InCampusMode -or $ChargeMode -eq 'Normal')) {
        $tips.Add([PSCustomObject]@{
            Case  = 'B'
            Color = 'Magenta'
            Text  = "-> [MỚI ĐI HỌC VỀ / ĐANG MỞ SẠC 100%]: Nếu hôm nay đã đi học xong (hoặc mai ở nhà), hãy bấm phím [4] (Về Nhà) để khóa lại bảo vệ pin 60% (Storage), khôi phục độ sáng màn hình và bật lại bảo vệ Wi-Fi PUBG!"
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
            Text  = "-> [LỊCH TỰ ĐỘNG 22:15]: Tối nay lúc 22:15 (sau khi thoát game), máy sẽ tự hiện bảng hỏi chọn [1]/[2] để sạc đầy 100% cho sáng mai đi học hoặc [3] giữ khóa 60%."
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
    $bedTask = Get-BedtimeReminderTaskStatus
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
        $acStr    = if ($bat.PowerOnline) {
            if ($bat.ChargeRateW -gt 0) {
                "Đang cắm sạc AC (Đang nạp +$($bat.ChargeRateW) W | $($bat.CurrentMA) mA)"
            } else {
                "Đang cắm sạc AC (Ngắt dòng sạc 0.0 W)"
            }
        } else {
            "Đang dùng Pin DC (Xả $($bat.DischargeRateW) W)"
        }
        Write-Host ("  [Pin & Nhiệt độ]  : {0}% ({1} Wh / {2} Wh) | {3} mV ({4} V/cell) | Nhiệt độ: {5} °C" -f $bat.Percent, $bat.RemainingWh, $bat.FullCapWh, $bat.VoltageMV, $bat.CellVoltageV, $bat.TemperatureC) -ForegroundColor Green
        Write-Host ("  [Chế độ Sạc]      : {0} | Sạc nhanh: {1} | Chu kỳ: {2} ({3}% Sức khỏe) | {4}" -f $modeDesc, $bat.IsRapidCharge, $bat.CycleCount, $bat.HealthPct, $acStr) -ForegroundColor Green
    }
    Write-Host ("  [Đồ họa MUX/GPU]  : Hybrid Mode = {0} | RTX 3060: {1} ({2})" -f $(if ($gpu.HybridModeOn) { "BẬT (Tiết kiệm pin)" } else { "TẮT (dGPU-Only)" }), $gpu.RtxState, $gpu.RtxPower) -ForegroundColor Cyan
    Write-Host ("  [Cấu hình Nguồn]  : AC Boost={0} | DC Boost={1} | DC MaxFreq={2} MHz | DC MaxCores={3}% | DC Wi-Fi={4} | InCampusMode={5}" -f $boost.AC, $boost.DC, $freq.DC, $cores.DC, $wifi.DC, $inCampus)
    Write-Host ("  [Màn hình & PUBG] : 2560x1600 @ 60Hz | Độ sáng: {0}% | PUBGWirelessGuard: {1}" -f $bri, $guard.State)
    Write-Host ("  [Nhắc Đi Ngủ]     : \LegionBedtimeBatteryReminder (22:15) = {0} | Cài sẵn mai đi học (PreArmed) = {1}" -f $bedTask.State, $bedTask.PreArmedCampusMode) -ForegroundColor Cyan
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
if ($RegisterBedtimeTask) {
    $null = Register-BedtimeReminderTask
    exit 0
}
if ($DisableBedtimeTask) {
    $null = Disable-BedtimeReminderTask
    exit 0
}
if ($BedtimeTaskStatus) {
    Get-BedtimeReminderTaskStatus | ConvertTo-Json -Depth 4
    exit 0
}
if ($CheckReturnHome) {
    Invoke-CheckReturnHome
    exit 0
}
if ($TestBedtimePrompt) {
    Invoke-BedtimePrompt -IsTestMode
    exit 0
}
if ($BedtimePrompt) {
    Invoke-BedtimePrompt
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
    Write-Host "  CHỌN CHẾ ĐỘ (Nhập số từ 1 đến 7 hoặc 0 để thoát):" -ForegroundColor Yellow
    Write-Host "    [1] Đi Học Tiêu Chuẩn (Tắt Boost trên pin, 2.4GHz, sáng 20%, tạm dừng PUBG Wi-Fi Guard, xả RAM)"
    Write-Host "    [2] Đi Học Siêu Trâu 8h-9.5h (Ép 4 nhân 1.7GHz, tắt đèn phím & Search, sáng 12%, Cốc Cốc Saver)"
    Write-Host "    [3] Chuẩn Bị Đi Học: Nạp Đầy 100% Mát Máy (Mở khóa 100% Normal Mode, tắt sạc nhanh)"
    Write-Host "    [4] Về Nhà / Cắm Sạc Chơi Game (Bật khóa bảo vệ pin 60% Storage, khôi phục PUBG Guard & độ sáng)"
    Write-Host "    [5] Cứu Hộ Xả RAM Tức Thì < 2 Giây (Đóng bloat ngầm + EcoQoS + thu hồi RAM, giữ nguyên nguồn)"
    Write-Host "    [6] Xem / Bật-Tắt Lịch Nhắc Đi Ngủ 22:15 (Tự chờ thoát game Steam/PUBG -> hỏi sạc 100% sáng mai)"
    Write-Host "    [7] Khôi Phục Cài Đặt Gốc Ban Đầu (Undo Baseline)"
    Write-Host "    [0] Thoát"
    Write-Host ""
    $choice = Read-Host "  Nhập lựa chọn của bạn [0-7]"
    switch ($choice.Trim()) {
        '1' { Invoke-CheDoDiHoc; Pause }
        '2' { Invoke-CheDoDiHoc -Ultra; Pause }
        '3' { Invoke-SacDay100; Pause }
        '4' { Invoke-VeNha; Pause }
        '5' { Invoke-CuuHoRAM; Pause }
        '6' { Invoke-BedtimeScheduleMenu }
        '7' {
            $baselineScript = Join-Path $ProjectDir "baseline_setup.ps1"
            if (Test-Path $baselineScript) { & $baselineScript -Undo }
            Pause
        }
        '0' { break }
        default { Write-Host "  Lựa chọn không hợp lệ, vui lòng nhập từ 0 đến 7." -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}

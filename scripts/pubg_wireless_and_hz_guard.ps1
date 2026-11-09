$ErrorActionPreference = "SilentlyContinue"

$mutexName = "Local\PUBGWirelessAndHzGuard_Mutex"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    exit 0
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) { $scriptDir = "C:\tools\goodbyedpi-0.2.3rc3-2" }
$guardLogPath = Join-Path $scriptDir "pubg_wireless_guard.log"

function Write-GuardLog {
    param([string]$Message)
    if (-not $Message) { return }
    try {
        $stamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
        $line = "[$stamp] [PID=$PID] $Message`r`n"
        $utf8Bom = New-Object System.Text.UTF8Encoding($true)
        if ([System.IO.File]::Exists($guardLogPath)) {
            $fi = New-Object System.IO.FileInfo($guardLogPath)
            if ($fi.Length -gt 65536) {
                $tail = [System.IO.File]::ReadAllLines($guardLogPath, $utf8Bom)
                if ($tail.Length -gt 80) {
                    $tail = $tail[($tail.Length - 80)..($tail.Length - 1)]
                }
                [System.IO.File]::WriteAllLines($guardLogPath, $tail, $utf8Bom)
            }
        }
        [System.IO.File]::AppendAllText($guardLogPath, $line, $utf8Bom)
    } catch {}
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class PubgNativeGuard {
    [StructLayout(LayoutKind.Sequential)]
    public struct SYSTEM_POWER_STATUS {
        public byte ACLineStatus;
        public byte BatteryFlag;
        public byte BatteryLifePercent;
        public byte SystemStatusFlag;
        public int BatteryLifeTime;
        public int BatteryFullLifeTime;
    }

    [DllImport("wlanapi.dll")]
    public static extern uint WlanOpenHandle(uint dwClientVersion, IntPtr pReserved, out uint pdwNegotiatedVersion, out IntPtr phClientHandle);

    [DllImport("wlanapi.dll")]
    public static extern uint WlanCloseHandle(IntPtr hClientHandle, IntPtr pReserved);

    [DllImport("wlanapi.dll")]
    public static extern uint WlanEnumInterfaces(IntPtr hClientHandle, IntPtr pReserved, out IntPtr ppInterfaceList);

    [DllImport("wlanapi.dll")]
    public static extern void WlanFreeMemory(IntPtr pMemory);

    [DllImport("wlanapi.dll")]
    public static extern uint WlanSetInterface(IntPtr hClientHandle, ref Guid pInterfaceGuid, uint OpCode, uint dwDataSize, ref int pData, IntPtr pReserved);

    [DllImport("psapi.dll", SetLastError = true)]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);

    [DllImport("kernel32.dll")]
    public static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetSystemPowerStatus(out SYSTEM_POWER_STATUS lpSystemPowerStatus);

    public static void TrimCurrentProcessWorkingSet() {
        try {
            EmptyWorkingSet(GetCurrentProcess());
        } catch {}
    }

    public static bool IsOnBatteryPower() {
        SYSTEM_POWER_STATUS sps;
        if (GetSystemPowerStatus(out sps)) {
            return sps.ACLineStatus == 0;
        }
        return false;
    }

    public static void SetWlanLowLatency(IntPtr hClient, bool enable) {
        if (hClient == IntPtr.Zero) return;
        IntPtr pList;
        if (WlanEnumInterfaces(hClient, IntPtr.Zero, out pList) != 0) return;
        try {
            int count = Marshal.ReadInt32(pList, 0);
            for (int i = 0; i < count; i++) {
                IntPtr itemPtr = new IntPtr(pList.ToInt64() + 8 + (i * 532));
                byte[] guidBytes = new byte[16];
                Marshal.Copy(itemPtr, guidBytes, 0, 16);
                Guid g = new Guid(guidBytes);
                int bgScan = enable ? 0 : 1;
                int mediaStreaming = enable ? 1 : 0;
                WlanSetInterface(hClient, ref g, 2, 4, ref bgScan, IntPtr.Zero);
                WlanSetInterface(hClient, ref g, 3, 4, ref mediaStreaming, IntPtr.Zero);
            }
        } finally {
            WlanFreeMemory(pList);
        }
    }

    public static void AssertLowLatencyWlan(IntPtr hClient) {
        SetWlanLowLatency(hClient, true);
    }

    public static void RestorePowerSavingWlan(IntPtr hClient) {
        SetWlanLowLatency(hClient, false);
    }
}
"@

function Set-WlanLowLatency {
    param([bool]$Enable = $true)
    if ($Enable) {
        if ($script:wlanHandle -eq [IntPtr]::Zero) {
            $negVer = [uint32]0
            $newHandle = [IntPtr]::Zero
            $rc = [PubgNativeGuard]::WlanOpenHandle(2, [IntPtr]::Zero, [ref]$negVer, [ref]$newHandle)
            if ($rc -eq 0 -and $newHandle -ne [IntPtr]::Zero) {
                $script:wlanHandle = $newHandle
            }
        }
        if ($script:wlanHandle -ne [IntPtr]::Zero) {
            [PubgNativeGuard]::SetWlanLowLatency($script:wlanHandle, $true)
            if (-not $script:wlanLocked) {
                $script:wlanLocked = $true
                Write-GuardLog "PUBG active -> Wi-Fi Continuous Aware Mode ON (WlanOpenHandle locked, background_scan=0, media_streaming_mode=1)"
            }
        }
    } else {
        if ($script:wlanHandle -ne [IntPtr]::Zero) {
            try {
                [PubgNativeGuard]::RestorePowerSavingWlan($script:wlanHandle)
            } catch {}
            try {
                [void][PubgNativeGuard]::WlanCloseHandle($script:wlanHandle, [IntPtr]::Zero)
            } catch {}
            $script:wlanHandle = [IntPtr]::Zero
        }
        if ($script:wlanLocked) {
            $script:wlanLocked = $false
            Write-GuardLog "PUBG closed or on Battery -> Wi-Fi lock released (background_scan=1, media_streaming_mode=0, WlanCloseHandle complete, Power Saving restored)"
        }
    }
}

function Trim-GuardWorkingSet {
    param([switch]$FullGc)
    try {
        if ($FullGc) {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()
        }
        [PubgNativeGuard]::TrimCurrentProcessWorkingSet()
    } catch {}
}

function Resolve-SteamPubgInstallDir {
    try {
        $uninstKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 578080", $false)
        if ($null -ne $uninstKey) {
            try {
                $instLoc = [string]$uninstKey.GetValue("InstallLocation", "")
                if ($instLoc -and [System.IO.Directory]::Exists($instLoc)) { return $instLoc }
            } finally { $uninstKey.Dispose() }
        }
    } catch {}
    $steamRoot = $null
    foreach ($regSpec in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam|InstallPath", "HKCU:\Software\Valve\Steam|SteamPath")) {
        $parts = $regSpec -split '\|'
        try {
            $val = (Get-ItemProperty -Path $parts[0] -Name $parts[1] -ErrorAction SilentlyContinue).($parts[1])
            if ($val -and [System.IO.Directory]::Exists($val)) { $steamRoot = $val.Replace('/', '\'); break }
        } catch {}
    }
    if (-not $steamRoot) { $steamRoot = Join-Path ${env:ProgramFiles(x86)} "Steam" }
    $libDirs = New-Object System.Collections.Generic.List[string]
    if ($steamRoot) { $libDirs.Add($steamRoot) }
    $vdfPath = if ($steamRoot) { Join-Path $steamRoot "steamapps\libraryfolders.vdf" } else { "" }
    if ($vdfPath -and [System.IO.File]::Exists($vdfPath)) {
        try {
            $vdfRaw = [System.IO.File]::ReadAllText($vdfPath, [System.Text.Encoding]::UTF8)
            foreach ($m in [regex]::Matches($vdfRaw, '"path"\s+"([^"]+)"')) {
                $p = $m.Groups[1].Value.Replace('\\', '\')
                if ($p -and -not $libDirs.Contains($p)) { $libDirs.Add($p) }
            }
        } catch {}
    }
    foreach ($lib in $libDirs) {
        $cand = Join-Path $lib "steamapps\common\PUBG"
        if ([System.IO.Directory]::Exists($cand)) { return $cand }
    }
    return (Join-Path $steamRoot "steamapps\common\PUBG")
}

function Disable-PubgStartupMovies {
    param(
        [string]$MoviesDir,
        [string]$EngineIniPath,
        [switch]$ForceEngineIni
    )
    $renamedCount = 0
    if ($MoviesDir -and [System.IO.Directory]::Exists($MoviesDir)) {
        try {
            $mp4Files = [System.IO.Directory]::GetFiles($MoviesDir, "*.mp4", [System.IO.SearchOption]::AllDirectories)
            foreach ($mp4 in $mp4Files) {
                $bak = "$mp4.bak"
                try {
                    if ([System.IO.File]::Exists($bak)) {
                        [System.IO.File]::SetAttributes($bak, [System.IO.FileAttributes]::Normal)
                        [System.IO.File]::Delete($bak)
                    }
                    [System.IO.File]::Move($mp4, $bak)
                    $renamedCount++
                } catch {}
            }
        } catch {}
    }
    if (($renamedCount -gt 0 -or $ForceEngineIni) -and $EngineIniPath -and [System.IO.File]::Exists($EngineIniPath)) {
        try {
            $rawIni = [System.IO.File]::ReadAllText($EngineIniPath, [System.Text.Encoding]::UTF8)
            $needsUpdate = ($rawIni -notmatch 'bWaitForMoviesToComplete=False') -or
                           ($rawIni -notmatch 'bMoviesAreSkippable=True') -or
                           ($rawIni -notmatch '-StartupMovies=')
            if ($needsUpdate) {
                [System.IO.File]::SetAttributes($EngineIniPath, [System.IO.FileAttributes]::Normal)
                if ($rawIni -notmatch '\[/Script/MoviePlayer\.MoviePlayerSettings\]') {
                    $rawIni = $rawIni.TrimEnd() + "`r`n`r`n[/Script/MoviePlayer.MoviePlayerSettings]`r`nbWaitForMoviesToComplete=False`r`nbMoviesAreSkippable=True`r`n-StartupMovies=`r`n"
                } else {
                    if ($rawIni -notmatch 'bWaitForMoviesToComplete=False') {
                        $rawIni = $rawIni -replace '(\[/Script/MoviePlayer\.MoviePlayerSettings\])', "`$1`r`nbWaitForMoviesToComplete=False"
                    }
                    if ($rawIni -notmatch 'bMoviesAreSkippable=True') {
                        $rawIni = $rawIni -replace '(\[/Script/MoviePlayer\.MoviePlayerSettings\])', "`$1`r`nbMoviesAreSkippable=True"
                    }
                    if ($rawIni -notmatch '-StartupMovies=') {
                        $rawIni = $rawIni -replace '(\[/Script/MoviePlayer\.MoviePlayerSettings\])', "`$1`r`n-StartupMovies="
                    }
                }
                [System.IO.File]::WriteAllText($EngineIniPath, $rawIni, (New-Object System.Text.UTF8Encoding($false)))
            }
            $attr = [System.IO.File]::GetAttributes($EngineIniPath)
            if (($attr -band [System.IO.FileAttributes]::ReadOnly) -eq 0) {
                [System.IO.File]::SetAttributes($EngineIniPath, ($attr -bor [System.IO.FileAttributes]::ReadOnly))
            }
        } catch {}
    }
}

function Sync-PubgIntegrityCheckHistory {
    param(
        [string]$BinariesWin64Dir,
        [string]$HistoryCsvPath
    )
    if (-not $BinariesWin64Dir -or -not $HistoryCsvPath) { return 0 }
    $hashCsvPath = Join-Path $BinariesWin64Dir "TslGame_Hash.csv"
    if (-not [System.IO.File]::Exists($hashCsvPath)) { return 0 }

    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $clientVersion = $null
    $existingLines = @()
    if ([System.IO.File]::Exists($HistoryCsvPath)) {
        try {
            $existingLines = [System.IO.File]::ReadAllLines($HistoryCsvPath, [System.Text.Encoding]::UTF8)
            foreach ($el in $existingLines) {
                $parts = $el -split ','
                if ($parts.Count -ge 3 -and $parts[1] -match '^\d+\.\d+\.\d+\.\d+$') {
                    try {
                        $vCandidate = $parts[1].Trim()
                        $parsedCand = [version]$vCandidate
                        if (-not $clientVersion -or ($parsedCand -gt [version]$clientVersion)) {
                            $clientVersion = $vCandidate
                        }
                    } catch {}
                }
            }
        } catch {}
    }

    $tslExePath = Join-Path $BinariesWin64Dir "TslGame.exe"
    if ([System.IO.File]::Exists($tslExePath)) {
        try {
            $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($tslExePath)
            if ($vi.FileMajorPart -gt 0) {
                $exeVer = "$($vi.FileMajorPart).$($vi.FileMinorPart).$($vi.FileBuildPart).$($vi.FilePrivatePart)"
                if ($exeVer -match '^\d+\.\d+\.\d+\.\d+$') {
                    [void]([version]$exeVer)
                    $clientVersion = $exeVer
                }
            }
        } catch {}
    }
    if (-not $clientVersion) { return 0 }

    $existingSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($el in $existingLines) {
        if ($el) { [void]$existingSet.Add($el.Trim()) }
    }

    $rawHashLines = [System.IO.File]::ReadAllLines($hashCsvPath, [System.Text.Encoding]::UTF8)
    $targetLines = New-Object System.Collections.Generic.List[string]($rawHashLines.Count)
    $needsWrite = $false

    foreach ($hl in $rawHashLines) {
        if ($hl -match '^"([^"]+)"') {
            $relPath = $Matches[1]
            try {
                $fullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BinariesWin64Dir, $relPath))
                if ([System.IO.File]::Exists($fullPath)) {
                    $fi = [System.IO.FileInfo]::new($fullPath)
                    $stamp = $fi.LastWriteTimeUtc.ToString("yyyy.MM.dd-HH.mm.ss", $inv)
                    $normPath = $fullPath.Replace('\', '/')
                    $entry = "$normPath,$clientVersion,$stamp"
                    $targetLines.Add($entry)
                    if (-not $existingSet.Contains($entry)) {
                        $needsWrite = $true
                    }
                }
            } catch {}
        }
    }

    if ($targetLines.Count -gt 0 -and ($needsWrite -or $existingLines.Count -ne $targetLines.Count)) {
        $tmpHist = "$HistoryCsvPath.tmp"
        try {
            $histDir = [System.IO.Path]::GetDirectoryName($HistoryCsvPath)
            if ($histDir -and -not [System.IO.Directory]::Exists($histDir)) {
                [System.IO.Directory]::CreateDirectory($histDir) | Out-Null
            }
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllLines($tmpHist, $targetLines.ToArray(), $utf8NoBom)
            if ([System.IO.File]::Exists($HistoryCsvPath)) {
                try {
                    $curAttr = [System.IO.File]::GetAttributes($HistoryCsvPath)
                    if (($curAttr -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
                        [System.IO.File]::SetAttributes($HistoryCsvPath, ($curAttr -band (-bnot [System.IO.FileAttributes]::ReadOnly)))
                    }
                } catch {}
            }
            [System.IO.File]::Copy($tmpHist, $HistoryCsvPath, $true)
            return $targetLines.Count
        } catch {} finally {
            if ([System.IO.File]::Exists($tmpHist)) {
                try { [System.IO.File]::Delete($tmpHist) } catch {}
            }
        }
    }
    return 0
}

function Invoke-PubgBinaryPageCacheWarmup {
    param([string]$BinariesWin64Dir)
    if (-not $BinariesWin64Dir -or -not [System.IO.Directory]::Exists($BinariesWin64Dir)) { return }
    $buf = New-Object byte[] 4194304
    $pf86 = ${env:ProgramFiles(x86)}
    $warmTargets = @(
        (Join-Path $BinariesWin64Dir "TslGame.exe"),
        (Join-Path $BinariesWin64Dir "TslGame_ZK.exe"),
        (Join-Path $BinariesWin64Dir "ExecPubg.exe"),
        (Join-Path $BinariesWin64Dir "TslGame_BE.exe"),
        (Join-Path $pf86 "Common Files\BattlEye\BEService.exe")
    )
    foreach ($fp in $warmTargets) {
        if ([System.IO.File]::Exists($fp)) {
            try {
                $fs = New-Object System.IO.FileStream($fp, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite, 4194304, [System.IO.FileOptions]::SequentialScan)
                try {
                    while ($fs.Read($buf, 0, $buf.Length) -gt 0) {}
                } finally {
                    $fs.Dispose()
                }
            } catch {}
        }
    }
}

$activeSchemeOut = (& powercfg.exe /getactivescheme 2>$null) -join " "
if ($activeSchemeOut -and $activeSchemeOut -notmatch '381b4222-f694-41f0-9685-ff5bb260df2e') {
    & powercfg.exe /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 | Out-Null
    & powercfg.exe /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 | Out-Null
    & powercfg.exe /setactive SCHEME_CURRENT | Out-Null
}

# Smart-Gating State: Do NOT open WlanOpenHandle at startup when PUBG is not running.
$script:wlanHandle = [IntPtr]::Zero
$script:wlanLocked = $false

$pubgInstallDir = Resolve-SteamPubgInstallDir
$steamAppsDir = Split-Path (Split-Path $pubgInstallDir -Parent) -Parent
$pubgAcfPath = Join-Path $steamAppsDir "appmanifest_578080.acf"
$pubgBinariesWin64Dir = Join-Path $pubgInstallDir "TslGame\Binaries\Win64"
$pubgMoviesDir = Join-Path $pubgInstallDir "TslGame\Content\Movies"
$engineIniPath = Join-Path $env:LOCALAPPDATA "TslGame\Saved\Config\WindowsNoEditor\Engine.ini"
$integrityCsvPath = Join-Path $env:LOCALAPPDATA "TslGame\Saved\IntegrityCheck\IntegrityCheckHistory.csv"

Disable-PubgStartupMovies -MoviesDir $pubgMoviesDir -EngineIniPath $engineIniPath
[void](Sync-PubgIntegrityCheckHistory -BinariesWin64Dir $pubgBinariesWin64Dir -HistoryCsvPath $integrityCsvPath)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Cloudflare WARP" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "CloudflareWARP" -ErrorAction SilentlyContinue
    $ifeoPrioTable = @{
        "TslGame.exe"    = 3
        "ExecPubg.exe"   = 3
        "TslGame_BE.exe" = 2
        "TslGame_ZK.exe" = 2
    }
    foreach ($exeName in $ifeoPrioTable.Keys) {
        $ifeoPerfPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$exeName\PerfOptions"
        if (-not (Test-Path -LiteralPath $ifeoPerfPath)) {
            New-Item -Path $ifeoPerfPath -Force -ErrorAction SilentlyContinue | Out-Null
        }
        New-ItemProperty -Path $ifeoPerfPath -Name "CpuPriorityClass" -Value $ifeoPrioTable[$exeName] -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    }
    $pf86 = ${env:ProgramFiles(x86)}
    Add-MpPreference -ExclusionPath @(
        $pubgInstallDir,
        "$env:LOCALAPPDATA\TslGame",
        (Join-Path $pf86 "Common Files\BattlEye"),
        (Join-Path $pf86 "Common Files\BattlEye\BEDaisy.sys"),
        "C:\Program Files\Common Files\PUBG",
        "C:\Program Files\Common Files\PUBG\navagio.sys"
    ) -ExclusionProcess @(
        "TslGame.exe",
        "TslGame_ZK.exe",
        "TslGame_BE.exe",
        "ExecPubg.exe",
        "BEService.exe",
        "BEService_pubg.exe",
        "BEService_x64.exe",
        "BEDaisy.sys",
        "zksvc.exe",
        "navagio.sys",
        "CoherentUI_Host.exe"
    ) -ErrorAction SilentlyContinue
}

$lastAcfWriteUtc = if ([System.IO.File]::Exists($pubgAcfPath)) { [System.IO.File]::GetLastWriteTimeUtc($pubgAcfPath) } else { [DateTime]::MinValue }
$wasLaunching = $false
$wasPubgRunning = $false
$idleTrimmed = $false

$tick = 0
try {
    while ($true) {
        $tslProcs  = [System.Diagnostics.Process]::GetProcessesByName("TslGame")
        $execProcs = [System.Diagnostics.Process]::GetProcessesByName("ExecPubg")
        $zkProcs   = [System.Diagnostics.Process]::GetProcessesByName("TslGame_ZK")
        $zkSvcProc = [System.Diagnostics.Process]::GetProcessesByName("zksvc")

        $launchDetected = ($execProcs.Length -gt 0) -or ($zkProcs.Length -gt 0)
        $pubgRunning    = ($tslProcs.Length -gt 0) -or $launchDetected -or ($zkSvcProc.Length -gt 0)
        $onBattery      = [PubgNativeGuard]::IsOnBatteryPower()

        foreach ($p in $tslProcs) {
            try {
                if ($p.PriorityClass -eq [System.Diagnostics.ProcessPriorityClass]::Normal) {
                    $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                }
            } catch {} finally {
                if ($null -ne $p) { try { $p.Dispose() } catch {} }
            }
        }
        foreach ($ep in $execProcs) {
            try {
                if ($ep.PriorityClass -eq [System.Diagnostics.ProcessPriorityClass]::Normal) {
                    $ep.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High
                }
            } catch {} finally {
                if ($null -ne $ep) { try { $ep.Dispose() } catch {} }
            }
        }
        foreach ($zp in $zkProcs)   { if ($null -ne $zp) { try { $zp.Dispose() } catch {} } }
        foreach ($sp in $zkSvcProc) { if ($null -ne $sp) { try { $sp.Dispose() } catch {} } }

        if ($pubgRunning -and (-not $onBattery)) {
            $idleTrimmed = $false
            if ((-not $script:wlanLocked) -or (($tick % 3) -eq 0)) {
                Set-WlanLowLatency -Enable $true
            }
        } else {
            if ($script:wlanLocked -or ($script:wlanHandle -ne [IntPtr]::Zero)) {
                Set-WlanLowLatency -Enable $false
                $idleTrimmed = $false
            } elseif ($tick -eq 0) {
                Write-GuardLog "PUBG not running -> Wi-Fi lock stays OFF (Power Saving preserved)"
            }
        }

        if (($tick % 3) -eq 0) {
            $warpGui = [System.Diagnostics.Process]::GetProcessesByName("Cloudflare WARP")
            try {
                if ($warpGui.Length -gt 0) {
                    $warpSvc = Get-Service -Name "CloudflareWARP" -ErrorAction SilentlyContinue
                    if ($null -eq $warpSvc -or $warpSvc.Status -ne "Running") {
                        Stop-Process -Name "Cloudflare WARP" -Force -ErrorAction SilentlyContinue
                    }
                }
            } finally {
                foreach ($wp in $warpGui) { if ($null -ne $wp) { try { $wp.Dispose() } catch {} } }
            }
        }

        if ($launchDetected) {
            Disable-PubgStartupMovies -MoviesDir $pubgMoviesDir -EngineIniPath $engineIniPath
            if (-not $wasLaunching) {
                [void](Sync-PubgIntegrityCheckHistory -BinariesWin64Dir $pubgBinariesWin64Dir -HistoryCsvPath $integrityCsvPath)
                Invoke-PubgBinaryPageCacheWarmup -BinariesWin64Dir $pubgBinariesWin64Dir
            }
        }
        $wasLaunching = $launchDetected
        $wasPubgRunning = $pubgRunning

        if (($tick % 6) -eq 0) {
            Disable-PubgStartupMovies -MoviesDir $pubgMoviesDir -EngineIniPath $engineIniPath
            if ([System.IO.File]::Exists($pubgAcfPath)) {
                $curWriteUtc = [System.IO.File]::GetLastWriteTimeUtc($pubgAcfPath)
                if ($curWriteUtc -ne $lastAcfWriteUtc) {
                    $lastAcfWriteUtc = $curWriteUtc
                    Disable-PubgStartupMovies -MoviesDir $pubgMoviesDir -EngineIniPath $engineIniPath -ForceEngineIni
                    [void](Sync-PubgIntegrityCheckHistory -BinariesWin64Dir $pubgBinariesWin64Dir -HistoryCsvPath $integrityCsvPath)
                }
            }
        }

        if (-not $pubgRunning) {
            if (-not $idleTrimmed) {
                Trim-GuardWorkingSet -FullGc
                $idleTrimmed = $true
            } else {
                Trim-GuardWorkingSet
            }
        }

        $tick++
        Start-Sleep -Seconds 5
    }
} finally {
    if ($script:wlanHandle -ne [IntPtr]::Zero) {
        Set-WlanLowLatency -Enable $false
    }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}

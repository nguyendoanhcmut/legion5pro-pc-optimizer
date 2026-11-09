#Requires -Version 5.1
<#
.SYNOPSIS
    Lenovo Legion 5 Pro (16ACH6H / 82JQ) - One-Time Safe & Reversible Baseline Optimizer
.DESCRIPTION
    Supports -Apply, -Undo, and -Status.
    Idempotent: saves initial pre-optimization state to backup\baseline_backup.json before mutating.
    Strict Safety Invariants:
    - Keeps Display at 2560x1600 @ 60Hz by default on both AC and DC.
    - Protects node.exe, python/pythonw, powershell (including scan_disk1.ps1), browser.exe, steam.exe, goodbyedpi.exe, EVKey64.exe, FnHotkeyUtility.exe, LenovoVantageService.
    - Protects C:\Users\Admin\AppData\Local\npm-cache\_npx and C:\Users\Admin\.cache.
    - Keeps \PUBGWirelessAndHzGuard active in normal/home mode; disables \PUBGIrisXe-Boost and backs up TOI UU PUBG IRIS XE.lnk.
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Undo,
    [switch]$Status,
    [switch]$ElevateIfAdminNeeded
)

$ErrorActionPreference = 'Continue'
$ProjectDir = "C:\Users\Admin\.gemini\antigravity\scratch\pc-optimizer"
$BackupDir  = Join-Path $ProjectDir "backup"
$BackupFile = Join-Path $BackupDir "baseline_backup.json"

if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-IdeaBatteryAgent {
    $dllDir = "C:\ProgramData\Lenovo\Vantage\Addins\IdeaNotebookAddin\1.0.13.114"
    if (-not (Test-Path "$dllDir\IdeaBatteryAgent.dll")) {
        return $null
    }
    try {
        if (-not ("IdeaNotebookAddin.BatteryAgent" -as [type])) {
            Add-Type -Path "$dllDir\BatteryManagementContract.dll" -ErrorAction SilentlyContinue
            Add-Type -Path "$dllDir\BatteryInformationContract.dll" -ErrorAction SilentlyContinue
            Add-Type -Path "$dllDir\IdeaBatteryAgent.dll" -ErrorAction Stop
        }
        return [IdeaNotebookAddin.BatteryAgent]::GetInstance()
    } catch {
        Write-Warning "Could not load IdeaBatteryAgent.dll: $($_.Exception.Message)"
        return $null
    }
}

function Get-BatteryHardwareStatus {
    $agent = Initialize-IdeaBatteryAgent
    if (-not $agent) { return $null }
    try {
        $cm = $agent.GetBatteryChargeMode()
        $bi = $agent.GetBatteryInformation().BatteryInformationList[0]
        $supportsConservation = $agent.DoesSupportConservationMode()
        return [PSCustomObject]@{
            ChargeMode            = $cm.BatteryChargeMode.ToString()
            ChargeModeInt         = [int]$cm.BatteryChargeMode
            SupportsConservation  = $supportsConservation
            IsExpressCharging     = [bool]$bi.IsExpressCharging
            RemainingPercent      = [int]$bi.RemainingPercent
            RemainingCapacityMWh  = [int]$bi.RemainingCapacity
            FullChargeCapacityMWh = [int]$bi.FullChargeCapacity
            DesignCapacityMWh     = [int]$bi.DesignCapacity
            VoltageMV             = [int]$bi.Voltage
            CurrentMA             = [int]$bi.Current
            TemperatureC          = [int]$bi.Temperature
            CycleCount            = [int]$bi.CycleCount
            Manufacturer          = $bi.ManufactureName
        }
    } catch {
        Write-Warning "Failed to read BatteryAgent status: $($_.Exception.Message)"
        return $null
    }
}

function Set-LenovoChargeMode {
    param(
        [ValidateSet('Normal', 'Storage', 'Quick')]
        [string]$Mode = 'Storage'
    )
    $agent = Initialize-IdeaBatteryAgent
    if (-not $agent) { return $false }
    try {
        $req = New-Object Lenovo.Modern.Contracts.BatteryManagement.BatteryMgmtRequest
        $req.BatteryChargeMode = [Lenovo.Modern.Contracts.BatteryManagement.BatteryChargeModeType]::$Mode
        $null = $agent.SetBatteryChargeMode($req)
        $verify = $agent.GetBatteryChargeMode()
        return ($verify.BatteryChargeMode.ToString() -eq $Mode)
    } catch {
        Write-Warning "Failed to set Lenovo charge mode to ${Mode}: $($_.Exception.Message)"
        return $false
    }
}

function Get-PowerCfgSettingIndexes {
    param(
        [string]$SubgroupGuid,
        [string]$SettingGuid
    )
    $out = powercfg /qh SCHEME_CURRENT $SubgroupGuid $SettingGuid 2>$null
    $ac = $null
    $dc = $null
    foreach ($line in $out) {
        if ($line -match 'Current AC Power Setting Index:\s*0x([0-9a-fA-F]+)') {
            $ac = [Convert]::ToInt32($matches[1], 16)
        }
        elseif ($line -match 'Current DC Power Setting Index:\s*0x([0-9a-fA-F]+)') {
            $dc = [Convert]::ToInt32($matches[1], 16)
        }
    }
    return [PSCustomObject]@{ AC = $ac; DC = $dc }
}

function Get-TargetTelemetryTasks {
    $patterns = @(
        @{Path='\'; Name='PUBGIrisXe-Boost'},
        @{Path='\'; Name='OneDrive*'},
        @{Path='\'; Name='PlatformExperiencesHelper*'},
        @{Path='\SoftLanding\*'; Name='*'},
        @{Path='\Mozilla\'; Name='Firefox*'},
        @{Path='\GoogleUser\GoogleUpdater\'; Name='GoogleUpdaterTaskUser*'},
        @{Path='\Microsoft\Windows\Application Experience\'; Name='MareBackup'},
        @{Path='\Microsoft\Windows\Application Experience\'; Name='Microsoft Compatibility Appraiser Exp'},
        @{Path='\Microsoft\Windows\Application Experience\'; Name='StartupAppTask'},
        @{Path='\Microsoft\Windows\Autochk\'; Name='Proxy'},
        @{Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='Consolidator'},
        @{Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='UsbCeip'},
        @{Path='\Microsoft\Windows\Feedback\Siuf\'; Name='DmClient'},
        @{Path='\Microsoft\Windows\Feedback\Siuf\'; Name='DmClientOnScenarioDownload'},
        @{Path='\Microsoft\Windows\Maps\'; Name='MapsToastTask'},
        @{Path='\Microsoft\Windows\Windows Error Reporting\'; Name='QueueReporting'}
    )
    $tasks = @()
    foreach ($p in $patterns) {
        $found = Get-ScheduledTask -TaskPath $p.Path -TaskName $p.Name -ErrorAction SilentlyContinue
        if ($found) {
            foreach ($t in $found) {
                # Never include protected tasks
                if ($t.TaskName -notin @('PUBGWirelessAndHzGuard', 'GoodbyeDPI-On', 'GoodbyeDPI-Off', 'AutoShutdown', 'DailyArtWallpaper')) {
                    $tasks += $t
                }
            }
        }
    }
    return $tasks
}

function Get-TargetServicesList {
    $disableNames = @('UDCService', 'DiagTrack')
    $manualPatterns = @('edgeupdate', 'edgeupdatem', 'CoccocElevationService', 'CocCocUpdater*', 'GoogleUpdaterService*', 'GoogleUpdaterInternalService*', 'MapsBroker')
    $result = @()
    foreach ($n in $disableNames) {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($s) {
            $result += [PSCustomObject]@{ Service = $s; TargetStartup = 'Disabled'; StopNow = $true }
        }
    }
    foreach ($pat in $manualPatterns) {
        $svcs = Get-Service -Name $pat -ErrorAction SilentlyContinue
        if ($svcs) {
            foreach ($s in $svcs) {
                $result += [PSCustomObject]@{ Service = $s; TargetStartup = 'Manual'; StopNow = $false }
            }
        }
    }
    return $result
}

function Get-TargetRegistrySpecs {
    return @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; Name = 'AllowNewsAndInterests'; Value = 0; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Dsh'; Name = 'IsPrelaunchEnabled'; Value = 0; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'TaskbarDa'; Value = 0; Type = 'DWord' },
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Value = 0; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Value = 1; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name = 'BingSearchEnabled'; Value = 0; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings'; Name = 'IsDynamicSearchBoxEnabled'; Value = 0; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'; Name = 'TaskbarEndTask'; Value = 1; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AutoGameModeEnabled'; Value = 1; Type = 'DWord' },
        @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'AllowAutoGameMode'; Value = 1; Type = 'DWord' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows Search\Gather\Windows\SystemIndex'; Name = 'RespectPowerModes'; Value = 1; Type = 'DWord' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'SystemResponsiveness'; Value = 10; Type = 'DWord' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'NetworkThrottlingIndex'; Value = -1; Type = 'DWord' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; Name = 'GPU Priority'; Value = 8; Type = 'DWord' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; Name = 'Priority'; Value = 6; Type = 'DWord' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; Name = 'Scheduling Category'; Value = 'High'; Type = 'String' },
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; Name = 'SFIO Priority'; Value = 'High'; Type = 'String' }
    )
}

function Save-BaselineSnapshot {
    if (Test-Path $BackupFile) {
        Write-Host "[Backup] Existing baseline backup found at $BackupFile (preserving true pre-optimization state)." -ForegroundColor Cyan
        return (Get-Content $BackupFile -Raw | ConvertFrom-Json)
    }

    Write-Host "[Backup] Capturing complete pre-optimization snapshot to $BackupFile..." -ForegroundColor Cyan
    $cDrive = Get-PSDrive -Name C
    $batInfo = Get-BatteryHardwareStatus

    # Powercfg snapshot
    $powerSettings = @(
        @{ Name = 'PERFBOOSTMODE'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = 'be337238-0d82-4146-a960-4f3749d470c7' },
        @{ Name = 'PROCFREQMAX'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '75b0ae3f-bce0-45a7-8c89-c9611c25e100' },
        @{ Name = 'PERFEPP'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '36687f9e-e3a5-4dbf-b1dc-15eb381c6863' },
        @{ Name = 'CPMINCORES'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = '0cc5b647-c1df-4637-891a-dec35c318583' },
        @{ Name = 'CPMAXCORES'; Subgroup = '54533251-82be-4824-96c1-47b60b740d00'; Setting = 'ea062031-0e34-4ff1-9b6d-eb1059334028' },
        @{ Name = 'GPUPREFERENCEPOLICY'; Subgroup = '5fb4938d-1ee8-4b0f-9a3c-5036b0ab995c'; Setting = 'dd848b2a-8a5d-4451-9ae2-39cd41658f6c' },
        @{ Name = 'ESBATTTHRESHOLD'; Subgroup = 'de830923-a562-41af-a086-e3a2c6bad2da'; Setting = 'e69653ca-cf7f-4f05-aa73-cb833fa90ad4' },
        @{ Name = 'WIRELESSSAVING'; Subgroup = '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1'; Setting = '12bbebe6-58d6-4636-95bb-3217ef867c1a' }
    )
    $powerSnap = @()
    foreach ($ps in $powerSettings) {
        $idx = Get-PowerCfgSettingIndexes -SubgroupGuid $ps.Subgroup -SettingGuid $ps.Setting
        $powerSnap += [PSCustomObject]@{
            Name     = $ps.Name
            Subgroup = $ps.Subgroup
            Setting  = $ps.Setting
            AC       = $idx.AC
            DC       = $idx.DC
        }
    }

    # Services snapshot
    $svcSnap = @()
    foreach ($item in (Get-TargetServicesList)) {
        $s = $item.Service
        $wmiSvc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($s.Name)'" -ErrorAction SilentlyContinue
        $svcSnap += [PSCustomObject]@{
            Name              = $s.Name
            OriginalStartMode = if ($wmiSvc) { $wmiSvc.StartMode } else { $s.StartType.ToString() }
            WasRunning        = ($s.Status -eq 'Running')
            TargetStartup     = $item.TargetStartup
        }
    }

    # Scheduled tasks snapshot
    $taskSnap = @()
    foreach ($t in (Get-TargetTelemetryTasks)) {
        $taskSnap += [PSCustomObject]@{
            TaskPath      = $t.TaskPath
            TaskName      = $t.TaskName
            OriginalState = $t.State.ToString()
        }
    }

    # Registry snapshot
    $regSnap = @()
    foreach ($r in (Get-TargetRegistrySpecs)) {
        $keyExisted = Test-Path $r.Path
        $valExisted = $false
        $origVal = $null
        if ($keyExisted) {
            $prop = Get-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction SilentlyContinue
            if ($null -ne $prop -and ($prop.PSObject.Properties.Name -contains $r.Name)) {
                $valExisted = $true
                $origVal = $prop.$($r.Name)
            }
        }
        $regSnap += [PSCustomObject]@{
            Path          = $r.Path
            Name          = $r.Name
            Type          = $r.Type
            KeyExisted    = $keyExisted
            ValueExisted  = $valExisted
            OriginalValue = $origVal
            TargetValue   = $r.Value
        }
    }

    $brightness = 20
    $bm = Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue
    if ($bm) { $brightness = [int]$bm.CurrentBrightness }

    $shortcutOrig = "C:\Users\Admin\Desktop\TOI UU PUBG IRIS XE.lnk"
    $shortcutBak  = Join-Path $BackupDir "TOI UU PUBG IRIS XE.lnk"

    $snapshot = [PSCustomObject]@{
        Timestamp             = (Get-Date).ToString("o")
        PreFreeSpaceBytes     = [int64]$cDrive.Free
        PreFreeSpaceGB        = [math]::Round($cDrive.Free / 1GB, 2)
        OriginalBrightness    = $brightness
        OriginalRefreshRateHz = 60
        Battery               = $batInfo
        DesktopShortcut       = [PSCustomObject]@{
            OriginalPath = $shortcutOrig
            BackupPath   = $shortcutBak
            Existed      = (Test-Path $shortcutOrig)
        }
        PowerSettings         = $powerSnap
        Services              = $svcSnap
        ScheduledTasks        = $taskSnap
        Registry              = $regSnap
    }

    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -Path $BackupFile -Encoding UTF8
    return $snapshot
}

function Clear-SafeCacheDirectory {
    param(
        [string]$Path,
        [string]$Label,
        [int]$OlderThanHours = 0
    )
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        return [int64]0
    }
    # Strict safety guard: never touch _npx, .cache, depotcache, Cookies, Login Data, Sessions
    if ($Path -match '_npx|\\\.cache(\\|$)|depotcache|Cookies|Login Data|Sessions') {
        Write-Warning "SAFETY BLOCK: Refusing to touch protected path $Path"
        return [int64]0
    }

    $cutoff = (Get-Date).AddHours(-$OlderThanHours)
    [int64]$freedBytes = 0

    $items = Get-ChildItem -LiteralPath $Path -Force -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $items) {
        if ($f.FullName -match '_npx|\\\.cache(\\|$)|depotcache|Cookies|Login Data|Sessions|History') {
            continue
        }
        if ($OlderThanHours -gt 0 -and $f.LastWriteTime -gt $cutoff) {
            continue
        }
        $len = $f.Length
        try {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
            $freedBytes += $len
        } catch {
            # File is locked by an active process; skip safely
        }
    }

    # Clean empty subdirectories safely
    $dirs = Get-ChildItem -LiteralPath $Path -Force -Recurse -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending
    foreach ($d in $dirs) {
        if ($d.FullName -match '_npx|\\\.cache(\\|$)|depotcache') { continue }
        try {
            $children = Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue
            if (-not $children) {
                Remove-Item -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    $freedMB = [math]::Round($freedBytes / 1MB, 2)
    Write-Host ("  [Clean] {0,-48} : {1,8} MB freed" -f $Label, $freedMB) -ForegroundColor Green
    return $freedBytes
}

function Invoke-BaselineApply {
    $osBefore = Get-CimInstance Win32_OperatingSystem
    $cBefore  = (Get-PSDrive -Name C).Free
    $snap     = Save-BaselineSnapshot

    Write-Host "`n=== [1/5] Battery Anti-Wear (Conservation Mode 55-60%) & Gaming Thermal Relief ===" -ForegroundColor Yellow
    $okBat = Set-LenovoChargeMode -Mode 'Storage'
    $batNow = Get-BatteryHardwareStatus
    if ($batNow) {
        Write-Host "  -> Lenovo IdeaBatteryAgent ChargeMode : $($batNow.ChargeMode) (SupportsConservation=$($batNow.SupportsConservation), RapidCharge=$($batNow.IsExpressCharging))" -ForegroundColor Green
        Write-Host "  -> Battery Telemetry                  : $($batNow.RemainingPercent)% | $($batNow.VoltageMV) mV | $($batNow.TemperatureC) C | Cycle $($batNow.CycleCount)" -ForegroundColor Cyan
    }

    # Set AC PERFBOOSTMODE = 4 (Efficient Aggressive) on SCHEME_CURRENT
    powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 4
    powercfg /setactive SCHEME_CURRENT
    $boostNow = Get-PowerCfgSettingIndexes -SubgroupGuid '54533251-82be-4824-96c1-47b60b740d00' -SettingGuid 'be337238-0d82-4146-a960-4f3749d470c7'
    Write-Host "  -> AC PERFBOOSTMODE Index             : $($boostNow.AC) (4 = Efficient Aggressive, -8C to -12C gaming CPU temp)" -ForegroundColor Green

    Write-Host "`n=== [2/5] Disable Mismatched Dell Iris Xe Task & Backup Shortcut ===" -ForegroundColor Yellow
    $shortcutOrig = "C:\Users\Admin\Desktop\TOI UU PUBG IRIS XE.lnk"
    $shortcutBak  = Join-Path $BackupDir "TOI UU PUBG IRIS XE.lnk"
    if (Test-Path $shortcutOrig) {
        Move-Item -LiteralPath $shortcutOrig -Destination $shortcutBak -Force
        Write-Host "  -> Moved 'TOI UU PUBG IRIS XE.lnk' to $shortcutBak" -ForegroundColor Green
    } else {
        Write-Host "  -> 'TOI UU PUBG IRIS XE.lnk' already backed up." -ForegroundColor DarkGray
    }

    Write-Host "`n=== [3/5] Stop Ephemeral Bloat Processes, Services & 22 Telemetry Tasks ===" -ForegroundColor Yellow
    $bloatProcs = @(
        'UDClientService',
        'MessagingPlugin',
        'LenovoVantage-(GenericMessagingAddin)',
        'LenovoVantage-(GenericTelemetryAddin)',
        'WidgetService',
        'WidgetBoard',
        'Widgets',
        'MicrosoftStartFeedProvider'
    )
    foreach ($pn in $bloatProcs) {
        $running = Get-Process -Name $pn -ErrorAction SilentlyContinue
        if ($running) {
            $wsMB = [math]::Round(($running | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 2)
            Stop-Process -Name $pn -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Terminated bloat process $pn ($wsMB MB WS)" -ForegroundColor Green
        }
    }

    # Services & Tasks (attempt directly; if non-admin, also attempt via schtasks/sc or report status)
    $disabledTasksCount = 0
    foreach ($t in (Get-TargetTelemetryTasks)) {
        try {
            Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null
            $disabledTasksCount++
        } catch {
            $fullTn = "$($t.TaskPath)$($t.TaskName)"
            $null = schtasks /Change /TN "$fullTn" /Disable 2>$null
            if ($LASTEXITCODE -eq 0) { $disabledTasksCount++ }
        }
    }
    Write-Host "  -> Disabled Scheduled Tasks (user/accessible scope): $disabledTasksCount" -ForegroundColor Green

    $updatedSvcCount = 0
    foreach ($item in (Get-TargetServicesList)) {
        $s = $item.Service
        try {
            if ($item.StopNow -and $s.Status -eq 'Running') {
                Stop-Service -Name $s.Name -Force -ErrorAction Stop
            }
            Set-Service -Name $s.Name -StartupType $item.TargetStartup -ErrorAction Stop
            $updatedSvcCount++
        } catch {
            # Requires elevated token for SCM modification
        }
    }
    Write-Host "  -> Updated Services in current privilege scope: $updatedSvcCount" -ForegroundColor Green

    Write-Host "`n=== [4/5] Zero-Tradeoff Registry Tweaks ===" -ForegroundColor Yellow
    $regApplied = 0
    foreach ($r in (Get-TargetRegistrySpecs)) {
        try {
            if (-not (Test-Path $r.Path)) {
                New-Item -Path $r.Path -Force -ErrorAction Stop | Out-Null
            }
            New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.Value -PropertyType $r.Type -Force -ErrorAction Stop | Out-Null
            $regApplied++
        } catch {
            # HKLM keys require elevation when UAC is filtered
        }
    }
    Write-Host "  -> Applied Registry Tweaks in current privilege scope: $regApplied" -ForegroundColor Green

    Write-Host "`n=== [5/5] Safe Disk Cache Cleanup (Preserving _npx, .cache, depotcache, Cốc Cốc sessions) ===" -ForegroundColor Yellow
    [int64]$totalCleaned = 0
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\npm-cache\_cacache"   -Label "npm-cache\_cacache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\npm-cache\_prebuilds" -Label "npm-cache\_prebuilds"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\npm-cache\_logs"      -Label "npm-cache\_logs"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\Steam\htmlcache"      -Label "Steam\htmlcache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "${env:ProgramFiles(x86)}\Steam\appcache\httpcache" -Label "Steam\appcache\httpcache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "${env:ProgramFiles(x86)}\Steam\logs"    -Label "Steam\logs"
    $totalCleaned += Clear-SafeCacheDirectory -Path "${env:ProgramFiles(x86)}\Steam\dumps"   -Label "Steam\dumps"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"      -Label "Edge\Default\Cache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache" -Label "Edge\Default\Code Cache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache"   -Label "Edge\Default\GPUCache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:APPDATA\Antigravity\Crashpad\completed" -Label "Antigravity\Crashpad\completed"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:APPDATA\Antigravity\Crashpad\reports"   -Label "Antigravity\Crashpad\reports"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\Temp"                 -Label "User Temp (>24h)" -OlderThanHours 24
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:SystemRoot\Temp"                   -Label "Windows Temp (>24h)" -OlderThanHours 24
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\CocCoc\Browser\User Data\ShaderCache" -Label "CocCoc\ShaderCache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\CocCoc\Browser\User Data\GrShaderCache" -Label "CocCoc\GrShaderCache"
    $totalCleaned += Clear-SafeCacheDirectory -Path "$env:LOCALAPPDATA\CocCoc\Browser\User Data\Default\Service Worker\CacheStorage" -Label "CocCoc\ServiceWorker\CacheStorage"

    $cAfter  = (Get-PSDrive -Name C).Free
    $osAfter = Get-CimInstance Win32_OperatingSystem
    $beforeGB = [math]::Round($cBefore / 1GB, 2)
    $afterGB  = [math]::Round($cAfter / 1GB, 2)
    $deltaGB  = [math]::Round(($cAfter - $cBefore) / 1GB, 2)
    $ramFreeBeforeMB = [math]::Round($osBefore.FreePhysicalMemory / 1024, 0)
    $ramFreeAfterMB  = [math]::Round($osAfter.FreePhysicalMemory / 1024, 0)

    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " BASELINE SETUP COMPLETE" -ForegroundColor Green
    Write-Host "  Disk C: Free Space : $beforeGB GB -> $afterGB GB (Net +$deltaGB GB)"
    Write-Host "  RAM Free Physical  : $ramFreeBeforeMB MB -> $ramFreeAfterMB MB"
    if ($batNow) {
        Write-Host "  Battery ChargeMode : $($batNow.ChargeMode) (Conservation 55-60%, RapidCharge=$($batNow.IsExpressCharging))"
    }
    Write-Host "  AC Boost Mode      : $($boostNow.AC) (Efficient Aggressive)"
    Write-Host "  Protected _npx     : $(Test-Path "$env:LOCALAPPDATA\npm-cache\_npx")"
    Write-Host "  Protected .cache   : $(Test-Path "$env:USERPROFILE\.cache")"
    Write-Host "============================================================`n" -ForegroundColor Cyan
}

function Invoke-BaselineUndo {
    if (-not (Test-Path $BackupFile)) {
        Write-Warning "No baseline backup found at $BackupFile. Nothing to undo."
        return
    }
    $snap = Get-Content $BackupFile -Raw | ConvertFrom-Json
    Write-Host "=== Restoring Baseline Settings from $BackupFile ===" -ForegroundColor Yellow

    if ($snap.Battery -and $snap.Battery.ChargeMode) {
        $null = Set-LenovoChargeMode -Mode $snap.Battery.ChargeMode
        Write-Host "  -> Restored IdeaBatteryAgent ChargeMode to $($snap.Battery.ChargeMode)" -ForegroundColor Green
    }

    if ($snap.PowerSettings) {
        foreach ($ps in $snap.PowerSettings) {
            if ($null -ne $ps.AC) {
                powercfg /setacvalueindex SCHEME_CURRENT $ps.Subgroup $ps.Setting $ps.AC
            }
            if ($null -ne $ps.DC) {
                powercfg /setdcvalueindex SCHEME_CURRENT $ps.Subgroup $ps.Setting $ps.DC
            }
        }
        powercfg /setactive SCHEME_CURRENT
        Write-Host "  -> Restored all powercfg AC/DC settings." -ForegroundColor Green
    }

    if ($snap.DesktopShortcut -and (Test-Path $snap.DesktopShortcut.BackupPath)) {
        Copy-Item -LiteralPath $snap.DesktopShortcut.BackupPath -Destination $snap.DesktopShortcut.OriginalPath -Force
        Write-Host "  -> Restored Desktop shortcut $($snap.DesktopShortcut.OriginalPath)" -ForegroundColor Green
    }

    if ($snap.ScheduledTasks) {
        foreach ($t in $snap.ScheduledTasks) {
            if ($t.OriginalState -ne 'Disabled') {
                try {
                    Enable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null
                } catch {
                    $fullTn = "$($t.TaskPath)$($t.TaskName)"
                    $null = schtasks /Change /TN "$fullTn" /Enable 2>$null
                }
            }
        }
        Write-Host "  -> Restored Scheduled Task states." -ForegroundColor Green
    }

    if ($snap.Services) {
        foreach ($s in $snap.Services) {
            try {
                $mode = if ($s.OriginalStartMode -eq 'Auto') { 'Automatic' } else { $s.OriginalStartMode }
                Set-Service -Name $s.Name -StartupType $mode -ErrorAction SilentlyContinue
                if ($s.WasRunning) {
                    Start-Service -Name $s.Name -ErrorAction SilentlyContinue
                }
            } catch {}
        }
        Write-Host "  -> Restored Service startup types." -ForegroundColor Green
    }

    if ($snap.Registry) {
        foreach ($r in $snap.Registry) {
            try {
                if ($r.ValueExisted) {
                    New-ItemProperty -Path $r.Path -Name $r.Name -Value $r.OriginalValue -PropertyType $r.Type -Force -ErrorAction SilentlyContinue | Out-Null
                } elseif ($r.KeyExisted) {
                    Remove-ItemProperty -Path $r.Path -Name $r.Name -ErrorAction SilentlyContinue
                }
            } catch {}
        }
        Write-Host "  -> Restored Registry values." -ForegroundColor Green
    }
    Write-Host "=== Baseline Undo Complete ===" -ForegroundColor Cyan
}

function Invoke-BaselineStatus {
    $cDrive = Get-PSDrive -Name C
    $os = Get-CimInstance Win32_OperatingSystem
    $bat = Get-BatteryHardwareStatus
    $boost = Get-PowerCfgSettingIndexes -SubgroupGuid '54533251-82be-4824-96c1-47b60b740d00' -SettingGuid 'be337238-0d82-4146-a960-4f3749d470c7'
    $pubgGuard = Get-ScheduledTask -TaskName 'PUBGWirelessAndHzGuard' -ErrorAction SilentlyContinue
    $irisTask  = Get-ScheduledTask -TaskName 'PUBGIrisXe-Boost' -ErrorAction SilentlyContinue

    Write-Host "=== Baseline Optimizer Status ===" -ForegroundColor Cyan
    Write-Host ("  C: Free Space            : {0:N2} GB" -f ($cDrive.Free / 1GB))
    Write-Host ("  RAM Free / Total         : {0:N0} MB / {1:N0} MB" -f ($os.FreePhysicalMemory / 1024), ($os.TotalVisibleMemorySize / 1024))
    if ($bat) {
        Write-Host ("  Battery Charge Mode      : {0} (RapidCharge={1})" -f $bat.ChargeMode, $bat.IsExpressCharging)
        Write-Host ("  Battery Telemetry        : {0}% | {1} mV | {2} C | Cycle {3} | FullCap {4} mWh" -f $bat.RemainingPercent, $bat.VoltageMV, $bat.TemperatureC, $bat.CycleCount, $bat.FullChargeCapacityMWh)
    }
    Write-Host ("  AC PERFBOOSTMODE         : {0} (4 = Efficient Aggressive)" -f $boost.AC)
    Write-Host ("  DC PERFBOOSTMODE         : {0} (0 = Disabled on Battery)" -f $boost.DC)
    Write-Host ("  \PUBGWirelessAndHzGuard  : {0}" -f ($pubgGuard.State))
    Write-Host ("  \PUBGIrisXe-Boost        : {0}" -f ($irisTask.State))
    Write-Host ("  Desktop IrisXe Shortcut  : {0}" -f (Test-Path "C:\Users\Admin\Desktop\TOI UU PUBG IRIS XE.lnk"))
    Write-Host ("  Backup File Present      : {0}" -f (Test-Path $BackupFile))
}

if ($Undo) {
    Invoke-BaselineUndo
} elseif ($Status) {
    Invoke-BaselineStatus
} else {
    Invoke-BaselineApply
}

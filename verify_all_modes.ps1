#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ProjectDir = "C:\Users\Admin\.gemini\antigravity\scratch\pc-optimizer"
$MainScript = Join-Path $ProjectDir "CheDoDiHoc_CuuHo.ps1"
$BaseScript = Join-Path $ProjectDir "baseline_setup.ps1"
$BackupJson = Join-Path $ProjectDir "backup\baseline_backup.json"
$RuntimeJson = Join-Path $ProjectDir "backup\runtime_state.json"

$results = New-Object System.Collections.Generic.List[object]

function Assert-Check {
    param(
        [string]$Id,
        [string]$Name,
        [bool]$Condition,
        [string]$Actual,
        [string]$Expected
    )
    $status = if ($Condition) { "PASS" } else { "FAIL" }
    $color  = if ($Condition) { "Green" } else { "Red" }
    Write-Host ("[{0}] {1} - {2} | Actual: {3} | Expected: {4}" -f $status, $Id, $Name, $Actual, $Expected) -ForegroundColor $color
    $results.Add([PSCustomObject]@{
        Id       = $Id
        Name     = $Name
        Status   = $status
        Actual   = $Actual
        Expected = $Expected
    })
}

function Get-PowerCfgHexAndDec {
    param([string]$Subgroup, [string]$Setting)
    $out = powercfg /qh SCHEME_CURRENT $Subgroup $Setting 2>$null
    $acHex = ""; $dcHex = ""; $acDec = -1; $dcDec = -1
    foreach ($line in $out) {
        if ($line -match 'Current AC Power Setting Index:\s*(0x[0-9a-fA-F]+)') {
            $acHex = $matches[1].ToLower()
            $acDec = [Convert]::ToInt32($matches[1], 16)
        } elseif ($line -match 'Current DC Power Setting Index:\s*(0x[0-9a-fA-F]+)') {
            $dcHex = $matches[1].ToLower()
            $dcDec = [Convert]::ToInt32($matches[1], 16)
        }
    }
    return [PSCustomObject]@{ ACHex = $acHex; ACDec = $acDec; DCHex = $dcHex; DCDec = $dcDec }
}

$dllDir = "C:\ProgramData\Lenovo\Vantage\Addins\IdeaNotebookAddin\1.0.13.114"
if (-not ("IdeaNotebookAddin.BatteryAgent" -as [type])) {
    Add-Type -Path "$dllDir\BatteryManagementContract.dll" -ErrorAction SilentlyContinue
    Add-Type -Path "$dllDir\BatteryInformationContract.dll" -ErrorAction SilentlyContinue
    Add-Type -Path "$dllDir\IdeaBatteryAgent.dll" -ErrorAction Stop
}
$batAgent = [IdeaNotebookAddin.BatteryAgent]::GetInstance()

$tokens1 = $null; $errors1 = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($MainScript, [ref]$tokens1, [ref]$errors1)
Assert-Check "1.1" "AST Parse CheDoDiHoc_CuuHo.ps1" ($errors1.Count -eq 0) "$($errors1.Count) errors" "0 errors"

$tokens2 = $null; $errors2 = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($BaseScript, [ref]$tokens2, [ref]$errors2)
Assert-Check "1.2" "AST Parse baseline_setup.ps1" ($errors2.Count -eq 0) "$($errors2.Count) errors" "0 errors"

$bkObj = Get-Content $BackupJson -Raw | ConvertFrom-Json
Assert-Check "1.3" "baseline_backup.json valid non-empty JSON" ($null -ne $bkObj -and $null -ne $bkObj.Timestamp -and $bkObj.PowerSettings.Count -ge 8) "Timestamp=$($bkObj.Timestamp), PowerSettings=$($bkObj.PowerSettings.Count)" "Valid JSON with >=8 PowerSettings"

$irisDesktop = Test-Path "C:\Users\Admin\Desktop\TOI UU PUBG IRIS XE.lnk"
$irisBackup  = Test-Path (Join-Path $ProjectDir "backup\TOI UU PUBG IRIS XE.lnk")
Assert-Check "1.4" "TOI UU PUBG IRIS XE.lnk moved to backup\" ((-not $irisDesktop) -and $irisBackup) "Desktop=$irisDesktop, Backup=$irisBackup" "Desktop=False, Backup=True"

$batPath = "C:\Users\Admin\Desktop\Che Do Di Hoc & Cuu Ho.bat"
$batRaw = if (Test-Path $batPath) { Get-Content $batPath -Raw } else { "" }
Assert-Check "1.5" "Desktop launcher points to CheDoDiHoc_CuuHo.ps1" ((Test-Path $batPath) -and ($batRaw -match 'CheDoDiHoc_CuuHo\.ps1')) "BatExists=$(Test-Path $batPath)" "Points to CheDoDiHoc_CuuHo.ps1"

$preBri = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness
$protectedList = @('node', 'python', 'pythonw', 'browser', 'steam', 'goodbyedpi', 'EVKey64', 'FnHotkeyUtility')
$preProcs = @{}
foreach ($pn in $protectedList) {
    $p = Get-Process -Name $pn -ErrorAction SilentlyContinue
    $preProcs[$pn] = if ($p) { @($p).Count } else { 0 }
}
$preVantageSvc = (Get-Service -Name 'LenovoVantageService').Status.ToString()
$npxFilesPre   = @(Get-ChildItem "$env:LOCALAPPDATA\npm-cache\_npx" -Recurse -File -ErrorAction SilentlyContinue).Count
$cacheFilesPre = @(Get-ChildItem "$env:USERPROFILE\.cache" -Recurse -File -ErrorAction SilentlyContinue).Count

$statusOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -Status) -join "`n"
$hasStatusFields = ($statusOut -match 'mV') -and ($statusOut -match '°C') -and ($statusOut -match 'Chế độ Sạc') -and ($statusOut -match 'RAM Trống') -and ($statusOut -match 'DỰ BÁO THỜI LƯỢNG PIN') -and ($statusOut -match 'GỢI Ý HÀNH ĐỘNG TIẾP THEO')
Assert-Check "2.0" "Mode -Status telemetry, runtime estimates, and Smart Advisor" $hasStatusFields "Matched all 6 telemetry & Smart Advisor sections" "Battery %, mV, °C, Charge Mode, RAM, runtime estimates, Smart Advisor"

$null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -DiHoc
$boost1 = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' 'be337238-0d82-4146-a960-4f3749d470c7'
$freq1  = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '75b0ae3f-bce0-45a7-8c89-c9611c25e100'
$epp1   = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'
$es1    = Get-PowerCfgHexAndDec 'de830923-a562-41af-a086-e3a2c6bad2da' 'e69653ca-cf7f-4f05-aa73-cb833fa90ad4'
$wifi1  = Get-PowerCfgHexAndDec '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1' '12bbebe6-58d6-4636-95bb-3217ef867c1a'
$bri1   = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness

Assert-Check "2.1a" "Mode [1] -DiHoc DC PERFBOOSTMODE & AC PERFBOOSTMODE" ($boost1.DCDec -eq 0 -and $boost1.ACDec -eq 4) "DC=$($boost1.DCHex) ($($boost1.DCDec)), AC=$($boost1.ACHex) ($($boost1.ACDec))" "DC=0x00000000 (0), AC=0x00000004 (4)"
Assert-Check "2.1b" "Mode [1] -DiHoc DC PROCFREQMAX" ($freq1.DCDec -eq 2400) "$($freq1.DCHex) ($($freq1.DCDec) MHz)" "0x00000960 (2400 MHz)"
Assert-Check "2.1c" "Mode [1] -DiHoc DC PERFEPP" ($epp1.DCDec -eq 90) "$($epp1.DCHex) ($($epp1.DCDec)%)" "0x0000005a (90%)"
Assert-Check "2.1d" "Mode [1] -DiHoc DC ESBATTTHRESHOLD" ($es1.DCDec -eq 100) "$($es1.DCHex) ($($es1.DCDec)%)" "0x00000064 (100%)"
Assert-Check "2.1e" "Mode [1] -DiHoc DC Wireless Adapter Saving" ($wifi1.DCDec -eq 3) "$($wifi1.DCHex) ($($wifi1.DCDec))" "0x00000003 (3)"
Assert-Check "2.1f" "Mode [1] -DiHoc Brightness 20%" ($bri1 -eq 20) "${bri1}%" "20%"

$null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -DiHocUltra
$cores2 = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' 'ea062031-0e34-4ff1-9b6d-eb1059334028'
$freq2  = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '75b0ae3f-bce0-45a7-8c89-c9611c25e100'
$epp2   = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'
$ccPol  = if (Test-Path 'HKCU:\Software\Policies\CocCoc\Browser') { Get-ItemProperty -Path 'HKCU:\Software\Policies\CocCoc\Browser' -ErrorAction SilentlyContinue } else { Get-ItemProperty -Path 'HKCU:\Software\CocCoc\Browser' -ErrorAction SilentlyContinue }
$bri2   = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness
$rtAfterUltra = Get-Content $RuntimeJson -Raw | ConvertFrom-Json

Assert-Check "2.2a" "Mode [2] -DiHocUltra DC CPMAXCORES" ($cores2.DCDec -eq 50) "$($cores2.DCHex) ($($cores2.DCDec)%)" "0x00000032 (50%)"
Assert-Check "2.2b" "Mode [2] -DiHocUltra DC PROCFREQMAX" ($freq2.DCDec -eq 1700) "$($freq2.DCHex) ($($freq2.DCDec) MHz)" "0x000006a4 (1700 MHz)"
Assert-Check "2.2c" "Mode [2] -DiHocUltra DC PERFEPP" ($epp2.DCDec -eq 100) "$($epp2.DCHex) ($($epp2.DCDec)%)" "0x00000064 (100%)"
Assert-Check "2.2d" "Mode [2] -DiHocUltra CocCoc Efficiency & BatterySaver Policies" ($ccPol.HighEfficiencyModeEnabled -eq 1 -and $ccPol.BatterySaverModeAvailability -eq 1) "HighEfficiency=$($ccPol.HighEfficiencyModeEnabled), BatterySaver=$($ccPol.BatterySaverModeAvailability)" "1, 1"
Assert-Check "2.2e" "Mode [2] -DiHocUltra Brightness 12% & PriorBrightness preserved" ($bri2 -eq 12 -and $rtAfterUltra.PriorBrightness -eq $preBri) "Current=${bri2}%, SavedPrior=$($rtAfterUltra.PriorBrightness)%" "Current=12%, SavedPrior=${preBri}%"

$null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -SacDay100
$cm3 = $batAgent.GetBatteryChargeMode()
$bi3 = $batAgent.GetBatteryInformation().BatteryInformationList[0]
Assert-Check "2.3" "Mode [3] -SacDay100 IdeaBatteryAgent Normal (0)" ($cm3.BatteryChargeMode.ToString() -eq 'Normal' -and [int]$cm3.BatteryChargeMode -eq 0 -and $bi3.IsExpressCharging -eq $false) "Mode=$($cm3.BatteryChargeMode) ($([int]$cm3.BatteryChargeMode)), IsExpressCharging=$($bi3.IsExpressCharging)" "Mode=Normal (0), IsExpressCharging=False"

$null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -VeNha
$cm4    = $batAgent.GetBatteryChargeMode()
$bi4    = $batAgent.GetBatteryInformation().BatteryInformationList[0]
$cores4 = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' 'ea062031-0e34-4ff1-9b6d-eb1059334028'
$freq4  = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '75b0ae3f-bce0-45a7-8c89-c9611c25e100'
$boost4 = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' 'be337238-0d82-4146-a960-4f3749d470c7'
$bri4   = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness
$vc4    = Get-CimInstance Win32_VideoController | Select-Object -First 1
$guard4 = (Get-ScheduledTask -TaskName 'PUBGWirelessAndHzGuard').State.ToString()

Assert-Check "2.4a" "Mode [4] -VeNha IdeaBatteryAgent Storage (1)" ($cm4.BatteryChargeMode.ToString() -eq 'Storage' -and [int]$cm4.BatteryChargeMode -eq 1 -and $bi4.IsExpressCharging -eq $false) "Mode=$($cm4.BatteryChargeMode) ($([int]$cm4.BatteryChargeMode)), IsExpressCharging=$($bi4.IsExpressCharging)" "Mode=Storage (1), IsExpressCharging=False"
Assert-Check "2.4b" "Mode [4] -VeNha PowerCfg Restored (Cores 100%, Freq 3500MHz, AC Boost 4)" ($cores4.DCDec -eq 100 -and $freq4.DCDec -eq 3500 -and $boost4.ACDec -eq 4) "DCCores=$($cores4.DCHex) ($($cores4.DCDec)%), DCFreq=$($freq4.DCHex) ($($freq4.DCDec)), ACBoost=$($boost4.ACHex) ($($boost4.ACDec))" "DCCores=0x64 (100%), DCFreq=0xdac (3500), ACBoost=0x4 (4)"
Assert-Check "2.4c" "Mode [4] -VeNha Brightness Restored & Display 2560x1600 @ 60Hz" ($bri4 -eq $preBri -and $vc4.CurrentHorizontalResolution -eq 2560 -and $vc4.CurrentVerticalResolution -eq 1600 -and $vc4.CurrentRefreshRate -eq 60) "Bri=${bri4}%, Res=$($vc4.CurrentHorizontalResolution)x$($vc4.CurrentVerticalResolution) @ $($vc4.CurrentRefreshRate)Hz" "Bri=${preBri}%, Res=2560x1600 @ 60Hz"
Assert-Check "2.4d" "Mode [4] -VeNha \PUBGWirelessAndHzGuard Running" ($guard4 -eq 'Running') "State=$guard4" "State=Running"

$sw5 = [Diagnostics.Stopwatch]::StartNew()
$ramOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -CuuHoRAM) -join "`n"
$sw5.Stop()
$internalMs = if ($ramOut -match 'Hoàn tất trong (\d+) ms') { [int]$matches[1] } else { 9999 }
Assert-Check "2.5" "Mode [5] -CuuHoRAM < 2000ms & zero errors" ($internalMs -lt 2000 -and $LASTEXITCODE -eq 0) "Internal=${internalMs}ms, TotalProcess=$($sw5.ElapsedMilliseconds)ms, ExitCode=$LASTEXITCODE" "Internal < 2000ms, ExitCode=0"

$allProcsIntact = $true
$procSummary = @()
foreach ($pn in $protectedList) {
    $p = Get-Process -Name $pn -ErrorAction SilentlyContinue
    $cnt = if ($p) { @($p).Count } else { 0 }
    if ($preProcs[$pn] -gt 0 -and $cnt -eq 0) { $allProcsIntact = $false }
    $procSummary += "${pn}:$cnt"
}
$postVantageSvc = (Get-Service -Name 'LenovoVantageService').Status.ToString()
if ($postVantageSvc -ne 'Running') { $allProcsIntact = $false }
$procSummary += "LenovoVantageService:$postVantageSvc"
Assert-Check "3.1" "Protected Processes & Services 100% Intact" $allProcsIntact ($procSummary -join ", ") "All active protected processes & LenovoVantageService Running"

$npxFilesPost   = @(Get-ChildItem "$env:LOCALAPPDATA\npm-cache\_npx" -Recurse -File -ErrorAction SilentlyContinue).Count
$cacheFilesPost = @(Get-ChildItem "$env:USERPROFILE\.cache" -Recurse -File -ErrorAction SilentlyContinue).Count
Assert-Check "3.2" "Protected Caches (_npx & .cache) 100% Intact" ($npxFilesPost -eq $npxFilesPre -and $cacheFilesPost -eq $cacheFilesPre -and $npxFilesPost -gt 0 -and $cacheFilesPost -gt 0) "_npx=$npxFilesPost files, .cache=$cacheFilesPost files" "_npx=$npxFilesPre files, .cache=$cacheFilesPre files"

$failed = @($results | Where-Object { $_.Status -ne 'PASS' }).Count
Write-Host "`n=== VERIFICATION SUMMARY: $($results.Count - $failed)/$($results.Count) PASSED, $failed FAILED ===" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
if ($failed -gt 0) { exit 1 }

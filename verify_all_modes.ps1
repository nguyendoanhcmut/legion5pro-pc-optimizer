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
$preChargeMode = $batAgent.GetBatteryChargeMode().BatteryChargeMode.ToString()
$preRuntimeRaw = if (Test-Path $RuntimeJson) { [System.IO.File]::ReadAllText($RuntimeJson, [System.Text.Encoding]::UTF8) } else { $null }
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
$cm3  = $batAgent.GetBatteryChargeMode()
$bi3  = $batAgent.GetBatteryInformation().BatteryInformationList[0]
$wmi3 = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus
$cr3Ok = (-not $wmi3.PowerOnline) -or ($bi3.RemainingPercent -ge 98) -or ($wmi3.ChargeRate -gt 0)
Assert-Check "2.3" "Mode [3] -SacDay100 IdeaBatteryAgent Normal (0) & WMI ChargeRate > 0" ($cm3.BatteryChargeMode.ToString() -eq 'Normal' -and [int]$cm3.BatteryChargeMode -eq 0 -and $bi3.IsExpressCharging -eq $false -and $cr3Ok) "Mode=$($cm3.BatteryChargeMode) ($([int]$cm3.BatteryChargeMode)), ChargeRate=$($wmi3.ChargeRate) mW, IsExpressCharging=$($bi3.IsExpressCharging)" "Mode=Normal (0), ChargeRate > 0 mW (when AC & <98%), IsExpressCharging=False"

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

$bedTask = Get-ScheduledTask -TaskPath '\' -TaskName 'LegionBedtimeBatteryReminder' -ErrorAction SilentlyContinue
$bedXml  = if ($bedTask) { Export-ScheduledTask -TaskPath '\' -TaskName 'LegionBedtimeBatteryReminder' } else { '' }
$bedOk   = ($null -ne $bedTask) -and
           ($bedTask.State.ToString() -eq 'Ready') -and
           ($bedXml -match '<LogonType>InteractiveToken</LogonType>') -and
           ($bedXml -match 'T22:15:00') -and
           ($bedXml -match '<StartWhenAvailable>true</StartWhenAvailable>') -and
           ($bedXml -match '<DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>') -and
           ($bedXml -match '<StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>') -and
           ($bedXml -match '<ExecutionTimeLimit>PT4H</ExecutionTimeLimit>') -and
           ($bedXml -match '<MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>') -and
           ($bedXml -match '-WindowStyle Hidden') -and
           ($bedXml -match '-BedtimePrompt')
Assert-Check "4.1" "Scheduled Task \LegionBedtimeBatteryReminder (22:15 InteractiveToken)" $bedOk "State=$($bedTask.State), Logon=$($bedTask.Principal.LogonType)" "Ready, InteractiveToken, 22:15 Daily, PT4H, IgnoreNew, -BedtimePrompt"

$testSteamKey = 'HKCU:\Software\PcOptimizerVerify\Steam'
New-Item -Path "$testSteamKey\Apps\578080" -Force | Out-Null
New-ItemProperty -Path $testSteamKey -Name 'RunningAppID' -Value 578080 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path "$testSteamKey\Apps\578080" -Name 'Name' -Value 'PUBG: BATTLEGROUNDS' -PropertyType String -Force | Out-Null
$gameSimOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -TestBedtimePrompt -AutoSelectForTest 3 -SteamRegistryPathOverride $testSteamKey) -join "`n"
Remove-Item -Path 'HKCU:\Software\PcOptimizerVerify' -Recurse -Force -ErrorAction SilentlyContinue
$gameSimJson = if ($gameSimOut -match 'BEDTIME_PROMPT_RESULT=(\{.+\})') { $matches[1] | ConvertFrom-Json } else { $null }
Assert-Check "4.2" "Steam RunningAppID (578080) Game Detection Logic" ($null -ne $gameSimJson -and $gameSimJson.GameCheckRunning -eq $true -and $gameSimJson.GameCheckSummary -match '578080') "Running=$($gameSimJson.GameCheckRunning), Summary=$($gameSimJson.GameCheckSummary)" "Running=True, Summary matches AppID 578080"

$waitProc = Start-Process -FilePath 'powershell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MainScript`" -TestBedtimePrompt -AutoSelectForTest 3 -SimulateGameWaitMs 2600" -PassThru
Start-Sleep -Milliseconds 1900
$waitProc.Refresh()
$waitWsMB = [math]::Round($waitProc.WorkingSet64 / 1MB, 2)
$waitProc.WaitForExit(8000) | Out-Null
Assert-Check "4.3" "Game-Wait Loop Trimmed Working Set < 8 MB" ($waitWsMB -gt 0 -and $waitWsMB -lt 8.0) "${waitWsMB} MB" "< 8.0 MB"

$briBeforeBed = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness
$swB1 = [Diagnostics.Stopwatch]::StartNew()
$b1Out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -TestBedtimePrompt -AutoSelectForTest 1) -join "`n"
$swB1.Stop()
$b1Json   = if ($b1Out -match 'BEDTIME_PROMPT_RESULT=(\{.+\})') { $matches[1] | ConvertFrom-Json } else { $null }
$b1Boost  = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' 'be337238-0d82-4146-a960-4f3749d470c7'
$b1Freq   = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '75b0ae3f-bce0-45a7-8c89-c9611c25e100'
$b1Epp    = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'
$b1Wifi   = Get-PowerCfgHexAndDec '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1' '12bbebe6-58d6-4636-95bb-3217ef867c1a'
$b1Es     = Get-PowerCfgHexAndDec 'de830923-a562-41af-a086-e3a2c6bad2da' 'e69653ca-cf7f-4f05-aa73-cb833fa90ad4'
$b1Bri    = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness
$b1Wmi    = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus
$b1Bi     = $batAgent.GetBatteryInformation().BatteryInformationList[0]
$b1CrOk   = (-not $b1Wmi.PowerOnline) -or ($b1Bi.RemainingPercent -ge 98) -or ($b1Json.VerifiedChargeRateMW -gt 0)
$b1Ok     = ($swB1.ElapsedMilliseconds -lt 13000) -and
            ($b1Json.PostChargeMode -eq 'Normal') -and
            $b1CrOk -and
            ($b1Json.IsExpressCharging -eq $false) -and
            ($b1Json.PreArmedCampusMode -eq 'Standard') -and
            ($b1Boost.DCDec -eq 0 -and $b1Freq.DCDec -eq 2400 -and $b1Epp.DCDec -eq 90 -and $b1Wifi.DCDec -eq 3 -and $b1Es.DCDec -eq 100) -and
            ($b1Bri -eq $briBeforeBed)
Assert-Check "4.4" "Bedtime [1] Standard (Normal 100%, WMI ChargeRate > 0, DC 2400MHz, AC Bri Untouched)" $b1Ok "Elapsed=$($swB1.ElapsedMilliseconds)ms, Charge=$($b1Json.PostChargeMode), ChargeRate=$($b1Json.VerifiedChargeRateMW)mW, DCFreq=$($b1Freq.DCDec), Bri=${b1Bri}% (Before=${briBeforeBed}%)" "<13000ms (incl EC soft-start), Normal, ChargeRate>0mW, DC=2400MHz, Bri=${briBeforeBed}%"

$retHomeOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -CheckReturnHome) -join "`n"
Assert-Check "4.5" "Return-Home Safety Guard (-CheckReturnHome when ChargeMode=Normal)" ($retHomeOut -match 'Lưu ý: Máy đang mở sạc 100% từ lần đi học trước') "WarningMatched=$($retHomeOut -match 'Lưu ý: Máy đang mở sạc 100%')" "Displays 100% Return-Home lock-back reminder"

$swB2 = [Diagnostics.Stopwatch]::StartNew()
$b2Out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -TestBedtimePrompt -AutoSelectForTest 2) -join "`n"
$swB2.Stop()
$b2Json   = if ($b2Out -match 'BEDTIME_PROMPT_RESULT=(\{.+\})') { $matches[1] | ConvertFrom-Json } else { $null }
$b2Cores  = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' 'ea062031-0e34-4ff1-9b6d-eb1059334028'
$b2Freq   = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '75b0ae3f-bce0-45a7-8c89-c9611c25e100'
$b2Epp    = Get-PowerCfgHexAndDec '54533251-82be-4824-96c1-47b60b740d00' '36687f9e-e3a5-4dbf-b1dc-15eb381c6863'
$b2CcPol  = Get-ItemProperty -Path 'HKCU:\Software\CocCoc\Browser' -ErrorAction SilentlyContinue
$b2Bri    = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness
$b2CrOk   = (-not $b1Wmi.PowerOnline) -or ($b1Bi.RemainingPercent -ge 98) -or ($b2Json.VerifiedChargeRateMW -gt 0)
$b2Ok     = ($swB2.ElapsedMilliseconds -lt 5000) -and
            ($b2Json.ReturnHomeBanner -eq $true) -and
            ($b2Json.PostChargeMode -eq 'Normal') -and
            $b2CrOk -and
            ($b2Json.PreArmedCampusMode -eq 'Ultra') -and
            ($b2Cores.DCDec -eq 50 -and $b2Freq.DCDec -eq 1700 -and $b2Epp.DCDec -eq 100) -and
            ($b2CcPol.HighEfficiencyModeEnabled -eq 1 -and $b2CcPol.BatterySaverModeAvailability -eq 1) -and
            ($b2Bri -eq $briBeforeBed)
Assert-Check "4.6" "Bedtime [2] Ultra (ReturnHomeBanner, WMI ChargeRate > 0, DC 50% Cores 1700MHz, CocCoc=1, Bri Untouched)" $b2Ok "Elapsed=$($swB2.ElapsedMilliseconds)ms, Banner=$($b2Json.ReturnHomeBanner), ChargeRate=$($b2Json.VerifiedChargeRateMW)mW, DCCores=$($b2Cores.DCDec)%, DCFreq=$($b2Freq.DCDec), Bri=${b2Bri}%, PreArmed=$($b2Json.PreArmedCampusMode)" "<5000ms, Banner=True, ChargeRate>0mW, DCCores=50%, DCFreq=1700, Bri=${briBeforeBed}%, PreArmed=Ultra"

$swBT = [Diagnostics.Stopwatch]::StartNew()
$btOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -TestBedtimePrompt -AutoSelectForTest Timeout) -join "`n"
$swBT.Stop()
$btJson = if ($btOut -match 'BEDTIME_PROMPT_RESULT=(\{.+\})') { $matches[1] | ConvertFrom-Json } else { $null }
Assert-Check "4.7" "Bedtime Timeout Default (< 3s -> Locks Storage 60% & PreArmed=None)" ($swBT.ElapsedMilliseconds -lt 3000 -and $btJson.PostChargeMode -eq 'Storage' -and $btJson.PreArmedCampusMode -eq 'None') "Elapsed=$($swBT.ElapsedMilliseconds)ms, Charge=$($btJson.PostChargeMode), PreArmed=$($btJson.PreArmedCampusMode)" "<3000ms, Charge=Storage, PreArmed=None"

$swB3 = [Diagnostics.Stopwatch]::StartNew()
$b3Out = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -TestBedtimePrompt -AutoSelectForTest 3) -join "`n"
$swB3.Stop()
$b3Json = if ($b3Out -match 'BEDTIME_PROMPT_RESULT=(\{.+\})') { $matches[1] | ConvertFrom-Json } else { $null }
$null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -VeNha
$finalCm  = $batAgent.GetBatteryChargeMode().BatteryChargeMode.ToString()
$finalBri = [int](Get-CimInstance -Namespace root\WMI -ClassName WmiMonitorBrightness).CurrentBrightness
Assert-Check "4.8" "Bedtime [3] & Final -VeNha Restore (< 3s, Locked Storage 60%, Original Brightness)" ($swB3.ElapsedMilliseconds -lt 3000 -and $b3Json.PostChargeMode -eq 'Storage' -and $finalCm -eq 'Storage' -and $finalBri -eq $preBri) "Elapsed=$($swB3.ElapsedMilliseconds)ms, FinalCharge=$finalCm, FinalBri=${finalBri}%" "<3000ms, FinalCharge=Storage, FinalBri=${preBri}%"

$nowCheck = Get-Date
$expectedNightDate = if ($nowCheck.Hour -lt 4) { $nowCheck.Date.AddDays(-1).ToString('yyyy-MM-dd') } else { $nowCheck.Date.ToString('yyyy-MM-dd') }
$rtGuard = Get-Content $RuntimeJson -Raw | ConvertFrom-Json
$rtGuard | Add-Member -NotePropertyName LastBedtimePromptDate -NotePropertyValue $expectedNightDate -Force
$rtGuard | ConvertTo-Json -Depth 4 | Set-Content -Path $RuntimeJson -Encoding UTF8
$swGuard = [Diagnostics.Stopwatch]::StartNew()
$guardOut = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -BedtimePrompt) -join "`n"
$swGuard.Stop()
$rtGuard.LastBedtimePromptDate = ''
$rtGuard | ConvertTo-Json -Depth 4 | Set-Content -Path $RuntimeJson -Encoding UTF8
Assert-Check "4.9" "Once-Per-Night Date Guard (00:00-03:59 Night Cycle Rollover)" ($swGuard.ElapsedMilliseconds -lt 2000 -and [string]::IsNullOrWhiteSpace($guardOut)) "NightDate=$expectedNightDate, Elapsed=$($swGuard.ElapsedMilliseconds)ms, OutputLen=$($guardOut.Length)" "Exits silently in <2000ms with 0 UI when NightCycleDate already prompted"

# CRITICAL: Preserve user's pre-test runtime_state.json and BatteryChargeMode (never clobber active Normal 100% charge!)
if ($null -ne $preRuntimeRaw) {
    [System.IO.File]::WriteAllText($RuntimeJson, $preRuntimeRaw, (New-Object System.Text.UTF8Encoding($false)))
}
if ($preChargeMode -eq 'Normal') {
    $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $MainScript -SacDay100
}
$restoredCm  = $batAgent.GetBatteryChargeMode().BatteryChargeMode.ToString()
$restoredWmi = Get-CimInstance -Namespace root\WMI -ClassName BatteryStatus
$restoredBi  = $batAgent.GetBatteryInformation().BatteryInformationList[0]
$restoredCrOk = if ($preChargeMode -eq 'Normal' -and $restoredWmi.PowerOnline -and $restoredBi.RemainingPercent -lt 98) { $restoredWmi.ChargeRate -gt 0 } else { $true }
Assert-Check "4.10" "User Pre-Test ChargeMode Preserved ($preChargeMode)" ($restoredCm -eq $preChargeMode -and $restoredCrOk) "RestoredMode=$restoredCm, ChargeRate=$($restoredWmi.ChargeRate) mW, Current=$($restoredBi.Current) mA" "RestoredMode=$preChargeMode (with ChargeRate > 0 mW when Normal)"

$failed = @($results | Where-Object { $_.Status -ne 'PASS' }).Count
Write-Host "`n=== VERIFICATION SUMMARY: $($results.Count - $failed)/$($results.Count) PASSED, $failed FAILED ===" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
if ($failed -gt 0) { exit 1 }

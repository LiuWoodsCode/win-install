<# PowerShell Startup Repair clone (hardened) #>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Always define this so catch blocks can safely reference it
$script:LogFile = $null

function Write-Section { param([string]$Text) Write-Host "`n==== $Text ====" }
function Write-Log {
    param([string]$Message)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss.fff')
    $line = "[$timestamp] $Message"
    Write-Host $line
    if ($script:LogFile) { Add-Content -Path $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue }
}

function Invoke-External {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [int]$SuccessCode = 0,
        [switch]$IgnoreExitCode
    )
    $argsString = ($ArgumentList -join ' ')
    Write-Log "EXEC: $FilePath $argsString"
    if ($DryRun) { return @{ ExitCode = 0; Output = @(); Error = @() } }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $argsString
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    if ($stdout) { $stdout.TrimEnd("`r", "`n").Split("`n") | ForEach-Object { Write-Log "OUT: $_" } }
    if ($stderr) { $stderr.TrimEnd("`r", "`n").Split("`n") | ForEach-Object { Write-Log "ERR: $_" } }
    $code = $p.ExitCode
    Write-Log "EXIT: $code"

    if (-not $IgnoreExitCode -and $code -ne $SuccessCode) {
        throw "Command failed ($code): $FilePath $argsString"
    }
    return @{ ExitCode = $code; Output = $stdout; Error = $stderr }
}

function Get-Volumes {
    Get-CimInstance -ClassName Win32_Volume |
    Where-Object { $_.DriveType -in 2, 3 } |
    Sort-Object -Property DriveLetter
}

function Test-PathExists {
    param([string]$Root, [string[]]$RelativePaths)
    foreach ($rel in $RelativePaths) {
        try {
            if (-not (Test-Path -LiteralPath (Join-Path $Root $rel))) { return $false }
        }
        catch {
            # Provider / mount flukes—treat as not found
            return $false
        }
    }
    return $true
}

function Find-WindowsInstallation {
    Write-Section "Discover Windows installations"
    $candidates = @()

    foreach ($v in (Get-Volumes)) {
        try {
            $dl = $v.DriveLetter
            if (-not $dl) { continue }

            # Normalize "C:" -> "C"
            $letter = ($dl -replace ':$', '').ToUpper()

            # Sanity: single A–Z only
            if ($letter.Length -ne 1 -or $letter -notmatch '^[A-Z]$') {
                Write-Log "Skipping volume with unusual letter '$dl'."
                continue
            }

            # Ensure a PSDrive actually exists for that letter
            if (-not (Get-PSDrive -Name "$letter" -ErrorAction SilentlyContinue)) {
                Write-Log "Skipping ${letter}: (no PSDrive mounted)."
                continue
            }

            $root = "${letter}:\"

            # Probe for Windows install
            $isWin = Test-PathExists -Root $root -RelativePaths @(
                'Windows\System32\config\SYSTEM',
                'Windows\explorer.exe'
            )
            if ($isWin) {
                $score = 0
                if (Test-Path -LiteralPath (Join-Path $root 'Windows\WinSxS')) { $score += 2 }
                if (Test-Path -LiteralPath (Join-Path $root 'Program Files')) { $score += 1 }
                $candidates += [pscustomobject]@{
                    DriveLetter = $letter
                    Root        = $root
                    Label       = $v.Label
                    FileSystem  = $v.FileSystem
                    CapacityGB  = [math]::Round(($v.Capacity / 1GB), 2)
                    FreeGB      = [math]::Round(($v.FreeSpace / 1GB), 2)
                    Score       = $score
                }
                Write-Log "Windows candidate: $root (FS=$($v.FileSystem), Label=$($v.Label)) Score=$score"
            }
        }
        catch {
            Write-Log "Probe error on volume $($v.DeviceID): $($_.Exception.Message)"
        }
    }

    if (-not $candidates) { throw "No Windows installation found." }
    $best = $candidates | Sort-Object Score -Descending | Select-Object -First 1
    Write-Log "Selected Windows: $($best.Root) (Label=$($best.Label), FS=$($best.FileSystem))"
    return $best
}

function Detect-BootStyle {
    try {
        $espLetter = Get-EfiSystemPartition
        if ($espLetter) { return @{ Style = 'UEFI'; EfiLetter = $espLetter } }
    }
    catch { Write-Log "ESP detection failed: $($_.Exception.Message)" }
    return @{ Style = 'Legacy'; EfiLetter = $null }
}

function Assert-NotBitLockerLocked {
    param([string]$TargetRoot)
    try {
        $drive = $TargetRoot.Substring(0, 1)
        $res = Invoke-External -FilePath 'manage-bde.exe' -ArgumentList @('-status', "$($drive):\") -IgnoreExitCode
        if ($res.Output -match 'Lock Status:\s+Locked') {
            if (-not $Force) {
                throw "BitLocker volume $($drive): is LOCKED. Unlock it before repairing."
            }
            else {
                Write-Log "WARNING: BitLocker volume appears locked; proceeding due to -Force."
            }
        }
    }
    catch {
        Write-Log "BitLocker status check issue (manage-bde may be unavailable): $($_.Exception.Message)"
    }
}

function Repair-FileSystem {
    param([string]$TargetRoot)
    Write-Section "CHKDSK (filesystem repair)"
    $drive = $TargetRoot.Substring(0, 1)
    Invoke-External -FilePath 'chkdsk.exe' -ArgumentList @("$($drive):", '/F') -IgnoreExitCode
}

function Repair-PendingUpdates {
    param([string]$TargetRoot)
    Write-Section "DISM revert pending actions (stuck updates)"
    $dismArgs = @("/image:$TargetRoot", '/cleanup-image', '/revertpendingactions')
    Invoke-External -FilePath 'dism.exe' -ArgumentList $dismArgs -IgnoreExitCode
}

function Repair-SystemFiles {
    param([string]$TargetRoot)
    Write-Section "SFC offline"
    $offBoot = $TargetRoot.Substring(0, 3) # e.g. C:\
    $offWin = Join-Path $TargetRoot 'Windows'
    $sfcArgs = @('/scannow', "/offbootdir=$offBoot", "/offwindir=$offWin")
    Invoke-External -FilePath 'sfc.exe' -ArgumentList $sfcArgs -IgnoreExitCode

    Write-Section "DISM component store repair (if possible)"
    $dismArgs = @("/image:$TargetRoot", '/cleanup-image', '/restorehealth')
    Invoke-External -FilePath 'dism.exe' -ArgumentList $dismArgs -IgnoreExitCode
}

function Repair-BootUEFI {
    param([string]$TargetRoot, [string]$EfiLetter)
    Write-Section "Rebuild UEFI boot files (bcdboot)"
    $winPath = Join-Path $TargetRoot 'Windows'
    if ($EfiLetter) {
        Invoke-External -FilePath 'bcdboot.exe' -ArgumentList @("$winPath", '/s', "$($EfiLetter):", '/f', 'UEFI') -IgnoreExitCode
    }
    else {
        Invoke-External -FilePath 'bcdboot.exe' -ArgumentList @("$winPath", '/f', 'UEFI') -IgnoreExitCode
    }
    Invoke-External -FilePath 'bootrec.exe' -ArgumentList @('/rebuildbcd') -IgnoreExitCode
}

function Repair-BootLegacy {
    param([string]$TargetRoot)
    Write-Section "Repair Legacy/MBR boot (bootrec/bootsect)"
    Invoke-External -FilePath 'bootrec.exe'  -ArgumentList @('/fixmbr')      -IgnoreExitCode
    Invoke-External -FilePath 'bootrec.exe'  -ArgumentList @('/fixboot')     -IgnoreExitCode
    Invoke-External -FilePath 'bootrec.exe'  -ArgumentList @('/scanos')      -IgnoreExitCode
    Invoke-External -FilePath 'bootrec.exe'  -ArgumentList @('/rebuildbcd')  -IgnoreExitCode
    Invoke-External -FilePath 'bootsect.exe' -ArgumentList @('/nt60', 'SYS', '/mbr') -IgnoreExitCode
}

function Initialize-Logging {
    param([string]$TargetRoot)
    try {
        $logDir = Join-Path $TargetRoot 'Windows\System32\LogFiles\Srt'
        if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
        $script:LogFile = Join-Path $logDir ("PSStartRep-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Write-Host "Logging to: $script:LogFile"
        if (-not $DryRun) { New-Item -ItemType File -Force -Path $script:LogFile | Out-Null }
    }
    catch {
        Write-Host "Could not create Srt log path on target; using temp."
        $script:LogFile = Join-Path $env:TEMP ("PSStartRep-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        if (-not $DryRun) { New-Item -ItemType File -Force -Path $script:LogFile | Out-Null }
    }
}

function Show-Summary {
    param($BootInfo, [string]$TargetRoot)
    Write-Section "SUMMARY"
    Write-Log "Windows root: $TargetRoot"
    Write-Log "Boot style: $($BootInfo.Style)"
    if ($BootInfo.EfiLetter) { Write-Log "ESP: $($BootInfo.EfiLetter):\" }
    Write-Log "Log file: $script:LogFile"
    Write-Log "Check SrtTrail: $(Join-Path $TargetRoot 'Windows\System32\LogFiles\Srt\SrtTrail.txt') (if present)."
}

# =========================
#            MAIN
# =========================

try {
    Write-Section "PowerShell Startup Repair (PS-StartRep)"
    Write-Host "Those who don’t automate are doomed to repeat themselves. ⚡"

    $win = Find-WindowsInstallation
    Initialize-Logging -TargetRoot $win.Root
    Write-Log "BEGIN PS-StartRep"

    Assert-NotBitLockerLocked -TargetRoot $win.Root

    Repair-FileSystem     -TargetRoot $win.Root
    Repair-PendingUpdates -TargetRoot $win.Root
    Repair-SystemFiles    -TargetRoot $win.Root

    $boot = Detect-BootStyle
    Write-Log "Detected boot style: $($boot.Style)"
    if ($boot.Style -eq 'UEFI') {
        Repair-BootUEFI -TargetRoot $win.Root -EfiLetter $boot.EfiLetter
    }
    else {
        Repair-BootLegacy -TargetRoot $win.Root
    }

    Show-Summary -BootInfo $boot -TargetRoot $win.Root
    Write-Log "END PS-StartRep (Success)"
    Write-Section "DONE"
    Write-Host "If the system still fails to boot, review the log above and $(Join-Path $win.Root 'Windows\System32\LogFiles\Srt\SrtTrail.txt')."
}
catch {
    Write-Section "ERROR"
    Write-Host $_.Exception.Message
    if ($script:LogFile) { Write-Log "FAILED: $($_.Exception.Message)" }
    exit 1
}



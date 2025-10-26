<#
.SYNOPSIS
Build or update the PixelSetup WinPE image.

.DESCRIPTION
Supports:
 - Full rebuild (-FullRebuild)
 - Incremental rebuild (default)
 - Optional autostart (-Autostart)
 - Custom source path for PixelSetup files (-SourcePath, defaults to $PSScriptRoot)
 - Optional features via -Features (currently supports: pixelrecovery, which includes the 'recovery' folder)

.EXAMPLE
.\Build-PixelSetup.ps1
.\Build-PixelSetup.ps1 -FullRebuild
.\Build-PixelSetup.ps1 -FullRebuild -Autostart
.\Build-PixelSetup.ps1 -SourcePath "D:\MyPixelSetup"
.\Build-PixelSetup.ps1 -Features pixelrecovery
#>

param(
    [switch]$FullRebuild,
    [switch]$Autostart,
    [string]$SourcePath = $PSScriptRoot,
    [ValidateSet("amd64","x64","x86","arm","arm64","ia64","axp64","woa")][string]$Arch = "amd64",
    [ValidateSet("pixelrecovery", "runner", "hiddenconhost")][string[]]$Features = @()
)

# --- CONFIGURATION ---
# Normalize common aliases (user may pass x64 etc.)
switch ($Arch.ToLower()) {
    'x64'  { $Arch = 'amd64' }
    'amd64'{ $Arch = 'amd64' }
    'x86'  { $Arch = 'x86' }
    'arm'  { $Arch = 'arm' }
    'arm64'{ $Arch = 'arm64' }
    default { $Arch = $Arch }
}

$WinPEWorkDir = "C:\WinPE_25H2"
$MountDir = "$WinPEWorkDir\mount"
$SrcDir = (Resolve-Path $SourcePath).Path
$OverlayDir = Join-Path $SrcDir "overlay"
$PwshDir = Join-Path $SrcDir "pwsh"
$MainScript = Join-Path $SrcDir "MainNew copy.ps1"
$ISOPath = "$WinPEWorkDir\PixelSetup.iso"
$AdkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$OCPath = "$AdkRoot\Windows Preinstallation Environment\$Arch\WinPE_OCs"
$CopypePath = "$AdkRoot\Windows Preinstallation Environment\copype.cmd"
$MakePEPath = "$AdkRoot\Windows Preinstallation Environment\MakeWinPEMedia.cmd"
$DeploymentTools = "$AdkRoot\Deployment Tools"


if (-not $PixelSetupSource) {
    if ($PSScriptRoot) {
        $PixelSetupSource = $PSScriptRoot
    }
    else {
        Write-Host "[!] PixelSetup source not specified and cannot detect script path. Please provide -PixelSetupSource <path>." -ForegroundColor Red
        exit 1
    }
}

function Write-Info($msg) { Write-Host "[*] $msg" -ForegroundColor Cyan }
function Write-OK($msg) { Write-Host "[+] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-ErrorAndExit($msg) { Write-Host "[X] $msg" -ForegroundColor Red; exit 1 }

# --- VALIDATION ---------------------------------------------------------------
Write-Info "Validating environment..."
if (-not (Test-Path $MainScript)) { Write-ErrorAndExit "Missing 'MainNew copy.ps1' in $SrcDir." }
if (-not (Test-Path $PwshDir)) { Write-ErrorAndExit "Missing 'pwsh' folder (must contain PowerShell Core)." }
if (-not (Test-Path (Join-Path $PwshDir "pwsh.exe"))) { Write-ErrorAndExit "Missing 'pwsh.exe' inside 'pwsh' folder." }
if (-not (Test-Path $OCPath)) { Write-ErrorAndExit "WinPE Optional Components not found at '$OCPath'." }
if (-not (Test-Path $CopypePath)) { Write-ErrorAndExit "copype.cmd not found at '$CopypePath'." }
if (-not (Test-Path $MakePEPath)) { Write-ErrorAndExit "MakeWinPEMedia.cmd not found at '$MakePEPath'." }
Write-OK "Environment validation passed."

# --- BUILD NUMBER MANAGEMENT ---
$BuildNumberFile = Join-Path $SrcDir ".BUILDNO"
$CurrentBuildNo = 0
if (Test-Path $BuildNumberFile) {
    $rawBuildNo = (Get-Content $BuildNumberFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
    if ($rawBuildNo) {
        try { $CurrentBuildNo = [int]$rawBuildNo } catch { $CurrentBuildNo = 0 }
    }
}
$NewBuildNo = $CurrentBuildNo + 1
Set-Content -Path $BuildNumberFile -Value $NewBuildNo -Encoding ASCII
$script:BuildNo = $NewBuildNo.ToString()
Write-Info "Incremented build number to $script:BuildNo."

# --- COPY FILES FUNCTION ------------------------------------------------------
function Copy-PixelSetupFiles {
    param([string]$MountDir)

    Write-Info "Copying PixelSetup files from $SrcDir..."
    $TargetDir = Join-Path $MountDir "PixelSetup"
    New-Item -ItemType Directory -Force -Path $TargetDir 
    Get-ChildItem $SrcDir -Exclude "overlay", "pwsh" | ForEach-Object {
        Copy-Item $_.FullName -Destination $TargetDir -Recurse -Force
    }

    if (Test-Path $OverlayDir) {
        Write-Info "Preparing ACLs for existing targets in mount dir..."
        Get-ChildItem -Path $OverlayDir -Recurse -Force | ForEach-Object {
            $rel = $_.FullName.Substring($OverlayDir.Length).TrimStart('\','/')
            if (-not $rel) { return }
            $dest = Join-Path $MountDir $rel

            if (Test-Path $dest) {
                # Only adjust ACLs for files (don't modify directory ACLs)
                if (-not $_.PSIsContainer) {
                    try {
                        & takeown.exe /F "$dest" /A | Out-Null
                        & icacls.exe "$dest" /grant "*S-1-5-32-544:F" /C | Out-Null  # Administrators
                        & icacls.exe "$dest" /grant "$($env:USERNAME):F" /C | Out-Null
                    }
                    catch {
                        Write-Warn "ACL adjust failed for $dest - $_"
                    }
                }
            }
        }

        Write-Info "Applying overlay files..."
        Copy-Item "$OverlayDir\*" $MountDir -Recurse -Force
    }

    if (Test-Path $PwshDir) {
        Write-Info "Copying PwshCore contents..."
        $PwshTarget = Join-Path $MountDir "PwshCore"
        New-Item -ItemType Directory -Force -Path $PwshTarget 
        Copy-Item "$PwshDir\*" $PwshTarget -Recurse -Force
    }

    # Copy wimlib tools if present
    $WimlibSource = Join-Path $SourcePath "wimlib"
    $WimlibTarget = Join-Path $MountDir "wimlib"
    if (Test-Path $WimlibSource) {
        Write-Host "Copying wimlib tools..."
        Copy-Item -Recurse -Force -Path $WimlibSource -Destination $WimlibTarget
    }
    else {
        Write-Warning "No wimlib directory found at $WimlibSource — skipping."
    }

    # Include optional features
    if ($Features -and $Features -contains 'pixelrecovery') {
        Write-Info "Including feature 'pixelrecovery' (copying recovery folder)..."
        $RecoverySource = Join-Path $SrcDir 'recovery'
        $RecoveryTarget = Join-Path $MountDir 'recovery'
        if (Test-Path $RecoverySource) {
            New-Item -ItemType Directory -Force -Path $RecoveryTarget | Out-Null
            Copy-Item -Recurse -Force -Path "$RecoverySource\*" -Destination $RecoveryTarget
            Write-OK "'recovery' folder copied."
        } else {
            Write-Warn "Feature 'pixelrecovery' requested but no 'recovery' folder at $RecoverySource — skipping."
        }
    }

    Write-Info "Configuring startnet.cmd..."
    $Startnet = Join-Path $MountDir "Windows\System32\startnet.cmd"
    if ($Autostart) {
        if ($Features -and $Features -contains 'runner') {
            Write-Info "Including feature 'runner' (Use experimental launcher script to do prepwork)..."
            if ($Features -and $Features -contains 'hiddenconhost') {
                Write-Info "Including feature 'hiddenconhost' (launch PowerShell with hidden console)..." 
                $StartupCmd = @"
X:\PwshCore\pwsh.exe -ExecutionPolicy Bypass -File "X:\PixelSetup\launch.ps1" -MakeHidden
"@
            }
            else {
                $StartupCmd = @"
X:\PwshCore\pwsh.exe -ExecutionPolicy Bypass -NoExit -File "X:\PixelSetup\launch.ps1"
"@
            }
        }
        else {
            $StartupCmd = @"
wpeinit
X:\PwshCore\pwsh.exe -ExecutionPolicy Bypass -NoExit -File "X:\PixelSetup\MainNew copy.ps1"
"@
        }
    }
    else {
        $StartupCmd = "wpeinit"
    }

    Set-Content -Path $Startnet -Value $StartupCmd -Encoding ASCII
    Write-OK "startnet.cmd configured (Autostart: $Autostart)"

    # Write PixelPE build information into the offline SOFTWARE hive so WinPE can expose it at HKLM\SOFTWARE\PixelPE
    $SoftwareHive = Join-Path $MountDir "Windows\System32\config\SOFTWARE"
    if (Test-Path $SoftwareHive) {
        Write-Info "Updating SOFTWARE hive with PixelPE build info..."
        $hiveKey = "HKLM\PixelPE_SOFT"
        try {
            # Load the offline SOFTWARE hive
            & reg.exe load $hiveKey $SoftwareHive | Out-Null

            # Build number already incremented earlier
            $BuildNo = $script:BuildNo
            if (-not $BuildNo) { $BuildNo = "0" }

            # Construct a PixelPE build tag with lab in format {gitbranch}(username) and a timestamp <YYMMDD-HHMM>
            $TimeStamp = (Get-Date).ToString("yyMMdd-HHmm")

            # Default values
            $Branch = "unknown"
            $User = $env:USERNAME

            # Try to read git branch and git user.name if git is available and $SrcDir is a repo
            if (Get-Command git -ErrorAction SilentlyContinue) {
                try {
                    $gitBranch = (& git -C $SrcDir rev-parse --abbrev-ref HEAD 2>$null).Trim()
                    if ($gitBranch) { $Branch = $gitBranch }
                } catch {
                    # ignore failures, keep defaults
                }
            }

            # Compose BuildTag: <BuildNo>.<Arch>.<gitbranch>(<username>).<YYMMDD-HHMM>
            $BuildTag = "{0}.{1}.{2}({3}).{4}" -f $BuildNo, $Arch, $Branch, $User, $TimeStamp

            # Ensure PixelPE key exists and write values
            & reg.exe add "$hiveKey\PixelPE" /f | Out-Null
            & reg.exe add "$hiveKey\PixelPE" /v BuildNumber /t REG_SZ /d "$BuildNo" /f | Out-Null
            & reg.exe add "$hiveKey\PixelPE" /v BuildTag /t REG_SZ /d "$BuildTag" /f | Out-Null
            & reg.exe add "$hiveKey\PixelPE" /v SourcePath /t REG_SZ /d "$SrcDir" /f | Out-Null

            Write-OK "PixelPE registry values written: BuildNumber=$BuildNo, BuildTag=$BuildTag"
        }
        catch {
            Write-Warn "Failed to update registry hive: $_"
        }
        finally {
            # Unload hive if it was loaded
            try { & reg.exe unload $hiveKey | Out-Null } catch {}
        }
    }
    else {
        Write-Warn "SOFTWARE hive not found at $SoftwareHive — skipping registry update."
    }
}

# --- FULL REBUILD -------------------------------------------------------------
if ($FullRebuild) {
    Write-Info "Performing full rebuild..."
    if (Test-Path $WinPEWorkDir) {
        Write-Info "Cleaning up old build directory..."
        $isoFile = Join-Path $WinPEWorkDir "PixelSetup.iso"
        if (Test-Path $isoFile) {
            try { Remove-Item -Force $isoFile -ErrorAction Stop } catch { Write-Warn "Skipping locked ISO: $isoFile" }
        }
        try { Remove-Item -Recurse -Force $WinPEWorkDir -ErrorAction Stop } catch { Write-Warn "Partial cleanup, continuing..." }
    }

    Write-Info "Running copype from Deployment Tools..."
    Push-Location $DeploymentTools
    try {
        & $CopypePath $Arch $WinPEWorkDir
    }
    finally {
        Pop-Location
    }

    Write-Info "Mounting boot.wim..."
    Dism /Mount-Image /ImageFile:"$WinPEWorkDir\media\sources\boot.wim" /Index:1 /MountDir:"$MountDir" 

    Write-Info "Adding WinPE packages..."
    Dism /Add-Package /Image:$MountDir /PackagePath:"$OCPath\WinPE-WMI.cab" 
    Dism /Add-Package /Image:$MountDir /PackagePath:"$OCPath\WinPE-NetFX.cab" 
    Dism /Add-Package /Image:$MountDir /PackagePath:"$OCPath\WinPE-Scripting.cab" 
    Dism /Add-Package /Image:$MountDir /PackagePath:"$OCPath\WinPE-PowerShell.cab" 
    Dism /Add-Package /Image:$MountDir /PackagePath:"$OCPath\WinPE-StorageWMI.cab" 

    if (Test-Path "$OCPath\WinPE-EnhancedStorage.cab") { Dism /Add-Package /Image:$MountDir /PackagePath:"$OCPath\WinPE-EnhancedStorage.cab"  }
    if (Test-Path "$OCPath\WinPE-SecureStartup.cab") { Dism /Add-Package /Image:$MountDir /PackagePath:"$OCPath\WinPE-SecureStartup.cab"  }

    Copy-PixelSetupFiles -MountDir $MountDir
    Dism /Unmount-Image /MountDir:$MountDir /Commit 

    Write-Info "Building ISO..."
    Push-Location $DeploymentTools
    try {
        & $MakePEPath /ISO $WinPEWorkDir $ISOPath
    }
    finally {
        Pop-Location
    }

    Write-OK "Full rebuild complete! ISO ready at: $ISOPath"
    exit
}

# --- INCREMENTAL REBUILD ------------------------------------------------------
if (-not (Test-Path "$WinPEWorkDir\media\sources\boot.wim")) {
    Write-ErrorAndExit "No existing image found. Use -FullRebuild first."
}

Write-Info "Performing incremental update..."
Dism /Mount-Image /ImageFile:"$WinPEWorkDir\media\sources\boot.wim" /Index:1 /MountDir:"$MountDir" 
Copy-PixelSetupFiles -MountDir $MountDir
Dism /Unmount-Image /MountDir:$MountDir /Commit 

Write-Info "Building updated ISO..."
Push-Location $DeploymentTools
try {
    & $MakePEPath /ISO $WinPEWorkDir $ISOPath
}
finally {
    Pop-Location
}

Write-OK "Incremental build complete! ISO ready at: $ISOPath"

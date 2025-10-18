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
    [ValidateSet("pixelrecovery")][string[]]$Features = @()
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

# --- COPY FILES FUNCTION ------------------------------------------------------
function Copy-PixelSetupFiles {
    param([string]$MountDir)

    Write-Info "Copying PixelSetup files from $SrcDir..."
    $TargetDir = Join-Path $MountDir "PixelSetup"
    New-Item -ItemType Directory -Force -Path $TargetDir 
    Get-ChildItem -Path "$SrcDir\*" -Exclude "overlay", "pwsh" | ForEach-Object {
        Copy-Item $_.FullName -Destination $TargetDir -Recurse -Force
    }

    if (Test-Path $PwshDir) {
        Write-Info "Copying PwshCore contents..."
        $PwshTarget = Join-Path $MountDir "PwshCore"
        New-Item -ItemType Directory -Force -Path $PwshTarget 
        Copy-Item "$PwshDir\*" $PwshTarget -Recurse -Force
    }

    # Copy wimlib tools if present
    $WimlibSource = Join-Path $SrcDir "wimlib"
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
        $StartupCmd = @"
wpeinit
X:\PwshCore\pwsh.exe -ExecutionPolicy Bypass -NoExit -File "X:\PixelSetup\MainNew copy.ps1"
"@
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

            # Read build number from source root .BUILDNO if present
            $BuildNoFile = Join-Path $SrcDir ".BUILDNO"
            if (Test-Path $BuildNoFile) {
                $BuildNo = (Get-Content $BuildNoFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
                if (-not $BuildNo) { $BuildNo = "0" }
            }
            else {
                $BuildNo = "0"
            }

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

    # Apply overlay last so it overrides any files we created/modified above
    if (Test-Path $OverlayDir) {
        Write-Info "Applying overlay files..."
        Copy-Item "$OverlayDir\*" $MountDir -Recurse -Force
        Write-OK "Overlay files applied."
    } else {
        Write-Warn "No overlay directory found at $OverlayDir — skipping."
    }
}

# New helper to take ownership and grant full control for overlay targets that already exist in the mounted image
function Prepare-OverlayReplacements {
    param(
        [string]$MountDir,
        [string]$OverlayDir
    )

    if (-not (Test-Path $OverlayDir)) {
        Write-Warn "No overlay directory found at $OverlayDir — skipping permission pre-check."
        return
    }

    # Normalize overlay root so substring operations are reliable (ensure trailing slash for substring)
    $overlayRoot = (Get-Item $OverlayDir).FullName
    $overlayRoot = $overlayRoot.TrimEnd('\','/') + '\'

    Write-Info "Scanning overlay for existing targets to unlock (treating overlay root as drive root)..."
    $adminSid = "S-1-5-32-544" # Built-in Administrators
    $unlockedCount = 0

    # Process immediate children only so we can use icacls /T on directories (handles nested items efficiently)
    Get-ChildItem -Path $OverlayDir -Force | ForEach-Object {
        try {
            $item = $_

            # Relative path from overlay root is just the immediate child's name
            $rel = $item.Name
            $rel = $rel.Replace('/','\').TrimStart('\')

            # Construct corresponding path in the mounted image (treat overlay root as X:\)
            $target = Join-Path $MountDir $rel

            if (Test-Path $target) {
                $isDir = $item.PSIsContainer

                # Take ownership (use /R for directories)
                if ($isDir) {
                    & takeown.exe /F $target /A /D Y /R | Out-Null

                    # Grant using SID first; use /T to apply recursively
                    $sidGrant = "*$($adminSid):(F)"
                    $icaclsOut = & icacls.exe $target /grant $sidGrant /C /T 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        & icacls.exe $target /grant "Administrators:(F)" /C /T | Out-Null
                    }
                } else {
                    & takeown.exe /F $target /A /D Y | Out-Null

                    $sidGrant = "*$($adminSid):(F)"
                    $icaclsOut = & icacls.exe $target /grant $sidGrant /C 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        & icacls.exe $target /grant "Administrators:(F)" /C | Out-Null
                    }
                }

                $unlockedCount++
            }
        } catch {
            Write-Warn "Failed to adjust ACLs on target for overlay item '$($_.FullName)': $_"
            # still count it so the summary reflects discovered items
            $unlockedCount++
        }
    }

    Write-OK "Unlocked $unlockedCount overlay items for replacement."
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
        & $CopypePath $Arch $WinPEWorkDir | Out-Null
    }
    finally {
        Pop-Location
    }

    Write-Info "Mounting boot.wim..."
    Dism /Mount-Image /ImageFile:"$WinPEWorkDir\media\sources\boot.wim" /Index:1 /MountDir:"$MountDir" 
    Prepare-OverlayReplacements -MountDir $MountDir -OverlayDir $OverlayDir

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
Prepare-OverlayReplacements -MountDir $MountDir -OverlayDir $OverlayDir
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

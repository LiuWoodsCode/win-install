<#
.SYNOPSIS
Build or update the PixelSetup WinPE image.

.DESCRIPTION
Supports:
 - Full rebuild (-FullRebuild)
 - Incremental rebuild (default)
 - Optional autostart (-Autostart)
 - Custom source path for PixelSetup files (-SourcePath, defaults to $PSScriptRoot)

.EXAMPLE
.\Build-PixelSetup.ps1
.\Build-PixelSetup.ps1 -FullRebuild
.\Build-PixelSetup.ps1 -FullRebuild -Autostart
.\Build-PixelSetup.ps1 -SourcePath "D:\MyPixelSetup"
#>

param(
    [switch]$FullRebuild,
    [switch]$Autostart,
    [string]$SourcePath = $PSScriptRoot
)

# --- CONFIGURATION ---
$Arch = "amd64"
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
    Get-ChildItem $SrcDir -Exclude "overlay", "pwsh" | ForEach-Object {
        Copy-Item $_.FullName -Destination $TargetDir -Recurse -Force
    }

    if (Test-Path $OverlayDir) {
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

<# 
    PixelSetup PowerShell Installer (Proof of Concept)
    --------------------------------------------------
    Version: 0.4-dev (wimlib Edition)

    ⚠️  WARNING ⚠️
    Extremely early prototype for educational use only.
    • Supports **UEFI + GPT** only (except in Test Mode)
    • Will ERASE the target disk (unless Test Mode is chosen)
    • No warranty or liability for any data loss or damage.

    Requires:
      - wimlib-imagex.exe in PATH or same directory
      - Valid Windows install.wim or install.esd
#>

Import-Module $PSScriptRoot\DismImage.psm1 -Force
Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "   PIXELSETUP - WINDOWS INSTALLER PROOF OF CONCEPT (v0.4)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  EARLY EXPERIMENTAL SCRIPT – USE AT YOUR OWN RISK" -ForegroundColor Red
Write-Host "    Supports UEFI only.  Will ERASE the selected disk." -ForegroundColor Red
Write-Host ""
Pause

# --- Verify wimlib availability ---
$wimlib = ".\wimlib\wimlib-imagex.exe"
if (-not (Get-Command $wimlib -ErrorAction SilentlyContinue)) {
    Write-Error "wimlib-imagex.exe not found. Please place it in the same directory or PATH."
    exit 1
}

# --- STEP 1: Locate Image File ---
$defaultImagePath = "D:\sources\install.wim"
$imagePath = Read-Host "Enter path to install.wim/esd [`$defaultImagePath`]"
if ([string]::IsNullOrWhiteSpace($imagePath)) { $imagePath = $defaultImagePath }

if (-not (Test-Path $imagePath)) {
    Write-Error "Could not find image file at $imagePath."
    exit 1
}

# --- STEP 2: List Available Images ---
Write-Host "`nEnumerating image indexes..."
Get-WimlibInfo $imagePath -ExpandImages | Select-Object -Property Index, Name, Build, TotalBytes| Format-Table -AutoSize

[int]$index = Read-Host "Select index number to install"

# --- STEP 3: Choose WinRE Mode ---
Write-Host "`nWinRE / Recovery options:"
Write-Host " [1] Full setup (create and enable WinRE)"
Write-Host " [2] Skip WinRE (keep Recovery partition empty)"
Write-Host " [3] No Recovery partition at all"
[int]$reMode = Read-Host "Select option [1-3]"
if ($reMode -lt 1 -or $reMode -gt 3) { $reMode = 1 }

# --- STEP 4: Disk or Test Target Selection ---
Write-Host "`nAvailable install targets:"
Write-Host " [T] C:\Test (safe for testing - no disk changes)"
Get-Disk | Format-Table Number, FriendlyName, Size, PartitionStyle

$target = Read-Host "Enter disk number to install to, or 'T' for Test Mode"

$testMode = $false
if ($target -match "^[Tt]") {
    $testMode = $true
    Write-Host "`n>>> Test Mode enabled. The image will be applied to C:\Test." -ForegroundColor Cyan
    if (-not (Test-Path "C:\Test")) { New-Item -ItemType Directory -Path "C:\Test" | Out-Null }
}
else {
    [int]$diskNum = $target
    if (-not (Get-Disk -Number $diskNum -ErrorAction SilentlyContinue)) {
        Write-Error "Invalid disk selection."
        exit 1
    }
}

# --- STEP 5: Partitioning or Test Prep ---
if (-not $testMode) {
    Write-Host "`n>>> Wiping and partitioning disk $diskNum..."

    if ($reMode -eq 3) {
        $diskpartScript = @"
select disk $diskNum
clean
convert gpt
create partition efi size=512
format quick fs=fat32 label="System"
assign letter=S
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter=C
exit
"@
    }
    else {
        $diskpartScript = @"
select disk $diskNum
clean
convert gpt
create partition efi size=512
format quick fs=fat32 label="System"
assign letter=S
create partition msr size=16
create partition primary
format quick fs=ntfs label="Windows"
assign letter=C
shrink minimum=750
create partition primary
format quick fs=ntfs label="Recovery"
assign letter=R
set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
gpt attributes=0x8000000000000001
exit
"@
    }

    $diskpartScript | Out-File "$env:TEMP\partition.txt" -Encoding ascii
    diskpart /s "$env:TEMP\partition.txt"
}
else {
    Write-Host "`nSkipping DiskPart — operating in Test Mode."
}

# --- STEP 6: Apply Windows Image via wimlib ---
if ($testMode) {
    $applyDir = "C:\Test"
}
else {
    $applyDir = "C:\"
}

Write-Host "`nApplying Windows image (Index $index) to $applyDir using wimlib..."
$arguments = "apply `"$imagePath`" $index `"$applyDir`" /verbose"
Start-Process -FilePath $wimlib -ArgumentList $arguments -NoNewWindow -Wait

# --- STEP 7: Boot Setup (Skipped in Test Mode) ---
if (-not $testMode) {
    Write-Host "`nConfiguring UEFI boot files..."
    bcdboot C:\Windows /s S: /f UEFI | Out-Host
}
else {
    Write-Host "`nSkipping BCDBoot — Test Mode active."
}

# --- STEP 8: WinRE Handling ---
if (-not $testMode) {
    switch ($reMode) {
        1 {
            Write-Host "`nConfiguring WinRE..."
            New-Item -ItemType Directory -Force -Path "R:\Recovery\WindowsRE" | Out-Null
            Copy-Item "C:\Windows\System32\Recovery\Winre.wim" "R:\Recovery\WindowsRE\" -Force
            reagentc /setreimage /path R:\Recovery\WindowsRE /target C:\Windows
            reagentc /enable
            reagentc /info
        }
        2 {
            Write-Host "`nLeaving Recovery partition empty (WinRE disabled)."
            reagentc /disable
        }
        3 {
            Write-Host "`nNo Recovery partition created – WinRE unavailable."
            reagentc /disable
        }
    }
}
else {
    Write-Host "`nSkipping WinRE configuration — Test Mode active."
}

# --- STEP 9: Finish ---
Write-Host "`nInstallation complete!" -ForegroundColor Green
if ($testMode) {
    Write-Host "Test Mode installation simulated to C:\Test."
    Write-Host "Inspect this directory to verify image contents."
}
else {
    Write-Host "Remove installation media and reboot into OOBE."
    Write-Host "Type 'wpeutil reboot' to restart."
}

<# 
    PixelSetup PowerShell Installer (GUI) — based on original v0.4-dev (wimlib Edition)

    ⚠️  WARNING ⚠️
    Extremely early prototype for educational use only.
    • Supports **UEFI + GPT** only (except in Test Mode)
    • Will ERASE the target disk (unless Test Mode is chosen)
    • No warranty or liability for any data loss or damage.

    Requires:
      - wimlib-imagex.exe in PATH or same directory
      - Valid Windows install.wim or install.esd
#>

param(
    [switch]$ForceReFsSupport
)

# Imports
Import-Module $PSScriptRoot\DismImage.psm1 -Force
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Helpers
function Test-Admin {
    $wp = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Ensure-STA {
    if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
        [System.Windows.Forms.MessageBox]::Show("This script must run in STA mode. Launch PowerShell with -STA.", "PixelSetup", 'OK', 'Error') | Out-Null
        exit 1
    }
}
# NEW: Detect if running in WinPE (MiniNT key exists)
function Test-WinPE {
    return $true
    # try { return Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\MiniNT' } catch { return $false }
}

Ensure-STA
if (-not (Test-Admin)) {
    [System.Windows.Forms.MessageBox]::Show("This tool requires Administrator privileges.", "PixelSetup", 'OK', 'Error') | Out-Null
    exit 1
}

$Global:IsWinPE = Test-WinPE
# State
$wimlib = Join-Path ($PSScriptRoot) "wimlib\wimlib-imagex.exe"
if (-not $PSScriptRoot) {
    # Fallback if $PSScriptRoot not populated
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $wimlib = Join-Path $scriptDir "wimlib\wimlib-imagex.exe"
}
$defaultImagePath = "D:\sources\install.wim"

# UI
$form = New-Object System.Windows.Forms.Form
$form.Text = "Windows Installer (win-install)"
$form.Size = New-Object System.Drawing.Size(980,700)
$form.StartPosition = 'CenterScreen'

$lblHdr = New-Object System.Windows.Forms.Label
$lblHdr.Text = "INSTALL WINDOWS (EXPERIMENTAL, NOT FINAL UI)"
$lblHdr.AutoSize = $true
$lblHdr.Font = New-Object System.Drawing.Font("Segoe UI",11,[Drawing.FontStyle]::Bold)
$lblHdr.Location = New-Object System.Drawing.Point(12,12)
$form.Controls.Add($lblHdr)

$gbImage = New-Object System.Windows.Forms.GroupBox
$gbImage.Text = "1) Image"
$gbImage.Location = New-Object System.Drawing.Point(12,45)
$gbImage.Size = New-Object System.Drawing.Size(940,130)
$form.Controls.Add($gbImage)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "install.wim/esd path:"
$lblPath.AutoSize = $true
$lblPath.Location = New-Object System.Drawing.Point(12,28)
$gbImage.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(140,25)
$txtPath.Size = New-Object System.Drawing.Size(650,23)
$txtPath.Text = $defaultImagePath
$gbImage.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(800,24)
$btnBrowse.Size = New-Object System.Drawing.Size(120,25)
$gbImage.Controls.Add($btnBrowse)

$btnList = New-Object System.Windows.Forms.Button
$btnList.Text = "List Images"
$btnList.Location = New-Object System.Drawing.Point(800,60)
$btnList.Size = New-Object System.Drawing.Size(120,25)
$gbImage.Controls.Add($btnList)

$lblIndex = New-Object System.Windows.Forms.Label
$lblIndex.Text = "Select index:"
$lblIndex.AutoSize = $true
$lblIndex.Location = New-Object System.Drawing.Point(12,65)
$gbImage.Controls.Add($lblIndex)

$cmbIndexes = New-Object System.Windows.Forms.ComboBox
$cmbIndexes.DropDownStyle = 'DropDownList'
$cmbIndexes.Location = New-Object System.Drawing.Point(140,62)
$cmbIndexes.Size = New-Object System.Drawing.Size(650,23)
$gbImage.Controls.Add($cmbIndexes)

# NEW: File system selection (default NTFS; ReFS enabled when supported)
$lblFs = New-Object System.Windows.Forms.Label
$lblFs.Text = "Windows volume file system:"
$lblFs.AutoSize = $true
$lblFs.Location = New-Object System.Drawing.Point(12,95)
$gbImage.Controls.Add($lblFs)

$rbFsNtfs = New-Object System.Windows.Forms.RadioButton
$rbFsNtfs.Text = "NTFS (default)"
$rbFsNtfs.Location = New-Object System.Drawing.Point(200,93)
$rbFsNtfs.AutoSize = $true
$rbFsNtfs.Checked = $true
$gbImage.Controls.Add($rbFsNtfs)

$rbFsRefs = New-Object System.Windows.Forms.RadioButton
$rbFsRefs.Text = "ReFS (Windows 11 22H2+)"
$rbFsRefs.Location = New-Object System.Drawing.Point(330,93)
$rbFsRefs.AutoSize = $true
$rbFsRefs.Enabled = $false
$gbImage.Controls.Add($rbFsRefs)

$gbWinRE = New-Object System.Windows.Forms.GroupBox
$gbWinRE.Text = "2) WinRE / Recovery"
$gbWinRE.Location = New-Object System.Drawing.Point(12,185)
$gbWinRE.Size = New-Object System.Drawing.Size(460,120)
$form.Controls.Add($gbWinRE)

$rbReFull = New-Object System.Windows.Forms.RadioButton
$rbReFull.Text = "Full setup (create and enable WinRE)"
$rbReFull.Location = New-Object System.Drawing.Point(12,25)
$rbReFull.AutoSize = $true
$rbReFull.Checked = $true
$gbWinRE.Controls.Add($rbReFull)

$rbReSkip = New-Object System.Windows.Forms.RadioButton
$rbReSkip.Text = "Skip WinRE (keep Recovery partition empty)"
$rbReSkip.Location = New-Object System.Drawing.Point(12,50)
$rbReSkip.AutoSize = $true
$gbWinRE.Controls.Add($rbReSkip)

$rbReNone = New-Object System.Windows.Forms.RadioButton
$rbReNone.Text = "No Recovery partition at all"
$rbReNone.Location = New-Object System.Drawing.Point(12,75)
$rbReNone.AutoSize = $true
$gbWinRE.Controls.Add($rbReNone)

$gbTarget = New-Object System.Windows.Forms.GroupBox
$gbTarget.Text = "3) Target"
$gbTarget.Location = New-Object System.Drawing.Point(492,185)
$gbTarget.Size = New-Object System.Drawing.Size(460,220)
$form.Controls.Add($gbTarget)

$cbTest = New-Object System.Windows.Forms.CheckBox
$cbTest.Text = "Test Mode (apply to C:\Test, no disk changes)"
$cbTest.Location = New-Object System.Drawing.Point(12,25)
$cbTest.AutoSize = $true
$gbTarget.Controls.Add($cbTest)

$btnRefreshDisks = New-Object System.Windows.Forms.Button
$btnRefreshDisks.Text = "Refresh Disks"
$btnRefreshDisks.Location = New-Object System.Drawing.Point(320,20)
$btnRefreshDisks.Size = New-Object System.Drawing.Size(120,25)
$gbTarget.Controls.Add($btnRefreshDisks)

$lvDisks = New-Object System.Windows.Forms.ListView
$lvDisks.Location = New-Object System.Drawing.Point(12,55)
$lvDisks.Size = New-Object System.Drawing.Size(428,150)
$lvDisks.View = 'Details'
$lvDisks.FullRowSelect = $true
$lvDisks.Columns.Add("Number",60) | Out-Null
$lvDisks.Columns.Add("FriendlyName",180) | Out-Null
$lvDisks.Columns.Add("Size (GB)",90) | Out-Null
$lvDisks.Columns.Add("Style",80) | Out-Null
$gbTarget.Controls.Add($lvDisks)

$gbActions = New-Object System.Windows.Forms.GroupBox
$gbActions.Text = "4) Actions"
$gbActions.Location = New-Object System.Drawing.Point(12,315)
$gbActions.Size = New-Object System.Drawing.Size(460,90)
$form.Controls.Add($gbActions)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install"
$btnInstall.Location = New-Object System.Drawing.Point(12,30)
$btnInstall.Size = New-Object System.Drawing.Size(140,35)
$gbActions.Controls.Add($btnInstall)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(170,30)
$btnClose.Size = New-Object System.Drawing.Size(140,35)
$gbActions.Controls.Add($btnClose)

# NEW: Repair button (WinPE only)
$btnRepair = New-Object System.Windows.Forms.Button
$btnRepair.Text = "Repair..."
$btnRepair.Location = New-Object System.Drawing.Point(330,30)
$btnRepair.Size = New-Object System.Drawing.Size(120,35)
$btnRepair.Enabled = $Global:IsWinPE
$gbActions.Controls.Add($btnRepair)

# NEW: Progress UI (two bars: current step and overall)
$gbProgress = New-Object System.Windows.Forms.GroupBox
$gbProgress.Text = "Progress"
$gbProgress.Location = New-Object System.Drawing.Point(12,415)
$gbProgress.Size = New-Object System.Drawing.Size(940,80)
$form.Controls.Add($gbProgress)

$lblStepName = New-Object System.Windows.Forms.Label
$lblStepName.Text = "Step: (ready)"
$lblStepName.AutoSize = $true
$lblStepName.Location = New-Object System.Drawing.Point(12,22)
$gbProgress.Controls.Add($lblStepName)

$pbStep = New-Object System.Windows.Forms.ProgressBar
$pbStep.Location = New-Object System.Drawing.Point(120,20)
$pbStep.Size = New-Object System.Drawing.Size(800,18)
$pbStep.Minimum = 0; $pbStep.Maximum = 100; $pbStep.Value = 0
$gbProgress.Controls.Add($pbStep)

$lblTotal = New-Object System.Windows.Forms.Label
$lblTotal.Text = "Overall: 0%"
$lblTotal.AutoSize = $true
$lblTotal.Location = New-Object System.Drawing.Point(12,50)
$gbProgress.Controls.Add($lblTotal)

$pbTotal = New-Object System.Windows.Forms.ProgressBar
$pbTotal.Location = New-Object System.Drawing.Point(120,48)
$pbTotal.Size = New-Object System.Drawing.Size(800,18)
$pbTotal.Minimum = 0; $pbTotal.Maximum = 100; $pbTotal.Value = 0
$gbProgress.Controls.Add($pbTotal)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
# MOVED DOWN to make room for progress group
$txtLog.Location = New-Object System.Drawing.Point(12,505)
$txtLog.Size = New-Object System.Drawing.Size(940,170)
$form.Controls.Add($txtLog)

# Logging helper
function Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("HH:mm:ss")
    $line = "[$ts] $Message"
    $txtLog.AppendText($line + [Environment]::NewLine)
}

# Core functions (adapt original steps)
function Ensure-Wimlib {
    param([string]$LocalPath)
    Log "Ensure-Wimlib: incoming path='$LocalPath'"
    if (Test-Path $LocalPath) {
        Log "Ensure-Wimlib: Found local bundled wimlib at '$LocalPath'"
        return $LocalPath
    }
    Log "Ensure-Wimlib: Local path missing, probing PATH..."
    $cmd = Get-Command "wimlib-imagex.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        Log "Ensure-Wimlib: Found in PATH at '$($cmd.Source)'"
        return $cmd.Source
    }
    Log "Ensure-Wimlib: NOT FOUND"
    throw "wimlib-imagex.exe not found. Place it in .\wimlib\ or add to PATH."
}

function Get-ImageList {
    param([string]$Path)
    Log "Get-ImageList: Path='$Path'"
    if (-not (Test-Path $Path)) { throw "Image file not found: $Path" }
    $fi = Get-Item $Path
    Log ("Get-ImageList: Size={0:N2} MB Extension={1}" -f ($fi.Length/1MB),$fi.Extension)
    $images = Get-WimlibInfo $Path -ExpandImages | Select-Object Index, Name, Build, TotalBytes
    Log "Get-ImageList: Retrieved $($images.Count) image record(s)."
    return $images
}

# NEW: Drive letter selection helpers
function Get-UsedDriveLetters {
    try {
        # Use DriveInfo to avoid reliance on Storage module
        return ([System.IO.DriveInfo]::GetDrives().Name | ForEach-Object { $_.Substring(0,1).ToUpper() })
    } catch {
        return @()
    }
}

function Get-PreferredOrRandomDriveLetter {
    param(
        [Parameter(Mandatory)][string]$Preferred,
        [string[]]$Exclude = @()
    )
    $used = (Get-UsedDriveLetters)
    # Avoid X: (commonly WinPE)
    $avoid = @('X') + $Exclude
    $preferredFree = ($used -notcontains $Preferred.ToUpper()) -and ($avoid -notcontains $Preferred.ToUpper())
    if ($preferredFree) { return $Preferred.ToUpper() }

    $all = "CDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray() | ForEach-Object { $_.ToString() }
    $free = $all | Where-Object { ($used -notcontains $_) -and ($avoid -notcontains $_) }
    if (-not $free -or $free.Count -eq 0) {
        # Fallback to something sane if everything looks used
        return "Z"
    }
    return Get-Random -InputObject $free
}

function Select-PartitionLetters {
    param([int]$ReMode)
    $efi = Get-PreferredOrRandomDriveLetter -Preferred 'S'
    $win = Get-PreferredOrRandomDriveLetter -Preferred 'C' -Exclude @($efi)
    $rec = $null
    if ($ReMode -ne 3) {
        $rec = Get-PreferredOrRandomDriveLetter -Preferred 'R' -Exclude @($efi,$win)
    }
    return [pscustomobject]@{
        Efi      = $efi
        Windows  = $win
        Recovery = $rec
    }
}

function Make-PartitionScript {
    param(
        [int]$DiskNumber,
        [int]$ReMode,
        [string]$FileSystem,  # "NTFS" or "ReFS"
        # NEW: letters to use (already ensured to be unique and free)
        [Parameter(Mandatory)][string]$EfiLetter,
        [Parameter(Mandatory)][string]$WindowsLetter,
        [string]$RecoveryLetter
    )
    Log "Make-PartitionScript: Disk=$DiskNumber ReMode=$ReMode (1=Full,2=SkipWinRE,3=NoRecovery) FS=$FileSystem Letters: EFI=$EfiLetter Windows=$WindowsLetter Recovery=$($RecoveryLetter ?? '<n/a>'):":
    $fsTag = if ($FileSystem -and $FileSystem.ToUpper() -eq 'REFS') { 'refs' } else { 'ntfs' }
    if ($ReMode -eq 3) {
        $script = @"
select disk $DiskNumber
clean
convert gpt
create partition efi size=512
format quick fs=fat32 label="System"
assign letter=$EfiLetter
create partition msr size=16
create partition primary
format quick fs=$fsTag label="Windows"
assign letter=$WindowsLetter
exit
"@
    } else {
        $script = @"
select disk $DiskNumber
clean
convert gpt
create partition efi size=512
format quick fs=fat32 label="System"
assign letter=$EfiLetter
create partition msr size=16
create partition primary
format quick fs=$fsTag label="Windows"
assign letter=$WindowsLetter
shrink minimum=750
create partition primary
format quick fs=ntfs label="Recovery"
assign letter=$RecoveryLetter
set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
gpt attributes=0x8000000000000001
exit
"@
    }
    Log "Make-PartitionScript: Generated script:`n$script"
    return $script
}

function Run-Diskpart {
    param([string]$ScriptContent)
    $temp = Join-Path $env:TEMP "partition.txt"
    Log "Run-Diskpart: Writing script to $temp (Length=$($ScriptContent.Length))"
    $ScriptContent | Out-File $temp -Encoding ascii
    Log "Run-Diskpart: Launching diskpart"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = diskpart /s $temp 2>&1
    $sw.Stop()
    $out | ForEach-Object { Log ("diskpart: $_") }
    Log ("Run-Diskpart: Completed in {0:N2}s OutputLines={1}" -f $sw.Elapsed.TotalSeconds, $out.Count)
}

# NEW (replaced): generic external process invoker with live log streaming (safe for GUI thread)
function Invoke-External {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$WorkingDirectory,
        # NEW: per-line callbacks
        [scriptblock]$OnStdOutLine,
        [scriptblock]$OnStdErrLine
    )
    Log ("Invoke-External: File='{0}' Args='{1}' WorkDir='{2}'" -f $FilePath, ($Arguments -join ' '), ($WorkingDirectory ?? "<inherit>"))
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $spl = @{
            FilePath = $FilePath
            ArgumentList = $Arguments
            PassThru = $true
            NoNewWindow = $true
            RedirectStandardOutput = $outFile
            RedirectStandardError  = $errFile
        }
        if ($WorkingDirectory) { $spl.WorkingDirectory = $WorkingDirectory }
        $proc = Start-Process @spl

        $loggedOut = 0
        $loggedErr = 0
        while (-not $proc.HasExited) {
            if (Test-Path $outFile) {
                $outLines = Get-Content -Path $outFile -ErrorAction SilentlyContinue
                for ($i=$loggedOut; $i -lt $outLines.Count; $i++) {
                    $line = $outLines[$i]
                    if ($line) { Log $line }
                    if ($OnStdOutLine -and $line) { & $OnStdOutLine $line }
                }
                $loggedOut = $outLines.Count
            }
            if (Test-Path $errFile) {
                $errLines = Get-Content -Path $errFile -ErrorAction SilentlyContinue
                for ($i=$loggedErr; $i -lt $errLines.Count; $i++) {
                    $line = $errLines[$i]
                    if ($line) { Log $line }
                    if ($OnStdErrLine -and $line) { & $OnStdErrLine $line }
                }
                $loggedErr = $errLines.Count
            }
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 150
        }

        # Final flush after exit
        foreach ($tuple in @(@($outFile, [ref]$loggedOut, $OnStdOutLine), @($errFile, [ref]$loggedErr, $OnStdErrLine))) {
            $file = $tuple[0]; $refIdx = $tuple[1]; $cb = $tuple[2]
            if (Test-Path $file) {
                $lines = Get-Content -Path $file -ErrorAction SilentlyContinue
                for ($i=$refIdx.Value; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]
                    if ($line) { Log $line }
                    if ($cb -and $line) { & $cb $line }
                }
                $refIdx.Value = $lines.Count
            }
        }

        $exit = $proc.ExitCode
        $sw.Stop()
        Log ("Invoke-External: ExitCode={0} Duration={1:N2}s StdOutLines={2} StdErrLines={3}" -f $exit,$sw.Elapsed.TotalSeconds,(Get-Content $outFile).Count,(Get-Content $errFile).Count)
        return $exit
    } finally {
        Remove-Item -Path $outFile,$errFile -ErrorAction SilentlyContinue
    }
}

function Apply-Image {
    param(
        [string]$WimlibPath,
        [string]$ImagePath,
        [int]$Index,
        [string]$ApplyDir
    )
    # REPLACED: per-phase steps instead of a single "Apply Image"
    try {
        if (-not (Test-Path $ApplyDir)) {
            Log "Apply-Image: Creating target directory $ApplyDir"
            New-Item -ItemType Directory -Force -Path $ApplyDir | Out-Null
        }
        Log "Apply-Image: Index=$Index Source='$ImagePath' Target='$ApplyDir'"

        # Map raw wimlib phase -> UI step name
        $phaseMap = @{
            'Creating files'              = 'Apply: Creating files'
            'Extracting file data'        = 'Apply: Extracting file data'
            'Applying metadata to files'  = 'Apply: Applying metadata to files'
        }
        $script:currentPhase = $null

        # Pre-start first phase so UI changes immediately
        $script:currentPhase = 'Creating files'
        Start-Step $phaseMap[$script:currentPhase]
        Update-StepProgress -Percent 0

        $onOut = {
            param($line)
            try {
                $m = [regex]::Match($line, '^(Creating files|Extracting file data|Applying metadata to files):.*\((\d+)%\)')
                if ($m.Success) {
                    $phaseRaw = $m.Groups[1].Value
                    $pctInPhase = [int]$m.Groups[2].Value
                    $stepName = $phaseMap[$phaseRaw]

                    if ($script:currentPhase -ne $phaseRaw) {
                        # Phase transition: end previous and start new
                        if ($script:currentPhase -and $phaseMap.ContainsKey($script:currentPhase)) {
                            End-Step $phaseMap[$script:currentPhase] "OK"
                        }
                        Start-Step $stepName
                        $script:currentPhase = $phaseRaw
                    }

                    Update-StepProgress -Percent $pctInPhase
                }
            } catch { }
        }

        $args = @("apply",$ImagePath,$Index.ToString(),$ApplyDir,"--verbose")
        Log "Apply-Image: Command: $WimlibPath $($args -join ' ')"
        $exit = Invoke-External -FilePath $WimlibPath -Arguments $args -WorkingDirectory (Split-Path -Parent $WimlibPath) -OnStdOutLine $onOut
        if ($exit -ne 0) { throw "wimlib apply failed (exit code $exit)" }
        if (-not (Test-Path (Join-Path $ApplyDir 'Windows'))) {
            throw "wimlib apply completed but Windows directory not found in target."
        }

        $fileCount = (Get-ChildItem -LiteralPath $ApplyDir -Recurse -Force -File -ErrorAction SilentlyContinue).Count
        Log "Apply-Image: Completed. Files=$fileCount"

        # Ensure last phase is closed with details, or fallback if no phase was detected
        if ($script:currentPhase -and $phaseMap.ContainsKey($script:currentPhase)) {
            End-Step $phaseMap[$script:currentPhase] "OK" "Files=$fileCount"
        } else {
            # Fallback: close all phases quickly to keep overall progress coherent
            foreach ($p in @('Creating files','Extracting file data','Applying metadata to files')) {
                Start-Step $phaseMap[$p]
                Update-StepProgress -Percent 100
                End-Step $phaseMap[$p] "OK" ($(if ($p -eq 'Applying metadata to files') { "Files=$fileCount" } else { $null }))
            }
        }
    } catch {
        if ($script:currentPhase -and $phaseMap.ContainsKey($script:currentPhase)) {
            End-Step $phaseMap[$script:currentPhase] "FAILED" $_.Exception.Message
        }
        throw
    }
}

function Setup-Boot {
    param(
        # NEW: dynamic letters
        [Parameter(Mandatory)][string]$WindowsLetter,
        [Parameter(Mandatory)][string]$EfiLetter
    )
    Start-Step "BCDBoot"
    try {
        $winPath = "$($WindowsLetter):\Windows"
        $efiPart = "$($EfiLetter):"
        Log "Setup-Boot: Configuring UEFI boot (bcdboot $winPath /s $efiPart /f UEFI)"
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $out = bcdboot $winPath /s $efiPart /f UEFI 2>&1
        $sw.Stop()
        $out | ForEach-Object { Log "bcdboot: $_" }
        Log ("Setup-Boot: Duration {0:N2}s" -f $sw.Elapsed.TotalSeconds)
        End-Step "BCDBoot" "OK"
    } catch {
        End-Step "BCDBoot" "FAILED" $_.Exception.Message
        throw
    }
}

function Configure-WinRE {
    param(
        [int]$ReMode,
        [bool]$TestMode,
        # NEW: dynamic letters
        [string]$WindowsLetter,
        [string]$RecoveryLetter
    )
    Start-Step "WinRE"
    try {
        if ($TestMode) { Log "WinRE: Skipping (Test Mode)"; End-Step "WinRE" "OK" "Skipped TestMode"; return }
        switch ($ReMode) {
            1 {
                Log "WinRE: Full setup"
                $recDir = "$($RecoveryLetter):\Recovery\WindowsRE"
                $srcWim = "$($WindowsLetter):\Windows\System32\Recovery\Winre.wim"
                New-Item -ItemType Directory -Force -Path $recDir | Out-Null
                Copy-Item $srcWim $recDir -Force
                foreach ($cmd in @(
                    "reagentc /setreimage /path $recDir /target $($WindowsLetter):\Windows",
                    "reagentc /enable",
                    "reagentc /info"
                )) {
                    Log "WinRE: $cmd"
                    (& cmd /c $cmd 2>&1) | ForEach-Object { Log "WinRE: $_" }
                }
                End-Step "WinRE" "OK" "Mode=Full"
            }
            2 {
                Log "WinRE: Disabling (empty Recovery partition)."
                (& cmd /c "reagentc /disable" 2>&1) | ForEach-Object { Log "WinRE: $_" }
                End-Step "WinRE" "OK" "Mode=SkipWinRE"
            }
            3 {
                Log "WinRE: No Recovery partition scenario."
                (& cmd /c "reagentc /disable" 2>&1) | ForEach-Object { Log "WinRE: $_" }
                End-Step "WinRE" "OK" "Mode=None"
            }
        }
    } catch {
        End-Step "WinRE" "FAILED" $_.Exception.Message
        throw
    }
}

function Refresh-Disks {
    Log "Refresh-Disks: Enumerating disks..."
    $lvDisks.Items.Clear()
    $disks = Get-Disk | Select-Object Number, FriendlyName, Size, PartitionStyle
    foreach ($d in $disks) {
        $sizeGB = [Math]::Round($d.Size/1GB,2)
        Log ("Refresh-Disks: Disk {0} '{1}' Size={2}GB Style={3}" -f $d.Number,$d.FriendlyName,$sizeGB,$d.PartitionStyle)
        $item = New-Object System.Windows.Forms.ListViewItem($d.Number.ToString())
        $null = $item.SubItems.Add($d.FriendlyName)
        $null = $item.SubItems.Add($sizeGB.ToString())
        $null = $item.SubItems.Add($d.PartitionStyle.ToString())
        $null = $lvDisks.Items.Add($item)
    }
    Log "Refresh-Disks: Total disks listed: $($disks.Count)"
}

# ==== Verbose step tracking additions ====
$Global:InstallSteps = @()
# NEW: planned step tracking for overall progress
$Global:PlannedSteps = @()
$Global:CurrentStepIndex = -1
$Global:CurrentStepName = $null

# NEW: progress helpers
function Initialize-Progress {
    param([string[]]$Steps)
    $Global:PlannedSteps = @($Steps)
    $Global:CurrentStepIndex = -1
    $Global:CurrentStepName = $null
    if ($pbStep) { $pbStep.Value = 0 }
    if ($pbTotal) { $pbTotal.Value = 0 }
    if ($lblStepName) { $lblStepName.Text = "Step: (ready)" }
    if ($lblTotal) { $lblTotal.Text = "Overall: 0%" }
}

function Update-TotalProgress {
    param([double]$CurrentStepPercent)
    try {
        $pct = 0
        if ($Global:PlannedSteps -and $Global:PlannedSteps.Count -gt 0 -and $Global:CurrentStepIndex -ge 0) {
            $pct = [Math]::Round((([double]$Global:CurrentStepIndex) + ($CurrentStepPercent/100.0)) / $Global:PlannedSteps.Count * 100)
        }
        $pct = [Math]::Max(0,[Math]::Min(100,[int]$pct))
        if ($pbTotal) { $pbTotal.Value = $pct }
        if ($lblTotal) { $lblTotal.Text = "Overall: $pct%" }
    } catch { }
}

function Update-StepProgress {
    param([double]$Percent)
    try {
        $p = [Math]::Max(0,[Math]::Min(100,[int][Math]::Round($Percent)))
        if ($pbStep) { $pbStep.Value = $p }
        if ($lblStepName -and $Global:CurrentStepName) {
            $lblStepName.Text = "Step: $($Global:CurrentStepName) ($p%)"
        }
        Update-TotalProgress -CurrentStepPercent $p
    } catch { }
}

function Start-Step {
    param([string]$Name)
    $step = [ordered]@{
        Name     = $Name
        Start    = Get-Date
        End      = $null
        Status   = "RUNNING"
        Details  = ""
        Duration = $null
    }
    $Global:InstallSteps += [PSCustomObject]$step
    Log "=== START STEP: $Name ==="

    # NEW: progress wiring
    $Global:CurrentStepName = $Name
    if ($lblStepName) { $lblStepName.Text = "Step: $Name (0%)" }
    if ($pbStep) { $pbStep.Value = 0 }
    if ($Global:PlannedSteps) {
        $idx = [Array]::IndexOf($Global:PlannedSteps, $Name)
        if ($idx -ge 0) { $Global:CurrentStepIndex = $idx } else { $Global:CurrentStepIndex++ }
    }
    Update-TotalProgress -CurrentStepPercent 0
}

function End-Step {
    param(
        [string]$Name,
        [string]$Status = "OK",
        [string]$Details
    )
    # NEW: ensure step progress hits 100% at end of the step
    if ($Name -eq $Global:CurrentStepName) { Update-StepProgress -Percent 100 }

    $step = $Global:InstallSteps | Where-Object { $_.Name -eq $Name -and -not $_.End } | Select-Object -Last 1
    if ($step) {
        $step.End = Get-Date
        $step.Status = $Status
        if ($Details) { $step.Details = $Details }
        $step.Duration = "{0:N2}s" -f (($step.End - $step.Start).TotalSeconds)
        Log ("=== END STEP: {0} | Status: {1} | Duration: {2} ===" -f $step.Name,$step.Status,$step.Duration)
        if ($Details) { Log ("--- Details: {0}" -f $Details) }
    } else {
        Log "WARNING: End-Step called for '$Name' but no running step found."
    }
}

function Write-EnvironmentInfo {
    Log "Environment: PSVersion=$($PSVersionTable.PSVersion) Edition=$($PSVersionTable.PSEdition) OS=$([Environment]::OSVersion.VersionString) Arch=$([Environment]::Is64BitProcess) Culture=$([System.Globalization.CultureInfo]::CurrentCulture.Name)"
    Log "User: $([Environment]::UserName) Admin=$((Test-Admin)) Process=$PID HostProcessArch=$([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)"
}

function Write-InstallSummary {
    if (-not $Global:InstallSteps -or $Global:InstallSteps.Count -eq 0) { return }
    Log ""
    Log "---------------- INSTALL SUMMARY (BEGIN) ----------------"
    $totalOk = 0; $totalFail = 0
    $t0 = $Global:InstallSteps | Sort-Object Start | Select-Object -First 1 -ExpandProperty Start
    $t1 = ($Global:InstallSteps | ForEach-Object { $_.End ?? $_.Start }) | Sort-Object | Select-Object -Last 1
    foreach ($s in $Global:InstallSteps) {
        if ($s.Status -eq 'OK') { $totalOk++ } elseif ($s.Status -eq 'FAILED') { $totalFail++ }
        $line = "* {0} :: {1,-6} :: {2,-8} :: {3}" -f $s.Name,$s.Status,$s.Duration,$s.Details
        Log $line
    }
    $elapsed = if ($t0 -and $t1) { "{0:N2}s" -f (($t1 - $t0).TotalSeconds) } else { "n/a" }
    Log "Steps OK=$totalOk Failed=$totalFail Total=$($Global:InstallSteps.Count) Elapsed=$elapsed"
    Log "---------------- INSTALL SUMMARY (END) ------------------"
}

# NEW: Enable/disable ReFS option based on image build or -ForceReFsSupport
function Update-FsOptions {
    try {
        $reasons = @()
        $allowRefs = $false
        if ($ForceReFsSupport) {
            $allowRefs = $true
            $reasons += "-ForceReFsSupport enabled"
        } elseif ($cmbIndexes.SelectedItem -ne $null -and $cmbIndexes.SelectedItem.PSObject.Properties.Name -contains 'Build') {
            $build = [int]$cmbIndexes.SelectedItem.Build
            if ($build -gt 22621) {
                $allowRefs = $true
                $reasons += "Image build $build > 22621"
            } else {
                $reasons += "Image build $build <= 22621"
            }
        } else {
            $reasons += "No image selected"
        }

        $rbFsRefs.Enabled = $allowRefs
        if (-not $allowRefs -and $rbFsRefs.Checked) {
            $rbFsNtfs.Checked = $true
        }

        Log ("FS Option: ReFS {0}. {1}" -f ($(if ($allowRefs) {'ENABLED'} else {'DISABLED'}), ($reasons -join '; ')))
    } catch {
        Log "FS Option: Error determining ReFS support: $($_.Exception.Message)"
        $rbFsRefs.Enabled = $false
        $rbFsNtfs.Checked = $true
    }
}

# UI events
$btnBrowse.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "Windows Images (*.wim;*.esd)|*.wim;*.esd|All files (*.*)|*.*"
    $ofd.InitialDirectory = Split-Path -Path $txtPath.Text -ErrorAction SilentlyContinue
    if ($ofd.ShowDialog() -eq 'OK') { $txtPath.Text = $ofd.FileName }
})

$btnList.Add_Click({
    try {
        $cmbIndexes.Items.Clear()
        Log "Enumerating image indexes..."
        $imgs = Get-ImageList -Path $txtPath.Text
        foreach ($img in $imgs) {
            $sizeGiB = [Math]::Round($img.TotalBytes/1GB,2)
            $display = "#{0} - {1} (Build {2}, {3} GiB)" -f $img.Index,$img.Name,$img.Build,$sizeGiB
            # Include Build so ReFS eligibility can be checked later
            $null = $cmbIndexes.Items.Add([PSCustomObject]@{ Display=$display; Index=$img.Index; Build=$img.Build })
        }
        if ($cmbIndexes.Items.Count -gt 0) { $cmbIndexes.SelectedIndex = 0 }
        # Configure display
        $cmbIndexes.DisplayMember = "Display"
        $cmbIndexes.ValueMember = "Index"
        Log "Found $($cmbIndexes.Items.Count) image(s)."
        Update-FsOptions
    } catch {
        Log "Error listing images: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "PixelSetup", 'OK', 'Error') | Out-Null
    }
})

# Update FS options when selection changes
$cmbIndexes.add_SelectedIndexChanged({ Update-FsOptions })

function Refresh-Disks {
    Log "Refresh-Disks: Enumerating disks..."
    $lvDisks.Items.Clear()
    $disks = Get-Disk | Select-Object Number, FriendlyName, Size, PartitionStyle
    foreach ($d in $disks) {
        $sizeGB = [Math]::Round($d.Size/1GB,2)
        Log ("Refresh-Disks: Disk {0} '{1}' Size={2}GB Style={3}" -f $d.Number,$d.FriendlyName,$sizeGB,$d.PartitionStyle)
        $item = New-Object System.Windows.Forms.ListViewItem($d.Number.ToString())
        $null = $item.SubItems.Add($d.FriendlyName)
        $null = $item.SubItems.Add($sizeGB.ToString())
        $null = $item.SubItems.Add($d.PartitionStyle.ToString())
        $null = $lvDisks.Items.Add($item)
    }
    Log "Refresh-Disks: Total disks listed: $($disks.Count)"
}
$btnRefreshDisks.Add_Click({ Refresh-Disks })
$cbTest.Add_CheckedChanged({
    $lvDisks.Enabled = -not $cbTest.Checked
    $btnRefreshDisks.Enabled = -not $cbTest.Checked
})

$btnInstall.Add_Click({
    # Basic validation
    $imgPath = $txtPath.Text
    if ([string]::IsNullOrWhiteSpace($imgPath) -or -not (Test-Path $imgPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select a valid install.wim/esd path.", "PixelSetup", 'OK', 'Warning') | Out-Null
        return
    }
    if ($cmbIndexes.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show("Please list images and select an index.", "PixelSetup", 'OK', 'Warning') | Out-Null
        return
    }
    $index = $cmbIndexes.SelectedItem.Index
    $reMode = if ($rbReFull.Checked) { 1 } elseif ($rbReSkip.Checked) { 2 } else { 3 }
    $testMode = $cbTest.Checked
    $fsChoice = if ($rbFsRefs.Checked) { "ReFS" } else { "NTFS" }

    # NEW: initialize overall progress plan with per-wimlib phases
    $planned = @("Initialization") + ($(if ($testMode) { @("Test Mode Notice") } else { @("Partitioning") })) + @(
        "Apply: Creating files","Apply: Extracting file data","Apply: Applying metadata to files",
        "BCDBoot","WinRE","Finalization"
    )
    Initialize-Progress -Steps $planned

    # ...existing code to get $diskNum ...

    # Disable UI during operation
    $form.UseWaitCursor = $true
    foreach ($c in $form.Controls) { $c.Enabled = $false }
    $currentStep = $null
    try {
        Start-Step "Initialization"
        Log "Starting installation..."
        Write-EnvironmentInfo

        # NEW: Select drive letters if not in Test Mode
        $letters = $null
        if (-not $testMode) {
            $letters = Select-PartitionLetters -ReMode $reMode
            Log ("Selected letters: EFI={0}: Windows={1}:{2}" -f $letters.Efi,$letters.Windows,($(if ($reMode -ne 3) { " Recovery=$($letters.Recovery):" } else { "" })))
        } else {
            Log "Test Mode: Drive letter selection skipped."
        }

        Log ("Selected: ImagePath='{0}' Index={1} ReMode={2} TestMode={3} Disk={4} FS={5} ForceReFs={6}" -f $imgPath,$index,$reMode,$testMode,($diskNum ?? "<n/a>"),$fsChoice,$ForceReFsSupport.IsPresent)
        $wim = Ensure-Wimlib -LocalPath $wimlib
        Log "Using wimlib: $wim"
        End-Step "Initialization" "OK"

        if ($testMode) {
            Start-Step "Test Mode Notice"
            Log "Test Mode enabled: applying image to C:\Test (no disk changes)."
            Log "Note: File system selection ($fsChoice) only applies when partitioning; it is ignored in Test Mode."
            End-Step "Test Mode Notice" "OK"
        } else {
            Start-Step "Partitioning"
            Log "Wiping and partitioning disk $diskNum..."
            $script = Make-PartitionScript -DiskNumber $diskNum -ReMode $reMode -FileSystem $fsChoice -EfiLetter $letters.Efi -WindowsLetter $letters.Windows -RecoveryLetter $letters.Recovery
            Run-Diskpart -ScriptContent $script
            End-Step "Partitioning" "OK"
        }

        $applyDir = if ($testMode) { "C:\Test" } else { "$($letters.Windows):\" }
        Apply-Image -WimlibPath $wim -ImagePath $imgPath -Index $index -ApplyDir $applyDir

        if (-not $testMode) {
            Setup-Boot -WindowsLetter $letters.Windows -EfiLetter $letters.Efi
        } else {
            Start-Step "BCDBoot"
            Log "Skipping BCDBoot — Test Mode active."
            End-Step "BCDBoot" "OK" "Skipped TestMode"
        }

        Configure-WinRE -ReMode $reMode -TestMode:$testMode -WindowsLetter $($letters.Windows) -RecoveryLetter $($letters.Recovery)

        Start-Step "Finalization"
        Log "Installation complete."
        if ($testMode) {
            Log "Test Mode installation simulated to C:\Test. Inspect to verify contents."
        } else {
            Log "Remove installation media and reboot into OOBE. Run: wpeutil reboot"
        }
        End-Step "Finalization" "OK"
        [System.Windows.Forms.MessageBox]::Show("Installation complete.", "PixelSetup", 'OK', 'Information') | Out-Null
    } catch {
        Log "ERROR: $($_.Exception.Message)"
        $running = $Global:InstallSteps | Where-Object { $_.Status -eq "RUNNING" }
        foreach ($r in $running) { End-Step $r.Name "FAILED" $_.Exception.Message }
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "PixelSetup Error", 'OK', 'Error') | Out-Null
    } finally {
        Write-InstallSummary
        foreach ($c in $form.Controls) { $c.Enabled = $true }
        $form.UseWaitCursor = $false
    }
})

$btnRepair.Add_Click({
    if (-not $Global:IsWinPE) {
        [System.Windows.Forms.MessageBox]::Show("Repair Environment only available in WinPE.", "PixelSetup", 'OK', 'Information') | Out-Null
        return
    }
    Log "Repair: Attempting to launch Windows Recovery Environment (RecEnv)..."
    $candidates = @(
        "X:\sources\recovery\RecEnv.exe",
        "X:\sources\RecEnv.exe",
        "X:\Windows\System32\Recovery\RecEnv.exe"
    )
    $rec = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $rec) {
        Log "Repair: RecEnv.exe not found in known locations."
        [System.Windows.Forms.MessageBox]::Show("Could not locate RecEnv.exe in WinPE.", "PixelSetup", 'OK', 'Error') | Out-Null
        return
    }
    Log "Repair: Launching '$rec'"
    try {
        Start-Process -FilePath $rec -WindowStyle Normal | Out-Null
        Log "Repair: Launched."
    } catch {
        Log "Repair: ERROR launching RecEnv: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Failed to launch RecEnv: $($_.Exception.Message)", "PixelSetup", 'OK', 'Error') | Out-Null
    }
})

$btnClose.Add_Click({ $form.Close() })

# Initial population
try { Refresh-Disks } catch { Log "Could not enumerate disks: $($_.Exception.Message)" }

if ($Global:IsWinPE) { Log "Environment detected: WinPE (Repair button enabled)." } else { Log "Environment: Not WinPE (Repair button disabled)." }

# Show form
[void]$form.ShowDialog()

# The original CLI code was replaced by a GUI workflow above.
# - wimlib check, image enumeration, partitioning, apply, BCDBoot, and WinRE steps
#   are implemented in functions and invoked from the Install button.

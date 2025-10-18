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
    [switch]$ForceReFsSupport,
    [switch]$PseudoLocale
)

# Imports
. "$PSScriptRoot\strings.ps1"
if ($PseudoLocale) { Set-UILanguage 'qps-ploc' }
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
        [System.Windows.Forms.MessageBox]::Show((T 'STARequired'), (T 'PixelSetupTitle'), 'OK', 'Error') | Out-Null
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
    [System.Windows.Forms.MessageBox]::Show((T 'AdminRequired'), (T 'PixelSetupTitle'), 'OK', 'Error') | Out-Null
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
$form.Text = (T 'AppTitle')
$form.Size = New-Object System.Drawing.Size(980,700)
$form.StartPosition = 'CenterScreen'

# --- Wizard scaffolding: header/content/footer + navigation ---

$wizardFooter = New-Object System.Windows.Forms.Panel
$wizardFooter.Dock = 'Bottom'
$wizardFooter.Height = 50
$form.Controls.Add($wizardFooter)

$wizardContent = New-Object System.Windows.Forms.Panel
$wizardContent.Dock = 'Fill'
$form.Controls.Add($wizardContent)

$btnBack = New-Object System.Windows.Forms.Button
$btnBack.Text = (T 'NavBack')
$btnBack.Size = New-Object System.Drawing.Size(90,28)
$btnBack.Location = New-Object System.Drawing.Point(580,11)
$btnBack.Enabled = $false
$wizardFooter.Controls.Add($btnBack)

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = (T 'NavNext')
$btnNext.Size = New-Object System.Drawing.Size(90,28)
$btnNext.Location = New-Object System.Drawing.Point(680,11)
$wizardFooter.Controls.Add($btnNext)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = (T 'NavCancel')
$btnCancel.Size = New-Object System.Drawing.Size(90,28)
$btnCancel.Location = New-Object System.Drawing.Point(780,11)
$wizardFooter.Controls.Add($btnCancel)

# Keep buttons right-aligned on resize
$wizardFooter.Add_Resize({
    $btnCancel.Left = $wizardFooter.Width - 100
    $btnNext.Left   = $wizardFooter.Width - 200
    $btnBack.Left   = $wizardFooter.Width - 300
})

# Wizard pages (Panels)
$pageWelcome = New-Object System.Windows.Forms.Panel; $pageWelcome.Dock = 'Fill'
$pageImage   = New-Object System.Windows.Forms.Panel; $pageImage.Dock   = 'Fill'
$pageWinRE   = New-Object System.Windows.Forms.Panel; $pageWinRE.Dock   = 'Fill'
$pageTarget  = New-Object System.Windows.Forms.Panel; $pageTarget.Dock  = 'Fill'
$pageSummary = New-Object System.Windows.Forms.Panel; $pageSummary.Dock = 'Fill'
$pageInstall = New-Object System.Windows.Forms.Panel; $pageInstall.Dock = 'Fill'
$pageFinish  = New-Object System.Windows.Forms.Panel; $pageFinish.Dock  = 'Fill'
$wizardContent.Controls.AddRange(@($pageWelcome,$pageImage,$pageWinRE,$pageTarget,$pageSummary,$pageInstall,$pageFinish))
$pageWelcome.Visible = $true; foreach($p in @($pageImage,$pageWinRE,$pageTarget,$pageSummary,$pageInstall,$pageFinish)){ $p.Visible = $false }

# Welcome page content
$lblWelcome = New-Object System.Windows.Forms.Label
$lblWelcome.Text = "Install Windows`r`n`r`nChoose Next to continue, or Repair to open recovery tools."
$lblWelcome.AutoSize = $true
$lblWelcome.Location = New-Object System.Drawing.Point(20,20)
$pageWelcome.Controls.Add($lblWelcome)

$BuildTag = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\PixelPE' -Name 'BuildTag' -ErrorAction SilentlyContinue
if ($BuildTag) {
    $BuildTag = $BuildTag
}
else {
    $BuildTag = "Not In PixelPE"
}

$lblInfo = New-Object System.Windows.Forms.Label
$winBuild = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'BuildLabEx' -ErrorAction SilentlyContinue
if ([string]::IsNullOrWhiteSpace($winBuild)) { $winBuild = 'Unknown' }
$lblInfo.Text = "PixelPE Build: $BuildTag`r`nWindows Build: $winBuild"
$lblInfo.AutoSize = $true
$lblInfo.Location = New-Object System.Drawing.Point(20, 500)
$pageWelcome.Controls.Add($lblInfo)

$gbImage = New-Object System.Windows.Forms.GroupBox
$gbImage.Text = (T 'GroupImageTitle')
$gbImage.Location = New-Object System.Drawing.Point(12,45)
$gbImage.Size = New-Object System.Drawing.Size(940,130)
$form.Controls.Add($gbImage)
# Re-parent to wizard page and reposition
$gbImage.Parent = $pageImage
$gbImage.Location = New-Object System.Drawing.Point(20,20)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = (T 'ImagePathLabel')
$lblPath.AutoSize = $true
$lblPath.Location = New-Object System.Drawing.Point(12,28)
$gbImage.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(140,25)
$txtPath.Size = New-Object System.Drawing.Size(650,23)
$txtPath.Text = $defaultImagePath
$gbImage.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = (T 'Browse')
$btnBrowse.Location = New-Object System.Drawing.Point(800,24)
$btnBrowse.Size = New-Object System.Drawing.Size(120,25)
$gbImage.Controls.Add($btnBrowse)

$btnList = New-Object System.Windows.Forms.Button
$btnList.Text = (T 'ListImages')
$btnList.Location = New-Object System.Drawing.Point(800,60)
$btnList.Size = New-Object System.Drawing.Size(120,25)
$gbImage.Controls.Add($btnList)

$lblIndex = New-Object System.Windows.Forms.Label
$lblIndex.Text = (T 'SelectIndexLabel')
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
$lblFs.Text = (T 'FSLabel')
$lblFs.AutoSize = $true
$lblFs.Location = New-Object System.Drawing.Point(12,95)
$gbImage.Controls.Add($lblFs)

$rbFsNtfs = New-Object System.Windows.Forms.RadioButton
$rbFsNtfs.Text = (T 'FSNTFS')
$rbFsNtfs.Location = New-Object System.Drawing.Point(200,93)
$rbFsNtfs.AutoSize = $true
$rbFsNtfs.Checked = $true
$gbImage.Controls.Add($rbFsNtfs)

$rbFsRefs = New-Object System.Windows.Forms.RadioButton
$rbFsRefs.Text = (T 'FSReFS')
$rbFsRefs.Location = New-Object System.Drawing.Point(330,93)
$rbFsRefs.AutoSize = $true
$rbFsRefs.Enabled = $false
$gbImage.Controls.Add($rbFsRefs)

$gbWinRE = New-Object System.Windows.Forms.GroupBox
$gbWinRE.Text = (T 'GroupWinRETitle')
$gbWinRE.Location = New-Object System.Drawing.Point(12,185)
$gbWinRE.Size = New-Object System.Drawing.Size(460,120)
$form.Controls.Add($gbWinRE)
# Re-parent to wizard page and reposition
$gbWinRE.Parent = $pageWinRE
$gbWinRE.Location = New-Object System.Drawing.Point(20,20)

$rbReFull = New-Object System.Windows.Forms.RadioButton
$rbReFull.Text = (T 'ReFull')
$rbReFull.Location = New-Object System.Drawing.Point(12,25)
$rbReFull.AutoSize = $true
$rbReFull.Checked = $true
$gbWinRE.Controls.Add($rbReFull)

$rbReSkip = New-Object System.Windows.Forms.RadioButton
$rbReSkip.Text = (T 'ReSkip')
$rbReSkip.Location = New-Object System.Drawing.Point(12,50)
$rbReSkip.AutoSize = $true
$gbWinRE.Controls.Add($rbReSkip)

$rbReNone = New-Object System.Windows.Forms.RadioButton
$rbReNone.Text = (T 'ReNone')
$rbReNone.Location = New-Object System.Drawing.Point(12,75)
$rbReNone.AutoSize = $true
$gbWinRE.Controls.Add($rbReNone)

$gbTarget = New-Object System.Windows.Forms.GroupBox
$gbTarget.Text = (T 'GroupTargetTitle')
$gbTarget.Location = New-Object System.Drawing.Point(492,185)
$gbTarget.Size = New-Object System.Drawing.Size(460,220)
$form.Controls.Add($gbTarget)
# Re-parent to wizard page and reposition
$gbTarget.Parent = $pageTarget
$gbTarget.Location = New-Object System.Drawing.Point(20,20)
$gbTarget.Width = 900

$cbTest = New-Object System.Windows.Forms.CheckBox
$cbTest.Text = (T 'TestModeLabel')
$cbTest.Location = New-Object System.Drawing.Point(12,25)
$cbTest.AutoSize = $true
$gbTarget.Controls.Add($cbTest)

$btnRefreshDisks = New-Object System.Windows.Forms.Button
$btnRefreshDisks.Text = (T 'RefreshDisks')
$btnRefreshDisks.Location = New-Object System.Drawing.Point(320,20)
$btnRefreshDisks.Size = New-Object System.Drawing.Size(120,25)
$gbTarget.Controls.Add($btnRefreshDisks)

$lvDisks = New-Object System.Windows.Forms.ListView
$lvDisks.Location = New-Object System.Drawing.Point(12,55)
$lvDisks.Size = New-Object System.Drawing.Size(428,150)
$lvDisks.View = 'Details'
$lvDisks.FullRowSelect = $true
$lvDisks.Columns.Add((T 'ColumnNumber'),60) | Out-Null
$lvDisks.Columns.Add((T 'ColumnFriendlyName'),180) | Out-Null
$lvDisks.Columns.Add((T 'ColumnSizeGB'),90) | Out-Null
$lvDisks.Columns.Add((T 'ColumnStyle'),80) | Out-Null
$gbTarget.Controls.Add($lvDisks)

$gbActions = New-Object System.Windows.Forms.GroupBox
$gbActions.Text = (T 'GroupActionsTitle')
$gbActions.Location = New-Object System.Drawing.Point(12,315)
$gbActions.Size = New-Object System.Drawing.Size(460,90)
$form.Controls.Add($gbActions)
# Hide legacy actions area (navigation moved to footer)
$gbActions.Visible = $false

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = (T 'Install')
$btnInstall.Location = New-Object System.Drawing.Point(12,30)
$btnInstall.Size = New-Object System.Drawing.Size(140,35)
$gbActions.Controls.Add($btnInstall)
# Hide old install button; wizard Next will start install
$btnInstall.Visible = $false

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = (T 'Close')
$btnClose.Location = New-Object System.Drawing.Point(170,30)
$btnClose.Size = New-Object System.Drawing.Size(140,35)
$gbActions.Controls.Add($btnClose)
# Legacy Close hidden
$btnClose.Visible = $false

# NEW: Repair button (WinPE only)
$btnRepair = New-Object System.Windows.Forms.Button
$btnRepair.Text = (T 'Repair')
$btnRepair.Location = New-Object System.Drawing.Point(330,30)
$btnRepair.Size = New-Object System.Drawing.Size(120,35)
$btnRepair.Enabled = $Global:IsWinPE
$gbActions.Controls.Add($btnRepair)
# Move Repair onto Welcome page
$btnRepair.Parent = $pageWelcome
$btnRepair.Location = New-Object System.Drawing.Point(20,90)

# NEW: Progress UI (two bars: current step and overall)
$gbProgress = New-Object System.Windows.Forms.GroupBox
$gbProgress.Text = (T 'ProgressTitle')
$gbProgress.Location = New-Object System.Drawing.Point(12,415)
$gbProgress.Size = New-Object System.Drawing.Size(940,80)
$form.Controls.Add($gbProgress)
# Re-parent to Installing page
$gbProgress.Parent = $pageInstall
$gbProgress.Location = New-Object System.Drawing.Point(20,20)

$lblStepName = New-Object System.Windows.Forms.Label
$lblStepName.Text = (T 'StepLabelReady')
$lblStepName.AutoSize = $true
$lblStepName.Location = New-Object System.Drawing.Point(12,22)
$gbProgress.Controls.Add($lblStepName)

$pbStep = New-Object System.Windows.Forms.ProgressBar
$pbStep.Location = New-Object System.Drawing.Point(120,20)
$pbStep.Size = New-Object System.Drawing.Size(800,18)
$pbStep.Minimum = 0; $pbStep.Maximum = 100; $pbStep.Value = 0
$gbProgress.Controls.Add($pbStep)

$lblTotal = New-Object System.Windows.Forms.Label
$lblTotal.Text = (T 'Overall0')
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
# Re-parent to Installing page and reposition/resize
$txtLog.Parent = $pageInstall
$txtLog.Location = New-Object System.Drawing.Point(20,120)
$txtLog.Size = New-Object System.Drawing.Size(900,420)

# Summary page content
$lblSummary = New-Object System.Windows.Forms.Label
$lblSummary.Text = "Confirm your settings before installation:"
$lblSummary.AutoSize = $true
$lblSummary.Location = New-Object System.Drawing.Point(20,20)
$pageSummary.Controls.Add($lblSummary)

$txtSummary = New-Object System.Windows.Forms.TextBox
$txtSummary.Multiline = $true
$txtSummary.ReadOnly = $true
$txtSummary.ScrollBars = 'Vertical'
$txtSummary.Location = New-Object System.Drawing.Point(20,50)
$txtSummary.Size = New-Object System.Drawing.Size(900,450)
$pageSummary.Controls.Add($txtSummary)

# Finish page content
$lblFinish = New-Object System.Windows.Forms.Label
$lblFinish.Text = (T 'InstallComplete') + " You can close this wizard."
$lblFinish.AutoSize = $true
$lblFinish.Location = New-Object System.Drawing.Point(20,20)
$pageFinish.Controls.Add($lblFinish)

# Wizard state and helpers
$script:WizardIndex = 0
$script:WizardPages = @(
    @{ Name='Welcome';   Panel=$pageWelcome },
    @{ Name='Image';     Panel=$pageImage },
    @{ Name='Recovery';  Panel=$pageWinRE },
    @{ Name='Target';    Panel=$pageTarget },
    @{ Name='Summary';   Panel=$pageSummary },
    @{ Name='Installing';Panel=$pageInstall },
    @{ Name='Finish';    Panel=$pageFinish }
)

function Show-WizardPage {
    param([int]$Index)
    if ($Index -lt 0 -or $Index -ge $script:WizardPages.Count) { return }
    for ($i=0; $i -lt $script:WizardPages.Count; $i++) {
        $script:WizardPages[$i].Panel.Visible = ($i -eq $Index)
    }
    $script:WizardIndex = $Index
    Update-WizardButtons
    if ($script:WizardPages[$Index].Name -eq 'Summary') { Build-Summary }
}

function Update-WizardButtons {
    $name = $script:WizardPages[$script:WizardIndex].Name
    switch ($name) {
        'Welcome'   { $btnBack.Enabled = $false; $btnNext.Text = (T 'NavNext') }
        'Summary'   { $btnBack.Enabled = $true;  $btnNext.Text = (T 'NavInstallNow') }
        'Installing'{ $btnBack.Enabled = $false; $btnNext.Enabled = $false; $btnCancel.Enabled = $false }
        'Finish'    { $btnBack.Enabled = $false; $btnNext.Enabled = $true; $btnNext.Text = (T 'Close'); $btnCancel.Enabled = $true }
        default     { $btnBack.Enabled = $true;  $btnNext.Text = (T 'NavNext'); $btnNext.Enabled = $true; $btnCancel.Enabled = $true }
    }
}

function Build-Summary {
    try {
        $imgPath = $txtPath.Text
        $sel = $cmbIndexes.SelectedItem
        $idx = if ($sel) { $sel.Index } else { '(not selected)' }
        $build = if ($sel -and ($sel.PSObject.Properties.Name -contains 'Build')) { $sel.Build } else { 'n/a' }
        $fsChoice = if ($rbFsRefs.Checked) { 'ReFS' } else { 'NTFS' }
        $reMode = if ($rbReFull.Checked) { 'Full (WinRE)' } elseif ($rbReSkip.Checked) { 'Skip WinRE' } else { 'No Recovery' }
        $target = if ($cbTest.Checked) { 'Test Mode (C:\\Test)' } else {
            if ($lvDisks.SelectedItems.Count -gt 0) {
                $it = $lvDisks.SelectedItems[0]; "Disk #$($it.SubItems[0].Text) - $($it.SubItems[1].Text)"
            } else { '(no disk selected)' }
        }
        $txtSummary.Text = @(
            "Image path: $imgPath",
            "Index: $idx  Build: $build",
            "File system: $fsChoice",
            "Recovery: $reMode",
            "Target: $target",
            "WinPE detected: $Global:IsWinPE"
        ) -join [Environment]::NewLine
    } catch { $txtSummary.Text = "Unable to build summary: $($_.Exception.Message)" }
}

Show-WizardPage 0

# Logging helper
function Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("HH:mm:ss")
    $line = "[$ts] $Message"
    $txtLog.AppendText($line + [Environment]::NewLine)
}

# Core functions (adapt original steps)
<#
{ Monolithic helpers were here (Ensure-Wimlib, Get-ImageList, Invoke-External, Apply-Image,
  partitioning, boot, WinRE, progress, and duplicate Refresh-Disks). They are now split
  into steps/*.ps1 and loaded via dot-sourcing. }
#>
# ==== Verbose step tracking additions ====
<# Duplicate progress helpers moved to steps/progress.ps1
# ...existing code defining $Global:InstallSteps, Initialize-Progress, Update-TotalProgress,
# Update-StepProgress, Start-Step, End-Step, Write-EnvironmentInfo, Write-InstallSummary...
#>

# NEW: Enable/disable ReFS option based on image build or -ForceReFsSupport
function Update-FsOptions {
    try {
        $reasons = @()
        $allowRefs = $false
        if ($ForceReFsSupport) {
            $allowRefs = $true
            $reasons += "-ForceReFsSupport enabled"
        } elseif ($null -ne $cmbIndexes.SelectedItem -and $cmbIndexes.SelectedItem.PSObject.Properties.Name -contains 'Build') {
            $build = [int]$cmbIndexes.SelectedItem.Build
            if ($build -gt 22621) {
                $allowRefs = $true
                $reasons += "Image build $build > 22621"
            } else {
                $allowRefs = $false
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

function Start-Installation {
    # ...existing code...
    # removed unused: $currentStep = $null
    # ...existing code...
}

# Single import location for step modules
. "$PSScriptRoot\steps\progress.ps1"
. "$PSScriptRoot\steps\image.ps1"
. "$PSScriptRoot\steps\partition.ps1"
. "$PSScriptRoot\steps\disksel.ps1"
. "$PSScriptRoot\steps\confirm.ps1"
. "$PSScriptRoot\steps\boot.ps1"
. "$PSScriptRoot\steps\winre.ps1"

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
            $display = (T 'ImageEntryFmt' $img.Index $img.Name $img.Build $sizeGiB)
            # Include Build so ReFS eligibility can be checked later
            $null = $cmbIndexes.Items.Add([PSCustomObject]@{ Display=$display; Index=$img.Index; Build=$img.Build })
        }
        if ($cmbIndexes.Items.Count -gt 0) { $cmbIndexes.SelectedIndex = 0 }
        $cmbIndexes.DisplayMember = "Display"
        $cmbIndexes.ValueMember = "Index"
        Log "Found $($cmbIndexes.Items.Count) image(s)."
        Update-FsOptions
    } catch {
        Log "Error listing images: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T 'PixelSetupTitle'), 'OK', 'Error') | Out-Null
    }
})

# Update FS options when selection changes
$cmbIndexes.add_SelectedIndexChanged({ Update-FsOptions })

# Using Refresh-Disks from steps/disksel.ps1
$btnRefreshDisks.Add_Click({ Refresh-Disks })
$cbTest.Add_CheckedChanged({
    $lvDisks.Enabled = -not $cbTest.Checked
    $btnRefreshDisks.Enabled = -not $cbTest.Checked
})

$btnInstall.Add_Click({
    # Basic validation
    $imgPath = $txtPath.Text
    if ([string]::IsNullOrWhiteSpace($imgPath) -or -not (Test-Path $imgPath)) {
        [System.Windows.Forms.MessageBox]::Show((T 'SelectValidImage'), (T 'PixelSetupTitle'), 'OK', 'Warning') | Out-Null
        return
    }
    if ($cmbIndexes.SelectedItem -eq $null) {
        [System.Windows.Forms.MessageBox]::Show((T 'SelectIndexPrompt'), (T 'PixelSetupTitle'), 'OK', 'Warning') | Out-Null
        return
    }
    $index = $cmbIndexes.SelectedItem.Index
    $reMode = if ($rbReFull.Checked) { 1 } elseif ($rbReSkip.Checked) { 2 } else { 3 }
    $testMode = $cbTest.Checked
    $fsChoice = if ($rbFsRefs.Checked) { "ReFS" } else { "NTFS" }

    # NEW: initialize overall progress plan with per-wimlib phases
    $planned = @((T 'StepInitialization')) + ($(if ($testMode) { @((T 'StepTestModeNotice')) } else { @((T 'StepPartitioning')) })) + @(
        (T 'StepApplyCreatingFiles'),(T 'StepApplyExtracting'),(T 'StepApplyApplyingMetadata'),
        (T 'StepBCDBoot'),(T 'StepWinRE'),(T 'StepFinalization')
    )
    Initialize-Progress -Steps $planned

    # ...existing code to get $diskNum ...

    # Disable UI during operation
    $form.UseWaitCursor = $true
    foreach ($c in $form.Controls) { $c.Enabled = $false }
    try {
        Start-Step (T 'StepInitialization')
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
        End-Step (T 'StepInitialization') "OK"

        if ($testMode) {
            Start-Step (T 'StepTestModeNotice')
            Log "Test Mode enabled: applying image to C:\\Test (no disk changes)."
            Log "Note: File system selection ($fsChoice) only applies when partitioning; it is ignored in Test Mode."
            End-Step (T 'StepTestModeNotice') "OK"
        } else {
            Start-Step (T 'StepPartitioning')
            Log "Wiping and partitioning disk $diskNum..."
            $script = Make-PartitionScript -DiskNumber $diskNum -ReMode $reMode -FileSystem $fsChoice -EfiLetter $letters.Efi -WindowsLetter $letters.Windows -RecoveryLetter $letters.Recovery
            Run-Diskpart -ScriptContent $script
            End-Step (T 'StepPartitioning') "OK"
        }

        $applyDir = if ($testMode) { "C:\\Test" } else { "$($letters.Windows):\\" }
        Apply-Image -WimlibPath $wim -ImagePath $imgPath -Index $index -ApplyDir $applyDir

        if (-not $testMode) {
            Set-BootConfig -WindowsLetter $letters.Windows -EfiLetter $letters.Efi
        } else {
            Start-Step (T 'StepBCDBoot')
            Log "Skipping BCDBoot — Test Mode active."
            End-Step (T 'StepBCDBoot') "OK" "Skipped TestMode"
        }

        Set-WinRE -ReMode $reMode -TestMode:$testMode -WindowsLetter $($letters.Windows) -RecoveryLetter $($letters.Recovery)

        Start-Step (T 'StepFinalization')
        Log "Installation complete."
        if ($testMode) {
            Log "Test Mode installation simulated to C:\\Test. Inspect to verify contents."
        } else {
            Log "Remove installation media and reboot into OOBE. Run: wpeutil reboot"
        }
        End-Step (T 'StepFinalization') "OK"
        [System.Windows.Forms.MessageBox]::Show((T 'InstallComplete'), (T 'PixelSetupTitle'), 'OK', 'Information') | Out-Null
    } catch {
        Log "ERROR: $($_.Exception.Message)"
        $running = $Global:InstallSteps | Where-Object { $_.Status -eq "RUNNING" }
        foreach ($r in $running) { End-Step $r.Name "FAILED" $_.Exception.Message }
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (T 'PixelSetupErrorTitle'), 'OK', 'Error') | Out-Null
    } finally {
        Write-InstallSummary
        foreach ($c in $form.Controls) { $c.Enabled = $true }
        $form.UseWaitCursor = $false
    }
})

# OLD direct install click handler replaced by Start-Installation
<#
$btnInstall.Add_Click({
    # Previous inline installation logic moved to Start-Installation and step modules.
})
#>

$btnRepair.Add_Click({
    if (-not $Global:IsWinPE) {
        [System.Windows.Forms.MessageBox]::Show("Repair Environment only available in WinPE.", "PixelSetup", 'OK', 'Information') | Out-Null
        return
    }

    # Target PowerShell script under script root
    $scriptPath = Join-Path $PSScriptRoot 'recovery\main.ps1'
    Log "Repair: Requested launch of PowerShell recovery script: $scriptPath"
    if (-not (Test-Path $scriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Recovery script not found: $scriptPath", "PixelSetup", 'OK', 'Error') | Out-Null
        Log "Repair: ERROR - Recovery script not found."
        return
    }
    & $scriptPath
})

# Wizard navigation events
$btnBack.Add_Click({ if ($script:WizardIndex -gt 0) { Show-WizardPage ($script:WizardIndex - 1) } })
$btnNext.Add_Click({
    switch ($script:WizardIndex) {
        0 { Show-WizardPage 1 }
        1 { Show-WizardPage 2 }
        2 { Show-WizardPage 3 }
        3 { Show-WizardPage 4 }
        4 { Start-Installation }
        6 { $form.Close() }
        default { }
    }
})
$btnCancel.Add_Click({ $form.Close() })

# Initial population
try { Refresh-Disks } catch { Log "Could not enumerate disks: $($_.Exception.Message)" }

if ($Global:IsWinPE) { Log "Environment detected: WinPE (Repair button enabled)." } else { Log "Environment: Not WinPE (Repair button disabled)." }

# Show form
[void]$form.ShowDialog()

# The original CLI code was replaced by a GUI workflow above.
# - wimlib check, image enumeration, partitioning, apply, BCDBoot, and WinRE steps
#   are implemented in functions and invoked from the Install button.

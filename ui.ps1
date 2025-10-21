
# UI
$form = New-Object System.Windows.Forms.Form
$form.Text = (T 'AppTitle')
$form.Size = New-Object System.Drawing.Size(980, 700)
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
$btnBack.Size = New-Object System.Drawing.Size(90, 28)
$btnBack.Location = New-Object System.Drawing.Point(580, 11)
$btnBack.Enabled = $false
$wizardFooter.Controls.Add($btnBack)

$btnNext = New-Object System.Windows.Forms.Button
$btnNext.Text = (T 'NavNext')
$btnNext.Size = New-Object System.Drawing.Size(90, 28)
$btnNext.Location = New-Object System.Drawing.Point(680, 11)
$wizardFooter.Controls.Add($btnNext)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = (T 'NavCancel')
$btnCancel.Size = New-Object System.Drawing.Size(90, 28)
$btnCancel.Location = New-Object System.Drawing.Point(780, 11)
$wizardFooter.Controls.Add($btnCancel)

# Keep buttons right-aligned on resize
$wizardFooter.Add_Resize({
        $btnCancel.Left = $wizardFooter.Width - 100
        $btnNext.Left = $wizardFooter.Width - 200
        $btnBack.Left = $wizardFooter.Width - 300
    })

# Wizard pages (Panels)
$pageWelcome = New-Object System.Windows.Forms.Panel; $pageWelcome.Dock = 'Fill'
$pageImage = New-Object System.Windows.Forms.Panel; $pageImage.Dock = 'Fill'
$pageWinRE = New-Object System.Windows.Forms.Panel; $pageWinRE.Dock = 'Fill'
$pageTarget = New-Object System.Windows.Forms.Panel; $pageTarget.Dock = 'Fill'
$pageSummary = New-Object System.Windows.Forms.Panel; $pageSummary.Dock = 'Fill'
$pageInstall = New-Object System.Windows.Forms.Panel; $pageInstall.Dock = 'Fill'
$pageFinish = New-Object System.Windows.Forms.Panel; $pageFinish.Dock = 'Fill'
$wizardContent.Controls.AddRange(@($pageWelcome, $pageImage, $pageWinRE, $pageTarget, $pageSummary, $pageInstall, $pageFinish))
$pageWelcome.Visible = $true; foreach ($p in @($pageImage, $pageWinRE, $pageTarget, $pageSummary, $pageInstall, $pageFinish)) { $p.Visible = $false }

# Welcome page content
$lblWelcome = New-Object System.Windows.Forms.Label
$lblWelcome.Text = "Install Windows`r`n`r`nChoose Next to continue, or Repair to open recovery tools."
$lblWelcome.AutoSize = $true
$lblWelcome.Location = New-Object System.Drawing.Point(20, 20)
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
$gbImage.Location = New-Object System.Drawing.Point(12, 45)
$gbImage.Size = New-Object System.Drawing.Size(940, 130)
$form.Controls.Add($gbImage)
# Re-parent to wizard page and reposition
$gbImage.Parent = $pageImage
$gbImage.Location = New-Object System.Drawing.Point(20, 20)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = (T 'ImagePathLabel')
$lblPath.AutoSize = $true
$lblPath.Location = New-Object System.Drawing.Point(12, 28)
$gbImage.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(140, 25)
$txtPath.Size = New-Object System.Drawing.Size(650, 23)
$txtPath.Text = $defaultImagePath
$gbImage.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = (T 'Browse')
$btnBrowse.Location = New-Object System.Drawing.Point(800, 24)
$btnBrowse.Size = New-Object System.Drawing.Size(120, 25)
$gbImage.Controls.Add($btnBrowse)

$btnList = New-Object System.Windows.Forms.Button
$btnList.Text = (T 'ListImages')
$btnList.Location = New-Object System.Drawing.Point(800, 60)
$btnList.Size = New-Object System.Drawing.Size(120, 25)
$gbImage.Controls.Add($btnList)

$lblIndex = New-Object System.Windows.Forms.Label
$lblIndex.Text = (T 'SelectIndexLabel')
$lblIndex.AutoSize = $true
$lblIndex.Location = New-Object System.Drawing.Point(12, 65)
$gbImage.Controls.Add($lblIndex)

$cmbIndexes = New-Object System.Windows.Forms.ComboBox
$cmbIndexes.DropDownStyle = 'DropDownList'
$cmbIndexes.Location = New-Object System.Drawing.Point(140, 62)
$cmbIndexes.Size = New-Object System.Drawing.Size(650, 23)
$gbImage.Controls.Add($cmbIndexes)

# NEW: File system selection (default NTFS; ReFS enabled when supported)
$lblFs = New-Object System.Windows.Forms.Label
$lblFs.Text = (T 'FSLabel')
$lblFs.AutoSize = $true
$lblFs.Location = New-Object System.Drawing.Point(12, 95)
$gbImage.Controls.Add($lblFs)

$rbFsNtfs = New-Object System.Windows.Forms.RadioButton
$rbFsNtfs.Text = (T 'FSNTFS')
$rbFsNtfs.Location = New-Object System.Drawing.Point(200, 93)
$rbFsNtfs.AutoSize = $true
$rbFsNtfs.Checked = $true
$gbImage.Controls.Add($rbFsNtfs)

$rbFsRefs = New-Object System.Windows.Forms.RadioButton
$rbFsRefs.Text = (T 'FSReFS')
$rbFsRefs.Location = New-Object System.Drawing.Point(330, 93)
$rbFsRefs.AutoSize = $true
$rbFsRefs.Enabled = $false
$gbImage.Controls.Add($rbFsRefs)

$gbWinRE = New-Object System.Windows.Forms.GroupBox
$gbWinRE.Text = (T 'GroupWinRETitle')
$gbWinRE.Location = New-Object System.Drawing.Point(12, 185)
$gbWinRE.Size = New-Object System.Drawing.Size(460, 120)
$form.Controls.Add($gbWinRE)
# Re-parent to wizard page and reposition
$gbWinRE.Parent = $pageWinRE
$gbWinRE.Location = New-Object System.Drawing.Point(20, 20)

$rbReFull = New-Object System.Windows.Forms.RadioButton
$rbReFull.Text = (T 'ReFull')
$rbReFull.Location = New-Object System.Drawing.Point(12, 25)
$rbReFull.AutoSize = $true
$rbReFull.Checked = $true
$gbWinRE.Controls.Add($rbReFull)

$rbReSkip = New-Object System.Windows.Forms.RadioButton
$rbReSkip.Text = (T 'ReSkip')
$rbReSkip.Location = New-Object System.Drawing.Point(12, 50)
$rbReSkip.AutoSize = $true
$gbWinRE.Controls.Add($rbReSkip)

$rbReNone = New-Object System.Windows.Forms.RadioButton
$rbReNone.Text = (T 'ReNone')
$rbReNone.Location = New-Object System.Drawing.Point(12, 75)
$rbReNone.AutoSize = $true
$gbWinRE.Controls.Add($rbReNone)

$gbTarget = New-Object System.Windows.Forms.GroupBox
$gbTarget.Text = (T 'GroupTargetTitle')
$gbTarget.Location = New-Object System.Drawing.Point(492, 185)
$gbTarget.Size = New-Object System.Drawing.Size(460, 220)
$form.Controls.Add($gbTarget)
# Re-parent to wizard page and reposition
$gbTarget.Parent = $pageTarget
$gbTarget.Location = New-Object System.Drawing.Point(20, 20)
$gbTarget.Width = 900

$cbTest = New-Object System.Windows.Forms.CheckBox
$cbTest.Text = (T 'TestModeLabel')
$cbTest.Location = New-Object System.Drawing.Point(12, 25)
$cbTest.AutoSize = $true
$gbTarget.Controls.Add($cbTest)

$btnRefreshDisks = New-Object System.Windows.Forms.Button
$btnRefreshDisks.Text = (T 'RefreshDisks')
$btnRefreshDisks.Location = New-Object System.Drawing.Point(320, 20)
$btnRefreshDisks.Size = New-Object System.Drawing.Size(120, 25)
$gbTarget.Controls.Add($btnRefreshDisks)

$lvDisks = New-Object System.Windows.Forms.ListView
$lvDisks.Location = New-Object System.Drawing.Point(12, 55)
$lvDisks.Size = New-Object System.Drawing.Size(850, 150)
$lvDisks.View = 'Details'
$lvDisks.FullRowSelect = $true
$lvDisks.Columns.Add((T 'ColumnNumber'), 60) | Out-Null
$lvDisks.Columns.Add((T 'ColumnFriendlyName'), 180) | Out-Null
$lvDisks.Columns.Add((T 'ColumnSizeGB'), 90) | Out-Null
$lvDisks.Columns.Add((T 'ColumnStyle'), 80) | Out-Null
$gbTarget.Controls.Add($lvDisks)

$gbActions = New-Object System.Windows.Forms.GroupBox
$gbActions.Text = (T 'GroupActionsTitle')
$gbActions.Location = New-Object System.Drawing.Point(12, 315)
$gbActions.Size = New-Object System.Drawing.Size(460, 90)
$form.Controls.Add($gbActions)
# Hide legacy actions area (navigation moved to footer)
$gbActions.Visible = $false

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = (T 'Install')
$btnInstall.Location = New-Object System.Drawing.Point(12, 30)
$btnInstall.Size = New-Object System.Drawing.Size(140, 35)
$gbActions.Controls.Add($btnInstall)
# Hide old install button; wizard Next will start install
$btnInstall.Visible = $false

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = (T 'Close')
$btnClose.Location = New-Object System.Drawing.Point(170, 30)
$btnClose.Size = New-Object System.Drawing.Size(140, 35)
$gbActions.Controls.Add($btnClose)
# Legacy Close hidden
$btnClose.Visible = $false

# NEW: Repair button (WinPE only)
$btnRepair = New-Object System.Windows.Forms.Button
$btnRepair.Text = (T 'Repair')
$btnRepair.Location = New-Object System.Drawing.Point(330, 30)
$btnRepair.Size = New-Object System.Drawing.Size(120, 35)
$btnRepair.Enabled = $Global:IsWinPE
$gbActions.Controls.Add($btnRepair)
# Move Repair onto Welcome page
$btnRepair.Parent = $pageWelcome
$btnRepair.Location = New-Object System.Drawing.Point(20, 90)

# NEW: Progress UI (two bars: current step and overall)
$gbProgress = New-Object System.Windows.Forms.GroupBox
$gbProgress.Text = (T 'ProgressTitle')
$gbProgress.Location = New-Object System.Drawing.Point(12, 415)
$gbProgress.Size = New-Object System.Drawing.Size(940, 80)
$form.Controls.Add($gbProgress)
# Re-parent to Installing page
$gbProgress.Parent = $pageInstall
$gbProgress.Location = New-Object System.Drawing.Point(20, 20)

$lblStepName = New-Object System.Windows.Forms.Label
$lblStepName.Text = (T 'StepLabelReady')
$lblStepName.AutoSize = $true
$lblStepName.Location = New-Object System.Drawing.Point(12, 22)
$gbProgress.Controls.Add($lblStepName)

$pbStep = New-Object System.Windows.Forms.ProgressBar
$pbStep.Location = New-Object System.Drawing.Point(120, 20)
$pbStep.Size = New-Object System.Drawing.Size(800, 18)
$pbStep.Minimum = 0; $pbStep.Maximum = 100; $pbStep.Value = 0
$gbProgress.Controls.Add($pbStep)

$lblTotal = New-Object System.Windows.Forms.Label
$lblTotal.Text = (T 'Overall0')
$lblTotal.AutoSize = $true
$lblTotal.Location = New-Object System.Drawing.Point(12, 50)
$gbProgress.Controls.Add($lblTotal)

$pbTotal = New-Object System.Windows.Forms.ProgressBar
$pbTotal.Location = New-Object System.Drawing.Point(120, 48)
$pbTotal.Size = New-Object System.Drawing.Size(800, 18)
$pbTotal.Minimum = 0; $pbTotal.Maximum = 100; $pbTotal.Value = 0
$gbProgress.Controls.Add($pbTotal)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
# MOVED DOWN to make room for progress group
$txtLog.Location = New-Object System.Drawing.Point(12, 505)
$txtLog.Size = New-Object System.Drawing.Size(940, 170)
$form.Controls.Add($txtLog)
# Re-parent to Installing page and reposition/resize
$txtLog.Parent = $pageInstall
$txtLog.Location = New-Object System.Drawing.Point(20, 120)
$txtLog.Size = New-Object System.Drawing.Size(900, 420)

# Summary page content
$lblSummary = New-Object System.Windows.Forms.Label
$lblSummary.Text = "Confirm your settings before installation:"
$lblSummary.AutoSize = $true
$lblSummary.Location = New-Object System.Drawing.Point(20, 20)
$pageSummary.Controls.Add($lblSummary)

$txtSummary = New-Object System.Windows.Forms.TextBox
$txtSummary.Multiline = $true
$txtSummary.ReadOnly = $true
$txtSummary.ScrollBars = 'Vertical'
$txtSummary.Location = New-Object System.Drawing.Point(20, 50)
$txtSummary.Size = New-Object System.Drawing.Size(900, 450)
$pageSummary.Controls.Add($txtSummary)

# Finish page content
$lblFinish = New-Object System.Windows.Forms.Label
$lblFinish.Text = (T 'InstallComplete') + " You can close this wizard."
$lblFinish.AutoSize = $true
$lblFinish.Location = New-Object System.Drawing.Point(20, 20)
$pageFinish.Controls.Add($lblFinish)
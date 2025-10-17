Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Basic fonts shared across the mockup
$uiFonts = @{
	Header = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
	Body   = New-Object System.Drawing.Font('Segoe UI', 11)
	Small  = New-Object System.Drawing.Font('Segoe UI', 9)
}

# Form shell
$form = New-Object System.Windows.Forms.Form
$form.Text = 'PixelSetup'
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ClientSize = New-Object System.Drawing.Size(640, 400)
$form.BackColor = [System.Drawing.Color]::White

$mainPanel = New-Object System.Windows.Forms.Panel
$mainPanel.Dock = 'Fill'
$mainPanel.Padding = New-Object System.Windows.Forms.Padding(24, 24, 24, 16)
$mainPanel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($mainPanel)

$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Dock = 'Bottom'
$footerPanel.Height = 56
$footerPanel.BackColor = [System.Drawing.Color]::White
$footerPanel.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 8)
$form.Controls.Add($footerPanel)

$NextButton = New-Object System.Windows.Forms.Button
$NextButton.Text = 'Next'
$NextButton.Width = 96
$NextButton.Height = 32
$NextButton.Anchor = 'Bottom,Right'
$footerPanel.Controls.Add($NextButton)

$BackButton = New-Object System.Windows.Forms.Button
$BackButton.Text = 'Back'
$BackButton.Width = 96
$BackButton.Height = 32
$BackButton.Anchor = 'Bottom,Right'
$footerPanel.Controls.Add($BackButton)

$SecondaryButton = New-Object System.Windows.Forms.Button
$SecondaryButton.Text = 'Secondary'
$SecondaryButton.Width = 120
$SecondaryButton.Height = 32
$SecondaryButton.Anchor = 'Bottom,Right'
$SecondaryButton.Visible = $false
$footerPanel.Controls.Add($SecondaryButton)

$CloseButton = New-Object System.Windows.Forms.Button
$CloseButton.Text = 'Close'
$CloseButton.Width = 96
$CloseButton.Height = 32
$CloseButton.Anchor = 'Bottom,Left'
$footerPanel.Controls.Add($CloseButton)

# --- Compute and set control positions after they've been added to the panel ---
$rightMargin = 16
$interButtonGap = 8
$topOffset = 12
$panelWidth = $footerPanel.ClientSize.Width

# Place Next button at right
$xNext = [int]($panelWidth - $rightMargin - $NextButton.Width)
$NextButton.Location = New-Object System.Drawing.Point($xNext, $topOffset)

# Place Back button to the left of Next
$xBack = $NextButton.Left - $interButtonGap - $BackButton.Width
$BackButton.Location = New-Object System.Drawing.Point($xBack, $topOffset)

# Place Secondary to the left of Back
$xSecondary = $BackButton.Left - $interButtonGap - $SecondaryButton.Width
$SecondaryButton.Location = New-Object System.Drawing.Point($xSecondary, $topOffset)

# Place Close at left
$CloseButton.Location = New-Object System.Drawing.Point(0, $topOffset)

$script:steps = @()
$script:currentIndex = 0
$script:uiState = @{ ActiveTimer = $null }

function Stop-ActiveTimer {
	if ($script:uiState.ActiveTimer -ne $null) {
		$script:uiState.ActiveTimer.Stop()
		$script:uiState.ActiveTimer.Dispose()
		$script:uiState.ActiveTimer = $null
	}
}

function Move-Next {
	if ($script:currentIndex -lt $script:steps.Count - 1) {
		$script:currentIndex++
		Show-Step
	}
	else {
		$form.Close()
	}
}

function Move-Previous {
	if ($script:currentIndex -gt 0) {
		$script:currentIndex--
		Show-Step
	}
}

function Show-Step {
	Stop-ActiveTimer
	foreach ($ctrl in @($mainPanel.Controls)) {
		$ctrl.Dispose()
	}
	$mainPanel.Controls.Clear()

	$step = $script:steps[$script:currentIndex]
	$metadata = & $step.Render $mainPanel $uiFonts

	$BackButton.Enabled = $script:currentIndex -gt 0
	$BackButton.Visible = $true
	$NextButton.Visible = $true
	$SecondaryButton.Visible = $false
	$NextButton.Enabled = $true
	$SecondaryButton.Tag = $null
	$NextButton.Tag = $null

	$NextButton.Text = if ($script:currentIndex -eq $script:steps.Count - 1) { 'Restart now' } else { 'Next' }

	if ($metadata) {
		if ($metadata.ContainsKey('NextText')) { $NextButton.Text = $metadata.NextText }
		if ($metadata.ContainsKey('NextEnabled')) { $NextButton.Enabled = $metadata.NextEnabled }
		if ($metadata.ContainsKey('BackEnabled')) { $BackButton.Enabled = $metadata.BackEnabled }
		if ($metadata.ContainsKey('BackVisible')) { $BackButton.Visible = $metadata.BackVisible }
		if ($metadata.ContainsKey('NextVisible')) { $NextButton.Visible = $metadata.NextVisible }
		if ($metadata.ContainsKey('Secondary')) {
			$SecondaryButton.Text = $metadata.Secondary.Text
			$SecondaryButton.Visible = $true
			$SecondaryButton.Enabled = $metadata.Secondary.ContainsKey('Enabled') ? $metadata.Secondary.Enabled : $true
			$SecondaryButton.Tag = $metadata.Secondary
		}
		if ($metadata.ContainsKey('NextAction')) {
			$NextButton.Tag = $metadata
		}
		if ($metadata.ContainsKey('Timer')) {
			$script:uiState.ActiveTimer = $metadata.Timer
		}
	}

	$form.AcceptButton = if ($NextButton.Visible -and $NextButton.Enabled) { $NextButton } else { $null }
}

# Load steps from external files and assemble in order
$stepsDir = Join-Path $PSScriptRoot 'Steps'
Get-ChildItem -Path $stepsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

$script:steps = @(
	(Get-Step-Welcome)
	(Get-Step-Landing)
	(Get-Step-Wim)
	(Get-Step-Edition)
	(Get-Step-ProductKey)
	(Get-Step-DriveSelect)
	(Get-Step-DriveSetup)
	(Get-Step-Installing)
	(Get-Step-Complete)
)

$CloseButton.Add_Click({ $form.Close() })
$BackButton.Add_Click({ Move-Previous })
$NextButton.Add_Click({
	$meta = $NextButton.Tag
	if ($meta -and $meta.ContainsKey('NextAction')) {
		$result = & $meta.NextAction
		if ($result -eq $false) { return }
	}
	Move-Next
})
$SecondaryButton.Add_Click({
	$meta = $SecondaryButton.Tag
	if ($meta -and $meta.ContainsKey('Action')) {
		& $meta.Action
	}
})

$form.Add_FormClosing({ Stop-ActiveTimer })

[System.Windows.Forms.Application]::EnableVisualStyles()
Show-Step
[void][System.Windows.Forms.Application]::Run($form)

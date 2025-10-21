Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Resolve script root and image path
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }
$ImagePath = Join-Path $ScriptRoot 'placeholder.jpg'

if (-not (Test-Path $ImagePath)) {
    [System.Windows.Forms.MessageBox]::Show("Image not found at:`n$ImagePath", "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    exit 1
}

# Load the image
$image = [System.Drawing.Image]::FromFile($ImagePath)

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Text = 'PixelRecovery Placeholder'
$form.Icon = [System.Drawing.SystemIcons]::Information
$form.AutoSize = $true
$form.AutoSizeMode = 'GrowAndShrink'  # size = image + citation, no manual resizing

# --- Layout ---
$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.AutoSize = $true
$layout.AutoSizeMode = 'GrowAndShrink'
$layout.ColumnCount = 1
$layout.RowCount = 2
$layout.Padding = New-Object System.Windows.Forms.Padding(0)
$layout.Margin = New-Object System.Windows.Forms.Padding(0)
$null = $layout.ColumnStyles.Add( ([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent, 100)) )
$null = $layout.RowStyles.Add(    ([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize)) )
$null = $layout.RowStyles.Add(    ([System.Windows.Forms.RowStyle]::new([System.Windows.Forms.SizeType]::AutoSize)) )

# --- Image ---
$pictureBox = New-Object System.Windows.Forms.PictureBox
$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::AutoSize  # Native size = image size
$pictureBox.Image = $image
$pictureBox.Margin = New-Object System.Windows.Forms.Padding(0)

# Tooltip
$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.SetToolTip($pictureBox, 'PixelRecovery development has not been started yet. In the meantime, enjoy this image of Lena Raine!')

# --- Citation (wrap to image width, adds only the needed height) ---
$label = New-Object System.Windows.Forms.Label
$label.AutoSize = $true
$label.Text = 'Sara Ranlett, CC BY-SA 4.0 <https://creativecommons.org/licenses/by-sa/4.0>, via Wikimedia Commons'
$label.TextAlign = 'MiddleCenter'
$label.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Italic)
$label.ForeColor = [System.Drawing.Color]::Gray
$label.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
$label.MaximumSize = New-Object System.Drawing.Size($image.Width, 0)  # Wrap to image width
$label.Dock = 'Top'  # Use full width; height auto-sizes to wrapped text

# Assemble
$layout.Controls.Add($pictureBox, 0, 0)
$layout.Controls.Add($label, 0, 1)
$form.Controls.Add($layout)

# Dispose the image when the form closes (release file lock)
$form.Add_FormClosed({ $image.Dispose() })

# Show
[void]$form.ShowDialog()

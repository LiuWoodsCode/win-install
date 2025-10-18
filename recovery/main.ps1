Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Form ---
$form = New-Object System.Windows.Forms.Form
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Text = 'PixelRecovery'
$form.Icon = [System.Drawing.SystemIcons]::Information
$form.Size = New-Object System.Drawing.Size(400, 200)

# Show
[void]$form.ShowDialog()

function Get-Step-DriveSetup {
    return @{
        Name = 'DriveSetup'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'Let''s set up your drive'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $panel.Controls.Add($title)

            $desc = New-Object System.Windows.Forms.Label
            $desc.Text = 'The advanced partitioning tool isn''t available yet, but you can choose one of these preset options:'
            $desc.Font = $fonts.Body
            $desc.Size = New-Object System.Drawing.Size(520, 48)
            $desc.Location = New-Object System.Drawing.Point(0, 48)
            $panel.Controls.Add($desc)

            $fullInstall = New-Object System.Windows.Forms.RadioButton
            $fullInstall.Text = 'Full install'
            $fullInstall.Font = $fonts.Body
            $fullInstall.Location = New-Object System.Drawing.Point(0, 108)
            $fullInstall.AutoSize = $true
            $fullInstall.Checked = $true
            $panel.Controls.Add($fullInstall)

            $noRecovery = New-Object System.Windows.Forms.RadioButton
            $noRecovery.Text = 'No recovery partition'
            $noRecovery.Font = $fonts.Body
            $noRecovery.Location = New-Object System.Drawing.Point(0, 144)
            $noRecovery.AutoSize = $true
            $panel.Controls.Add($noRecovery)

            $testMode = New-Object System.Windows.Forms.RadioButton
            $testMode.Text = 'Test Mode (no partitioning, put all files in C:/Test)'
            $testMode.Font = $fonts.Body
            $testMode.Location = New-Object System.Drawing.Point(0, 180)
            $testMode.AutoSize = $true
            $panel.Controls.Add($testMode)

            $refs = New-Object System.Windows.Forms.CheckBox
            $refs.Text = 'Use ReFS instead of NTFS (experimental)'
            $refs.Font = $fonts.Body
            $refs.Location = New-Object System.Drawing.Point(0, 220)
            $refs.AutoSize = $true
            $panel.Controls.Add($refs)

            return @{
                NextAction = {
                    $result = [System.Windows.Forms.MessageBox]::Show('This will erase everything on the selected drive. Make sure you''ve backed up any important files before continuing.', 'PixelSetup', [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)
                    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $false }
                }
            }
        }
    }
}

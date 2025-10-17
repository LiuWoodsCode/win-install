function Get-Step-Wim {
    return @{
        Name = 'Wim'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'Let''s find your WIM file'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $panel.Controls.Add($title)

            $desc = New-Object System.Windows.Forms.Label
            $desc.Text = "We need the location of your Windows image file (.wim) to continue. Enter the full path to your WIM file (for example, D:\sources\install.wim)."
            $desc.Font = $fonts.Body
            $desc.Size = New-Object System.Drawing.Size(520, 60)
            $desc.Location = New-Object System.Drawing.Point(0, 48)
            $panel.Controls.Add($desc)

            $pathBox = New-Object System.Windows.Forms.TextBox
            $pathBox.Font = $fonts.Body
            $pathBox.Size = New-Object System.Drawing.Size(400, 28)
            $pathBox.Location = New-Object System.Drawing.Point(0, 120)
            $pathBox.Text = 'D:\sources\install.wim'
            $panel.Controls.Add($pathBox)

            $browseButton = New-Object System.Windows.Forms.Button
            $browseButton.Text = 'Browse'
            $browseButton.Font = $fonts.Small
            $browseButton.Size = New-Object System.Drawing.Size(96, 28)
            $browseButton.Location = New-Object System.Drawing.Point(408, 120)
            $browseButton.Add_Click({
                $dialog = New-Object System.Windows.Forms.OpenFileDialog
                $dialog.Filter = 'WIM files (*.wim)|*.wim|All files (*.*)|*.*'
                if ($dialog.ShowDialog() -eq 'OK') {
                    $pathBox.Text = $dialog.FileName
                }
                $dialog.Dispose()
            })
            $panel.Controls.Add($browseButton)

            return @{}
        }
    }
}

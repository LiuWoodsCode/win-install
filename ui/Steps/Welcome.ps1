function Get-Step-Welcome {
    return @{
        Name = 'Welcome'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'Welcome!'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $title.Location = New-Object System.Drawing.Point(0, 0)
            $panel.Controls.Add($title)

            $subtitle = New-Object System.Windows.Forms.Label
            $subtitle.Text = 'Please select your regional preferences.'
            $subtitle.Font = $fonts.Body
            $subtitle.AutoSize = $true
            $subtitle.Location = New-Object System.Drawing.Point(0, 44)
            $panel.Controls.Add($subtitle)

            $regionLabel = New-Object System.Windows.Forms.Label
            $regionLabel.Text = 'Region:'
            $regionLabel.Font = $fonts.Body
            $regionLabel.AutoSize = $true
            $regionLabel.Location = New-Object System.Drawing.Point(0, 96)
            $panel.Controls.Add($regionLabel)

            $regionCombo = New-Object System.Windows.Forms.ComboBox
            $regionCombo.Font = $fonts.Body
            $regionCombo.DropDownStyle = 'DropDownList'
            $regionCombo.Size = New-Object System.Drawing.Size(296, 28)
            $regionCombo.Location = New-Object System.Drawing.Point(0, 124)
            $regionCombo.Items.AddRange(@('English (United States)', 'English (United Kingdom)', 'Deutsch (Deutschland)', '日本語'))
            $regionCombo.SelectedIndex = 0
            $panel.Controls.Add($regionCombo)

            $keyboardLabel = New-Object System.Windows.Forms.Label
            $keyboardLabel.Text = 'Keyboard layout:'
            $keyboardLabel.Font = $fonts.Body
            $keyboardLabel.AutoSize = $true
            $keyboardLabel.Location = New-Object System.Drawing.Point(0, 172)
            $panel.Controls.Add($keyboardLabel)

            $keyboardCombo = New-Object System.Windows.Forms.ComboBox
            $keyboardCombo.Font = $fonts.Body
            $keyboardCombo.DropDownStyle = 'DropDownList'
            $keyboardCombo.Size = New-Object System.Drawing.Size(296, 28)
            $keyboardCombo.Location = New-Object System.Drawing.Point(0, 200)
            $keyboardCombo.Items.AddRange(@('US', 'US International', 'UK', 'German', 'Japanese'))
            $keyboardCombo.SelectedIndex = 0
            $panel.Controls.Add($keyboardCombo)

            return @{ BackEnabled = $false }
        }
    }
}

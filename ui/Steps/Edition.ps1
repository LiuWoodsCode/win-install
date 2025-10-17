function Get-Step-Edition {
    return @{
        Name = 'Edition'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'Let''s choose your edition'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $panel.Controls.Add($title)

            $desc = New-Object System.Windows.Forms.Label
            $desc.Text = 'Select the edition of Windows you want to install. It should match your product key.'
            $desc.Font = $fonts.Body
            $desc.Size = New-Object System.Drawing.Size(500, 48)
            $desc.Location = New-Object System.Drawing.Point(0, 48)
            $panel.Controls.Add($desc)

            $list = New-Object System.Windows.Forms.ListBox
            $list.Font = $fonts.Body
            $list.Size = New-Object System.Drawing.Size(400, 120)
            $list.Location = New-Object System.Drawing.Point(0, 108)
            $list.Items.AddRange(@('Windows 11 Pro', 'Windows 11 Pro N', 'Windows 11 Enterprise', 'Windows 11 Education'))
            $panel.Controls.Add($list)

            return @{
                NextAction = {
                    return $true
                }
            }
        }
    }
}

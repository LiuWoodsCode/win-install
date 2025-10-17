function Get-Step-DriveSelect {
    return @{
        Name = 'DriveSelect'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'Let''s choose where to install Windows'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $panel.Controls.Add($title)

            $desc = New-Object System.Windows.Forms.Label
            $desc.Text = 'Choose the drive where you''d like to install Windows. All existing data on that drive will be erased during setup.'
            $desc.Font = $fonts.Body
            $desc.Size = New-Object System.Drawing.Size(520, 48)
            $desc.Location = New-Object System.Drawing.Point(0, 48)
            $panel.Controls.Add($desc)

            $listView = New-Object System.Windows.Forms.ListView
            $listView.View = 'Details'
            $listView.FullRowSelect = $true
            $listView.HideSelection = $false
            $listView.Size = New-Object System.Drawing.Size(500, 180)
            $listView.Location = New-Object System.Drawing.Point(0, 108)
            $listView.Columns.Add('ID', 40) | Out-Null
            $listView.Columns.Add('Name', 280) | Out-Null
            $listView.Columns.Add('Size', 120) | Out-Null

            foreach ($item in @(
                @{ Id = '0'; Name = 'Western Digital WD5000LPLX'; Size = '500GB' },
                @{ Id = '1'; Name = 'SeaDisk Trip'; Size = '2GB' },
                @{ Id = '2'; Name = 'Alan Turing HDD'; Size = '999PB' },
                @{ Id = '3'; Name = 'Apple iPhone 14'; Size = '128GB' }
            )) {
                $listItem = New-Object System.Windows.Forms.ListViewItem($item.Id)
                $listItem.SubItems.Add($item.Name) | Out-Null
                $listItem.SubItems.Add($item.Size) | Out-Null
                $listView.Items.Add($listItem) | Out-Null
            }

            $panel.Controls.Add($listView)

            return @{
                NextAction = {
                    return $true
                    }
                }
            }
        }
    }
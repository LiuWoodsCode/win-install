function Get-Step-Landing {
    return @{
        Name = 'Landing'
        Render = {
            param($panel, $fonts)

            $title = New-Object System.Windows.Forms.Label
            $title.Text = 'What would you like to do?'
            $title.Font = $fonts.Header
            $title.AutoSize = $true
            $title.Location = New-Object System.Drawing.Point(0, 0)
            $panel.Controls.Add($title)

            $installButton = New-Object System.Windows.Forms.Button
            $installButton.Text = 'Install Windows'
            $installButton.Font = $fonts.Body
            $installButton.Size = New-Object System.Drawing.Size(200, 40)
            $installButton.Location = New-Object System.Drawing.Point(0, 64)
            $installButton.Add_Click({ Move-Next })
            $panel.Controls.Add($installButton)

            $repairButton = New-Object System.Windows.Forms.Button
            $repairButton.Text = 'Repair my PC'
            $repairButton.Font = $fonts.Body
            $repairButton.Size = New-Object System.Drawing.Size(200, 40)
            $repairButton.Location = New-Object System.Drawing.Point(0, 120)
            $repairButton.Add_Click({ [System.Windows.Forms.MessageBox]::Show('Repair tools are not included in this mockup.', 'PixelSetup') })
            $panel.Controls.Add($repairButton)

            $legal = New-Object System.Windows.Forms.Label
            $legal.Text = "PixelSetup is licensed under the GPL v3 license.`r`n© Microsoft Corporation, all rights reserved for Microsoft Windows.`r`nClick here for more information"
            $legal.Font = $fonts.Small
            $legal.AutoSize = $true
            $legal.Location = New-Object System.Drawing.Point(0, 200)
            $panel.Controls.Add($legal)

            return @{ BackVisible = $false; NextVisible = $false }
        }
    }
}

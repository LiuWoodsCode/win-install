function New-PixelSetupWelcomePage {
    param(
        [string]$BuildTag,
        [string]$WindowsBuild,
        [bool]$IsWinPE
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $lblWelcome = New-Object System.Windows.Forms.Label
    $lblWelcome.Text = "Install Windows`r`n`r`nChoose Next to continue, or Repair to open recovery tools."
    $lblWelcome.AutoSize = $true
    $lblWelcome.Location = New-Object System.Drawing.Point(20,20)
    $panel.Controls.Add($lblWelcome)

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "PixelPE Build: $BuildTag`r`nWindows Build: $WindowsBuild"
    $lblInfo.AutoSize = $true
    $lblInfo.Location = New-Object System.Drawing.Point(20,500)
    $panel.Controls.Add($lblInfo)

    $btnRepair = New-Object System.Windows.Forms.Button
    $btnRepair.Text = (T 'Repair')
    $btnRepair.Location = New-Object System.Drawing.Point(20,90)
    $btnRepair.Size = New-Object System.Drawing.Size(120,35)
    $btnRepair.Enabled = $IsWinPE
    $panel.Controls.Add($btnRepair)

    return [pscustomobject]@{
        Name = 'Welcome'
        Panel = $panel
        Controls = @{
            RepairButton = $btnRepair
            WelcomeLabel = $lblWelcome
            InfoLabel = $lblInfo
        }
    }
}
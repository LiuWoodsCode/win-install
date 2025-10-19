function New-PixelSetupFinishPage {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $lblFinish = New-Object System.Windows.Forms.Label
    $lblFinish.Text = (T 'InstallComplete') + " You can close this wizard."
    $lblFinish.AutoSize = $true
    $lblFinish.Location = New-Object System.Drawing.Point(20,20)
    $panel.Controls.Add($lblFinish)

    return [pscustomobject]@{
        Name = 'Finish'
        Panel = $panel
        Controls = @{
            FinishLabel = $lblFinish
        }
    }
}
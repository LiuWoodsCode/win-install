function New-PixelSetupSummaryPage {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $lblSummary = New-Object System.Windows.Forms.Label
    $lblSummary.Text = "Confirm your settings before installation:"
    $lblSummary.AutoSize = $true
    $lblSummary.Location = New-Object System.Drawing.Point(20,20)
    $panel.Controls.Add($lblSummary)

    $txtSummary = New-Object System.Windows.Forms.TextBox
    $txtSummary.Multiline = $true
    $txtSummary.ReadOnly = $true
    $txtSummary.ScrollBars = 'Vertical'
    $txtSummary.Location = New-Object System.Drawing.Point(20,50)
    $txtSummary.Size = New-Object System.Drawing.Size(900,450)
    $panel.Controls.Add($txtSummary)

    return [pscustomobject]@{
        Name = 'Summary'
        Panel = $panel
        Controls = @{
            SummaryLabel   = $lblSummary
            SummaryTextbox = $txtSummary
        }
    }
}
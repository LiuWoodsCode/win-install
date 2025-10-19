function New-PixelSetupInstallPage {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $gbProgress = New-Object System.Windows.Forms.GroupBox
    $gbProgress.Text = (T 'ProgressTitle')
    $gbProgress.Location = New-Object System.Drawing.Point(20,20)
    $gbProgress.Size = New-Object System.Drawing.Size(940,80)
    $panel.Controls.Add($gbProgress)

    $lblStepName = New-Object System.Windows.Forms.Label
    $lblStepName.Text = (T 'StepLabelReady')
    $lblStepName.AutoSize = $true
    $lblStepName.Location = New-Object System.Drawing.Point(12,22)
    $gbProgress.Controls.Add($lblStepName)

    $pbStep = New-Object System.Windows.Forms.ProgressBar
    $pbStep.Location = New-Object System.Drawing.Point(120,20)
    $pbStep.Size = New-Object System.Drawing.Size(800,18)
    $pbStep.Minimum = 0
    $pbStep.Maximum = 100
    $pbStep.Value = 0
    $gbProgress.Controls.Add($pbStep)

    $lblTotal = New-Object System.Windows.Forms.Label
    $lblTotal.Text = (T 'Overall0')
    $lblTotal.AutoSize = $true
    $lblTotal.Location = New-Object System.Drawing.Point(12,50)
    $gbProgress.Controls.Add($lblTotal)

    $pbTotal = New-Object System.Windows.Forms.ProgressBar
    $pbTotal.Location = New-Object System.Drawing.Point(120,48)
    $pbTotal.Size = New-Object System.Drawing.Size(800,18)
    $pbTotal.Minimum = 0
    $pbTotal.Maximum = 100
    $pbTotal.Value = 0
    $gbProgress.Controls.Add($pbTotal)

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Multiline = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.ReadOnly = $true
    $txtLog.Location = New-Object System.Drawing.Point(20,120)
    $txtLog.Size = New-Object System.Drawing.Size(900,420)
    $panel.Controls.Add($txtLog)

    return [pscustomobject]@{
        Name = 'Installing'
        Panel = $panel
        Controls = @{
            StepLabel        = $lblStepName
            StepProgressBar  = $pbStep
            TotalLabel       = $lblTotal
            TotalProgressBar = $pbTotal
            LogTextbox       = $txtLog
        }
    }
}
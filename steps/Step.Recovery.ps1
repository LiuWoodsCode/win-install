function New-PixelSetupRecoveryPage {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $gbWinRE = New-Object System.Windows.Forms.GroupBox
    $gbWinRE.Text = (T 'GroupWinRETitle')
    $gbWinRE.Location = New-Object System.Drawing.Point(20,20)
    $gbWinRE.Size = New-Object System.Drawing.Size(460,120)
    $panel.Controls.Add($gbWinRE)

    $rbReFull = New-Object System.Windows.Forms.RadioButton
    $rbReFull.Text = (T 'ReFull')
    $rbReFull.Location = New-Object System.Drawing.Point(12,25)
    $rbReFull.AutoSize = $true
    $rbReFull.Checked = $true
    $gbWinRE.Controls.Add($rbReFull)

    $rbReSkip = New-Object System.Windows.Forms.RadioButton
    $rbReSkip.Text = (T 'ReSkip')
    $rbReSkip.Location = New-Object System.Drawing.Point(12,50)
    $rbReSkip.AutoSize = $true
    $gbWinRE.Controls.Add($rbReSkip)

    $rbReNone = New-Object System.Windows.Forms.RadioButton
    $rbReNone.Text = (T 'ReNone')
    $rbReNone.Location = New-Object System.Drawing.Point(12,75)
    $rbReNone.AutoSize = $true
    $gbWinRE.Controls.Add($rbReNone)

    return [pscustomobject]@{
        Name = 'Recovery'
        Panel = $panel
        Controls = @{
            FullRadio = $rbReFull
            SkipRadio = $rbReSkip
            NoneRadio = $rbReNone
        }
    }
}
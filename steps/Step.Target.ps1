function New-PixelSetupTargetPage {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $gbTarget = New-Object System.Windows.Forms.GroupBox
    $gbTarget.Text = (T 'GroupTargetTitle')
    $gbTarget.Location = New-Object System.Drawing.Point(20,20)
    $gbTarget.Size = New-Object System.Drawing.Size(900,220)
    $panel.Controls.Add($gbTarget)

    $cbTest = New-Object System.Windows.Forms.CheckBox
    $cbTest.Text = (T 'TestModeLabel')
    $cbTest.Location = New-Object System.Drawing.Point(12,25)
    $cbTest.AutoSize = $true
    $gbTarget.Controls.Add($cbTest)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = (T 'RefreshDisks')
    $btnRefresh.Location = New-Object System.Drawing.Point(320,20)
    $btnRefresh.Size = New-Object System.Drawing.Size(120,25)
    $gbTarget.Controls.Add($btnRefresh)

    $lvDisks = New-Object System.Windows.Forms.ListView
    $lvDisks.Location = New-Object System.Drawing.Point(12,55)
    $lvDisks.Size = New-Object System.Drawing.Size(428,150)
    $lvDisks.View = 'Details'
    $lvDisks.FullRowSelect = $true
    $null = $lvDisks.Columns.Add((T 'ColumnNumber'),60)
    $null = $lvDisks.Columns.Add((T 'ColumnFriendlyName'),180)
    $null = $lvDisks.Columns.Add((T 'ColumnSizeGB'),90)
    $null = $lvDisks.Columns.Add((T 'ColumnStyle'),80)
    $gbTarget.Controls.Add($lvDisks)

    return [pscustomobject]@{
        Name = 'Target'
        Panel = $panel
        Controls = @{
            TestModeCheckbox = $cbTest
            RefreshButton    = $btnRefresh
            DiskListView     = $lvDisks
        }
    }
}
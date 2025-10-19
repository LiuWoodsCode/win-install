function New-PixelSetupImagePage {
    param([string]$DefaultImagePath)

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $gbImage = New-Object System.Windows.Forms.GroupBox
    $gbImage.Text = (T 'GroupImageTitle')
    $gbImage.Location = New-Object System.Drawing.Point(20,20)
    $gbImage.Size = New-Object System.Drawing.Size(940,130)
    $panel.Controls.Add($gbImage)

    $lblPath = New-Object System.Windows.Forms.Label
    $lblPath.Text = (T 'ImagePathLabel')
    $lblPath.AutoSize = $true
    $lblPath.Location = New-Object System.Drawing.Point(12,28)
    $gbImage.Controls.Add($lblPath)

    $txtPath = New-Object System.Windows.Forms.TextBox
    $txtPath.Location = New-Object System.Drawing.Point(140,25)
    $txtPath.Size = New-Object System.Drawing.Size(650,23)
    $txtPath.Text = $DefaultImagePath
    $gbImage.Controls.Add($txtPath)

    $btnBrowse = New-Object System.Windows.Forms.Button
    $btnBrowse.Text = (T 'Browse')
    $btnBrowse.Location = New-Object System.Drawing.Point(800,24)
    $btnBrowse.Size = New-Object System.Drawing.Size(120,25)
    $gbImage.Controls.Add($btnBrowse)

    $btnList = New-Object System.Windows.Forms.Button
    $btnList.Text = (T 'ListImages')
    $btnList.Location = New-Object System.Drawing.Point(800,60)
    $btnList.Size = New-Object System.Drawing.Size(120,25)
    $gbImage.Controls.Add($btnList)

    $lblIndex = New-Object System.Windows.Forms.Label
    $lblIndex.Text = (T 'SelectIndexLabel')
    $lblIndex.AutoSize = $true
    $lblIndex.Location = New-Object System.Drawing.Point(12,65)
    $gbImage.Controls.Add($lblIndex)

    $cmbIndexes = New-Object System.Windows.Forms.ComboBox
    $cmbIndexes.DropDownStyle = 'DropDownList'
    $cmbIndexes.Location = New-Object System.Drawing.Point(140,62)
    $cmbIndexes.Size = New-Object System.Drawing.Size(650,23)
    $gbImage.Controls.Add($cmbIndexes)

    $lblFs = New-Object System.Windows.Forms.Label
    $lblFs.Text = (T 'FSLabel')
    $lblFs.AutoSize = $true
    $lblFs.Location = New-Object System.Drawing.Point(12,95)
    $gbImage.Controls.Add($lblFs)

    $rbFsNtfs = New-Object System.Windows.Forms.RadioButton
    $rbFsNtfs.Text = (T 'FSNTFS')
    $rbFsNtfs.Location = New-Object System.Drawing.Point(200,93)
    $rbFsNtfs.AutoSize = $true
    $rbFsNtfs.Checked = $true
    $gbImage.Controls.Add($rbFsNtfs)

    $rbFsRefs = New-Object System.Windows.Forms.RadioButton
    $rbFsRefs.Text = (T 'FSReFS')
    $rbFsRefs.Location = New-Object System.Drawing.Point(330,93)
    $rbFsRefs.AutoSize = $true
    $rbFsRefs.Enabled = $false
    $gbImage.Controls.Add($rbFsRefs)

    return [pscustomobject]@{
        Name = 'Image'
        Panel = $panel
        Controls = @{
            PathTextbox      = $txtPath
            BrowseButton     = $btnBrowse
            ListImagesButton = $btnList
            IndexCombo       = $cmbIndexes
            FsLabel          = $lblFs
            FsNtfsRadio      = $rbFsNtfs
            FsRefsRadio      = $rbFsRefs
        }
    }
}
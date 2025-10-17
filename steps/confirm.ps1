# Summary builder split from main

function Build-Summary {
    try {
        $imgPath = $script:txtPath.Text
        $sel = $script:cmbIndexes.SelectedItem
        $idx = if ($sel) { $sel.Index } else { '(not selected)' }
        $build = if ($sel -and ($sel.PSObject.Properties.Name -contains 'Build')) { $sel.Build } else { 'n/a' }
        $fsChoice = if ($script:rbFsRefs.Checked) { 'ReFS' } else { 'NTFS' }
        $reMode = if ($script:rbReFull.Checked) { 'Full (WinRE)' } elseif ($script:rbReSkip.Checked) { 'Skip WinRE' } else { 'No Recovery' }
        $target = if ($script:cbTest.Checked) { 'Test Mode (C:\\Test)' } else {
            if ($script:lvDisks.SelectedItems.Count -gt 0) {
                $it = $script:lvDisks.SelectedItems[0]; "Disk #$($it.SubItems[0].Text) - $($it.SubItems[1].Text)"
            } else { '(no disk selected)' }
        }
        $script:txtSummary.Text = @(
            "Image path: $imgPath",
            "Index: $idx  Build: $build",
            "File system: $fsChoice",
            "Recovery: $reMode",
            "Target: $target",
            "WinPE detected: $Global:IsWinPE"
        ) -join [Environment]::NewLine
    } catch { $script:txtSummary.Text = "Unable to build summary: $($_.Exception.Message)" }
}

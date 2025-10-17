# Disk selection helpers split from main

function Refresh-Disks {
    Log "Refresh-Disks: Enumerating disks..."
    $script:lvDisks.Items.Clear()
    $disks = Get-Disk | Select-Object Number, FriendlyName, Size, PartitionStyle
    foreach ($d in $disks) {
        $sizeGB = [Math]::Round($d.Size/1GB,2)
        Log ("Refresh-Disks: Disk {0} '{1}' Size={2}GB Style={3}" -f $d.Number,$d.FriendlyName,$sizeGB,$d.PartitionStyle)
        $item = New-Object System.Windows.Forms.ListViewItem($d.Number.ToString())
        $null = $item.SubItems.Add($d.FriendlyName)
        $null = $item.SubItems.Add($sizeGB.ToString())
        $null = $item.SubItems.Add($d.PartitionStyle.ToString())
        $null = $script:lvDisks.Items.Add($item)
    }
    Log "Refresh-Disks: Total disks listed: $($disks.Count)"
}

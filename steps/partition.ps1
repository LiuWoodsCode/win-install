# Partitioning helpers split from main

function Get-UsedDriveLetters {
    try {
        return ([System.IO.DriveInfo]::GetDrives().Name | ForEach-Object { $_.Substring(0,1).ToUpper() })
    } catch {
        return @()
    }
}

function Get-PreferredOrRandomDriveLetter {
    param(
        [Parameter(Mandatory)][string]$Preferred,
        [string[]]$Exclude = @()
    )
    $used = (Get-UsedDriveLetters)
    $avoid = @('X') + $Exclude
    $preferredFree = ($used -notcontains $Preferred.ToUpper()) -and ($avoid -notcontains $Preferred.ToUpper())
    if ($preferredFree) { return $Preferred.ToUpper() }

    $all = "CDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray() | ForEach-Object { $_.ToString() }
    $free = $all | Where-Object { ($used -notcontains $_) -and ($avoid -notcontains $_) }
    if (-not $free -or $free.Count -eq 0) { return "Z" }
    return Get-Random -InputObject $free
}

function Select-PartitionLetters {
    param([int]$ReMode)
    $efi = Get-PreferredOrRandomDriveLetter -Preferred 'S'
    $win = Get-PreferredOrRandomDriveLetter -Preferred 'C' -Exclude @($efi)
    $rec = $null
    if ($ReMode -ne 3) {
        $rec = Get-PreferredOrRandomDriveLetter -Preferred 'R' -Exclude @($efi,$win)
    }
    return [pscustomobject]@{
        Efi      = $efi
        Windows  = $win
        Recovery = $rec
    }
}

function Make-PartitionScript {
    param(
        [int]$DiskNumber,
        [int]$ReMode,
        [string]$FileSystem,
        [Parameter(Mandatory)][string]$EfiLetter,
        [Parameter(Mandatory)][string]$WindowsLetter,
        [string]$RecoveryLetter
    )
    Log "Make-PartitionScript: Disk=$DiskNumber ReMode=$ReMode (1=Full,2=SkipWinRE,3=NoRecovery) FS=$FileSystem Letters: EFI=$EfiLetter Windows=$WindowsLetter Recovery=$($RecoveryLetter ?? '<n/a>'):"
    $fsTag = if ($FileSystem -and $FileSystem.ToUpper() -eq 'REFS') { 'refs' } else { 'ntfs' }
    if ($ReMode -eq 3) {
        $script = @"
select disk $DiskNumber
clean
convert gpt
create partition efi size=512
format quick fs=fat32 label="System"
assign letter=$EfiLetter
create partition msr size=16
create partition primary
format quick fs=$fsTag label="Windows"
assign letter=$WindowsLetter
exit
"@
    } else {
        $script = @"
select disk $DiskNumber
clean
convert gpt
create partition efi size=512
format quick fs=fat32 label="System"
assign letter=$EfiLetter
create partition msr size=16
create partition primary
format quick fs=$fsTag label="Windows"
assign letter=$WindowsLetter
shrink minimum=750
create partition primary
format quick fs=ntfs label="Recovery"
assign letter=$RecoveryLetter
set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac
gpt attributes=0x8000000000000001
exit
"@
    }
    Log "Make-PartitionScript: Generated script:`n$script"
    return $script
}

function Run-Diskpart {
    param([string]$ScriptContent)
    $temp = Join-Path $env:TEMP "partition.txt"
    Log "Run-Diskpart: Writing script to $temp (Length=$($ScriptContent.Length))"
    $ScriptContent | Out-File $temp -Encoding ascii
    Log "Run-Diskpart: Launching diskpart"
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = diskpart /s $temp 2>&1
    $sw.Stop()
    $out | ForEach-Object { Log ("diskpart: $_") }
    Log ("Run-Diskpart: Completed in {0:N2}s OutputLines={1}" -f $sw.Elapsed.TotalSeconds, $out.Count)
}

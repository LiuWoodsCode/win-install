# WimlibInfoParser.psm1
# Parses `wimlib-imagex info` output into structured PSObjects.
# PowerShell 7+ recommended.

#region Private helpers
function _Normalize-Key {
    param([string]$Key)
    switch ($Key.Trim()) {
        'Image Count' { 'ImageCount' }
        'Chunk Size' { 'ChunkSizeBytes' }
        'Part Number' { 'PartNumber' }
        'Boot Index' { 'BootIndex' }
        'Size' { 'SizeBytes' }
        'Default Language' { 'DefaultLanguage' }
        'Directory Count' { 'DirectoryCount' }
        'File Count' { 'FileCount' }
        'Total Bytes' { 'TotalBytes' }
        'Hard Link Bytes' { 'HardLinkBytes' }
        'Creation Time' { 'CreationTime' }
        'Last Modification Time' { 'LastModificationTime' }
        'Product Name' { 'ProductName' }
        'Edition ID' { 'EditionID' }
        'Installation Type' { 'InstallationType' }
        'Product Type' { 'ProductType' }
        'Product Suite' { 'ProductSuite' }
        'System Root' { 'SystemRoot' }
        'Major Version' { 'MajorVersion' }
        'Minor Version' { 'MinorVersion' }
        'Build' { 'Build' }
        'Service Pack Build' { 'ServicePackBuild' }
        'Service Pack Level' { 'ServicePackLevel' }
        'Display Name' { 'DisplayName' }
        'Display Description' { 'DisplayDescription' }
        'WIMBoot compatible' { 'WIMBootCompatible' }
        default { ($Key -replace '\s+', '') } # Guid, Path, Compression, etc.
    }
}

function _Parse-Date {
    param([string]$Value)
    $formats = @(
        "ddd MMM dd HH:mm:ss yyyy 'UTC'",
        "ddd MMM d HH:mm:ss yyyy 'UTC'"
    )
    foreach ($f in $formats) {
        try {
            return [datetime]::ParseExact(
                $Value.Trim(),
                $f,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                [System.Globalization.DateTimeStyles]::AdjustToUniversal
            )
        }
        catch { }
    }
    return $Value
}

function _Parse-Boolean {
    param([string]$Value)
    switch ($Value.Trim().ToLowerInvariant()) {
        'yes' { $true }
        'no' { $false }
        default { $null }
    }
}

function _Parse-Bytes {
    param([string]$Value)
    # Strip non-digits; safe for "131072 bytes" or "5225886800 bytes"
    $num = $Value -replace '[^\d]', ''
    if ([string]::IsNullOrWhiteSpace($num)) { return $null }
    return [int64]$num
}

function _Parse-Scalar {
    param([string]$Key, [string]$Value)
    $k = $Key.Trim()

    # Bytes fields
    if ($k -in @('Chunk Size', 'Size', 'Total Bytes', 'Hard Link Bytes')) {
        return _Parse-Bytes $Value
    }

    # Int fields
    if ($k -in @('Image Count', 'Boot Index', 'Version', 'Directory Count', 'File Count',
            'Major Version', 'Minor Version', 'Build', 'Service Pack Build', 'Service Pack Level', 'Index')) {
        if ($Value -match '^\s*\d+\s*$') { return [int]$Value }
        return $Value
    }

    # Bool fields
    if ($k -eq 'WIMBoot compatible') {
        $b = _Parse-Boolean $Value
        if ($null -ne $b) { return $b }
    }

    # Date fields
    if ($k -in @('Creation Time', 'Last Modification Time')) {
        return _Parse-Date $Value
    }

    # Languages field -> array if comma-separated
    if ($k -eq 'Languages') {
        if ($Value -match ',') {
            return ($Value -split '\s*,\s*') | Where-Object { $_ -ne '' }
        }
        else {
            return @($Value.Trim())
        }
    }

    # Everything else as string
    return $Value.Trim()
}

function _Parse-KeyValueLine {
    param([string]$Line)
    # Matches "Key:   Value" with any spacing
    if ($Line -match '^\s*([^:]+):\s*(.*)$') {
        $rawKey = $matches[1]
        $rawVal = $matches[2]
        $key = _Normalize-Key $rawKey
        $val = _Parse-Scalar $rawKey $rawVal
        return , @($key, $val)
    }
    return $null
}
#endregion Private helpers

function ConvertFrom-WimlibInfo {
    <#
    .SYNOPSIS
    Converts the text output of `wimlib-imagex info` into a structured object.

    .PARAMETER Text
    The raw text (string or lines) from `wimlib-imagex info`. Accepts pipeline.

    .OUTPUTS
    PSCustomObject with header fields and an Images array of PSCustomObjects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Text
    )
    begin {
        $buffer = New-Object System.Collections.Generic.List[string]
    }
    process {
        if ($null -ne $Text) {
            if ($Text -match "(\r\n|\n)") {
                $Text -split "(\r?\n)" | ForEach-Object {
                    if ($_ -notmatch "(\r?\n)") { $buffer.Add($_) }
                }
            }
            else {
                $buffer.Add($Text)
            }
        }
    }
    end {
        $lines = $buffer | ForEach-Object { $_.TrimEnd() }

        # Find section markers
        $headerStart = ($lines | Select-String -SimpleMatch 'WIM Information:').LineNumber
        $imagesStart = ($lines | Select-String -SimpleMatch 'Available Images:').LineNumber

        if (-not $headerStart) { throw "Could not find 'WIM Information:' section." }
        if (-not $imagesStart) { throw "Could not find 'Available Images:' section." }

        # Parse header (skip the immediate dashed line after the title)
        $header = [ordered]@{}
        for ($i = $headerStart; $i -lt $imagesStart - 1; $i++) {
            $line = $lines[$i]
            if ($line -match '^-{3,}$' -or [string]::IsNullOrWhiteSpace($line)) { continue }
            $kv = _Parse-KeyValueLine $line
            if ($kv) { $header[$kv[0]] = $kv[1] }
        }

        # Parse images
        $images = New-Object System.Collections.Generic.List[object]
        $current = $null

        for ($j = $imagesStart; $j -lt $lines.Count; $j++) {
            $line = $lines[$j]
            if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^-{3,}$') { continue }

            if ($line -match '^\s*Index:\s*(\d+)') {
                # Start new image block
                if ($current) { $images.Add([pscustomobject]$current) }
                $current = [ordered]@{}
                $current['Index'] = [int]$matches[1]
                continue
            }

            $kv = _Parse-KeyValueLine $line
            if ($kv) { $current[$kv[0]] = $kv[1] }
        }
        if ($current) { $images.Add([pscustomobject]$current) }

        # Final object
        $out = [ordered]@{}
        foreach ($k in $header.Keys) { $out[$k] = $header[$k] }
        $out['Images'] = $images.ToArray()

        # Strongly type a few header fields if present
        foreach ($hName in @('Version', 'ImageCount', 'BootIndex')) {
            if ($out.Contains($hName) -and $out[$hName] -isnot [int]) {
                if ($out[$hName] -as [int]) { $out[$hName] = [int]$out[$hName] }
            }
        }
        foreach ($hBytes in @('ChunkSizeBytes', 'SizeBytes')) {
            if ($out.Contains($hBytes) -and $out[$hBytes] -isnot [long]) {
                $out[$hBytes] = _Parse-Bytes ($out[$hBytes] -as [string])
            }
        }

        [pscustomobject]$out
    }
}

function Get-WimEsdInfo {
    <#
    .SYNOPSIS
    Executes `wimlib-imagex info` and parses the output.

    .PARAMETER ImagePath
    Path to the WIM/ESD (e.g., C:\25H2\sources\install.esd)

    .PARAMETER WimlibPath
    Path to wimlib-imagex.exe (default assumes it's on PATH)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath,
        [string]$WimlibPath = './wimlib/wimlib-imagex.exe'
    )
    $cmd = @($WimlibPath, 'info', $ImagePath)
    $raw = & $cmd 2>&1 | Out-String
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "wimlib-imagex exited with code $LASTEXITCODE`n$raw"
    }
    $raw | ConvertFrom-WimlibInfo
}

function Get-WimEsdImage {
    <#
    .SYNOPSIS
    Emits the per-image objects from a ConvertFrom-WimlibInfo/Get-WimEsdInfo result.

    .PARAMETER WimObject
    The object returned by ConvertFrom-WimlibInfo or Get-WimEsdInfo.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$WimObject
    )
    process {
        if ($WimObject.Images) {
            $WimObject.Images
        }
        else {
            Write-Error "No Images property found."
        }
    }
}

# WimlibInfo.psm1
# One function: Get-WimImageInfo
# PowerShell 7+ recommended.

function Get-WimImageInfo {
    <#
    .SYNOPSIS
    Runs `wimlib-imagex info` and returns a structured object containing header info and an Images array.

    .PARAMETER ImagePath
    Path to the WIM/ESD file (e.g., C:\25H2\sources\install.esd)

    .PARAMETER WimlibPath
    Path to wimlib-imagex.exe (default assumes it's on PATH)

    .PARAMETER ExpandImages
    If set, emits the per-image objects directly instead of the top-level header object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath,
        [string]$WimlibPath = 'wimlib-imagex.exe',
        [switch]$ExpandImages
    )

    # --- Local helper scriptblocks (scoped inside the function) ---
    $NormalizeKey = {
        param([string]$Key)
        switch ($Key.Trim()) {
            'Image Count' { 'ImageCount' }
            'Chunk Size' { 'ChunkSizeBytes' }
            'Part Number' { 'PartNumber' }
            'Boot Index' { 'BootIndex' }
            'Size' { 'SizeBytes' }
            'Default Language' { 'DefaultLanguage' }
            'Directory Count' { 'DirectoryCount' }
            'File Count' { 'FileCount' }
            'Total Bytes' { 'TotalBytes' }
            'Hard Link Bytes' { 'HardLinkBytes' }
            'Creation Time' { 'CreationTime' }
            'Last Modification Time' { 'LastModificationTime' }
            'Product Name' { 'ProductName' }
            'Edition ID' { 'EditionID' }
            'Installation Type' { 'InstallationType' }
            'Product Type' { 'ProductType' }
            'Product Suite' { 'ProductSuite' }
            'System Root' { 'SystemRoot' }
            'Major Version' { 'MajorVersion' }
            'Minor Version' { 'MinorVersion' }
            'Build' { 'Build' }
            'Service Pack Build' { 'ServicePackBuild' }
            'Service Pack Level' { 'ServicePackLevel' }
            'Display Name' { 'DisplayName' }
            'Display Description' { 'DisplayDescription' }
            'WIMBoot compatible' { 'WIMBootCompatible' }
            default { ($Key -replace '\s+', '') } # Path, GUID, Compression, Architecture, etc.
        }
    }

    $ParseDate = {
        param([string]$Value)
        $formats = @(
            "ddd MMM dd HH:mm:ss yyyy 'UTC'",
            "ddd MMM d HH:mm:ss yyyy 'UTC'"
        )
        foreach ($f in $formats) {
            try {
                return [datetime]::ParseExact(
                    $Value.Trim(),
                    $f,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                    [System.Globalization.DateTimeStyles]::AdjustToUniversal
                )
            }
            catch { }
        }
        return $Value
    }

    $ParseBoolean = {
        param([string]$Value)
        switch ($Value.Trim().ToLowerInvariant()) {
            'yes' { $true }
            'no' { $false }
            default { $null }
        }
    }

    $ParseBytes = {
        param([string]$Value)
        $num = $Value -replace '[^\d]', ''
        if ([string]::IsNullOrWhiteSpace($num)) { return $null }
        [int64]$num
    }

    $ParseScalar = {
        param([string]$RawKey, [string]$Value)

        if ($RawKey -in @('Chunk Size', 'Size', 'Total Bytes', 'Hard Link Bytes')) {
            return & $ParseBytes $Value
        }

        if ($RawKey -in @('Image Count', 'Boot Index', 'Version', 'Directory Count', 'File Count',
                'Major Version', 'Minor Version', 'Build', 'Service Pack Build', 'Service Pack Level', 'Index')) {
            if ($Value -match '^\s*\d+\s*$') { return [int]$Value }
            return $Value
        }

        if ($RawKey -eq 'WIMBoot compatible') {
            $b = & $ParseBoolean $Value
            if ($null -ne $b) { return $b }
        }

        if ($RawKey -in @('Creation Time', 'Last Modification Time')) {
            return & $ParseDate $Value
        }

        if ($RawKey -eq 'Languages') {
            if ($Value -match ',') {
                return ($Value -split '\s*,\s*') | Where-Object { $_ -ne '' }
            }
            else {
                return @($Value.Trim())
            }
        }

        $Value.Trim()
    }

    $ParseKeyValue = {
        param([string]$Line)
        if ($Line -match '^\s*([^:]+):\s*(.*)$') {
            $rawKey = $matches[1]
            $rawVal = $matches[2]
            $key = & $NormalizeKey $rawKey
            $val = & $ParseScalar $rawKey $rawVal
            return @{ Key = $key; Value = $val }
        }
        $null
    }
    # --- End helpers ---

    # Execute wimlib-imagex
    $cmd = @($WimlibPath, 'info', $ImagePath)
    $raw = & $cmd 2>&1 | Out-String
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "wimlib-imagex exited with code $LASTEXITCODE`n$raw"
    }

    # Split lines, normalize endings
    $lines = $raw -split "`r?`n" | ForEach-Object { $_.TrimEnd() }

    # Locate sections
    $headerStart = ($lines | Select-String -SimpleMatch 'WIM Information:').LineNumber
    $imagesStart = ($lines | Select-String -SimpleMatch 'Available Images:').LineNumber

    if (-not $headerStart) { throw "Could not find 'WIM Information:' section." }
    if (-not $imagesStart) { throw "Could not find 'Available Images:' section." }

    # Parse header (skip dashed separators/blank lines)
    $header = [ordered]@{}
    for ($i = $headerStart; $i -lt $imagesStart - 1; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^-{3,}$') { continue }
        $kv = & $ParseKeyValue $line
        if ($kv) { $header[$kv.Key] = $kv.Value }
    }

    # Parse images
    $images = New-Object System.Collections.Generic.List[object]
    $current = $null

    for ($j = $imagesStart; $j -lt $lines.Count; $j++) {
        $line = $lines[$j]
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^-{3,}$') { continue }

        if ($line -match '^\s*Index:\s*(\d+)') {
            if ($current) { $images.Add([pscustomobject]$current) }
            $current = [ordered]@{}
            $current['Index'] = [int]$matches[1]
            continue
        }

        $kv = & $ParseKeyValue $line
        if ($kv) { $current[$kv.Key] = $kv.Value }
    }
    if ($current) { $images.Add([pscustomobject]$current) }

    # Build final object and cast some header fields
    $out = [ordered]@{}
    foreach ($k in $header.Keys) { $out[$k] = $header[$k] }
    $out['Images'] = $images.ToArray()

    foreach ($hName in @('Version', 'ImageCount', 'BootIndex')) {
        if ($out.Contains($hName) -and $out[$hName] -isnot [int]) {
            if ($out[$hName] -as [int]) { $out[$hName] = [int]$out[$hName] }
        }
    }
    foreach ($hBytes in @('ChunkSizeBytes', 'SizeBytes')) {
        if ($out.Contains($hBytes) -and $out[$hBytes] -isnot [long]) {
            $out[$hBytes] = & $ParseBytes ($out[$hBytes] -as [string])
        }
    }

    if ($ExpandImages) {
        $out['Images']
    }
    else {
        [pscustomobject]$out
    }
}

# WimlibInfo.psm1
# One function: Get-WimImageInfo
# PowerShell 7+ recommended.

function Get-WimlibInfo {
    <#
    .SYNOPSIS
    Runs `wimlib-imagex info` and returns a structured object containing header info and an Images array.

    .PARAMETER ImagePath
    Path to the WIM/ESD file (e.g., C:\25H2\sources\install.esd)

    .PARAMETER WimlibPath
    Path to wimlib-imagex.exe (default assumes it's on PATH)

    .PARAMETER ExpandImages
    If set, emits the per-image objects directly instead of the top-level header object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath,
        [string]$WimlibPath = (Join-Path $PSScriptRoot 'wimlib\wimlib-imagex.exe'),
        [switch]$ExpandImages
    )

    # --- Local helper scriptblocks (scoped inside the function) ---
    $NormalizeKey = {
        param([string]$Key)
        switch ($Key.Trim()) {
            'Image Count' { 'ImageCount' }
            'Chunk Size' { 'ChunkSizeBytes' }
            'Part Number' { 'PartNumber' }
            'Boot Index' { 'BootIndex' }
            'Size' { 'SizeBytes' }
            'Default Language' { 'DefaultLanguage' }
            'Directory Count' { 'DirectoryCount' }
            'File Count' { 'FileCount' }
            'Total Bytes' { 'TotalBytes' }
            'Hard Link Bytes' { 'HardLinkBytes' }
            'Creation Time' { 'CreationTime' }
            'Last Modification Time' { 'LastModificationTime' }
            'Product Name' { 'ProductName' }
            'Edition ID' { 'EditionID' }
            'Installation Type' { 'InstallationType' }
            'Product Type' { 'ProductType' }
            'Product Suite' { 'ProductSuite' }
            'System Root' { 'SystemRoot' }
            'Major Version' { 'MajorVersion' }
            'Minor Version' { 'MinorVersion' }
            'Build' { 'Build' }
            'Service Pack Build' { 'ServicePackBuild' }
            'Service Pack Level' { 'ServicePackLevel' }
            'Display Name' { 'DisplayName' }
            'Display Description' { 'DisplayDescription' }
            'WIMBoot compatible' { 'WIMBootCompatible' }
            default { ($Key -replace '\s+', '') } # Path, GUID, Compression, Architecture, etc.
        }
    }

    $ParseDate = {
        param([string]$Value)
        $formats = @(
            "ddd MMM dd HH:mm:ss yyyy 'UTC'",
            "ddd MMM d HH:mm:ss yyyy 'UTC'"
        )
        foreach ($f in $formats) {
            try {
                return [datetime]::ParseExact(
                    $Value.Trim(),
                    $f,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                    [System.Globalization.DateTimeStyles]::AdjustToUniversal
                )
            }
            catch { }
        }
        return $Value
    }

    $ParseBoolean = {
        param([string]$Value)
        switch ($Value.Trim().ToLowerInvariant()) {
            'yes' { $true }
            'no' { $false }
            default { $null }
        }
    }

    $ParseBytes = {
        param([string]$Value)
        $num = $Value -replace '[^\d]', ''
        if ([string]::IsNullOrWhiteSpace($num)) { return $null }
        [int64]$num
    }

    $ParseScalar = {
        param([string]$RawKey, [string]$Value)

        if ($RawKey -in @('Chunk Size', 'Size', 'Total Bytes', 'Hard Link Bytes')) {
            return & $ParseBytes $Value
        }

        if ($RawKey -in @('Image Count', 'Boot Index', 'Version', 'Directory Count', 'File Count',
                'Major Version', 'Minor Version', 'Build', 'Service Pack Build', 'Service Pack Level', 'Index')) {
            if ($Value -match '^\s*\d+\s*$') { return [int]$Value }
            return $Value
        }

        if ($RawKey -eq 'WIMBoot compatible') {
            $b = & $ParseBoolean $Value
            if ($null -ne $b) { return $b }
        }

        if ($RawKey -in @('Creation Time', 'Last Modification Time')) {
            return & $ParseDate $Value
        }

        if ($RawKey -eq 'Languages') {
            if ($Value -match ',') {
                return ($Value -split '\s*,\s*') | Where-Object { $_ -ne '' }
            }
            else {
                return @($Value.Trim())
            }
        }

        $Value.Trim()
    }

    $ParseKeyValue = {
        param([string]$Line)
        if ($Line -match '^\s*([^:]+):\s*(.*)$') {
            $rawKey = $matches[1]
            $rawVal = $matches[2]
            $key = & $NormalizeKey $rawKey
            $val = & $ParseScalar $rawKey $rawVal
            return @{ Key = $key; Value = $val }
        }
        $null
    }
    # --- End helpers ---

    # Execute wimlib-imagex
    $raw = & $WimlibPath info $ImagePath 2>&1 | Out-String

    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "wimlib-imagex exited with code $LASTEXITCODE`n$raw"
    }

    # Split lines, normalize endings
    $lines = $raw -split "`r?`n" | ForEach-Object { $_.TrimEnd() }

    # Locate sections
    $headerStart = ($lines | Select-String -SimpleMatch 'WIM Information:').LineNumber
    $imagesStart = ($lines | Select-String -SimpleMatch 'Available Images:').LineNumber

    if (-not $headerStart) { throw "Could not find 'WIM Information:' section." }
    if (-not $imagesStart) { throw "Could not find 'Available Images:' section." }

    # Parse header (skip dashed separators/blank lines)
    $header = [ordered]@{}
    for ($i = $headerStart; $i -lt $imagesStart - 1; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^-{3,}$') { continue }
        $kv = & $ParseKeyValue $line
        if ($kv) { $header[$kv.Key] = $kv.Value }
    }

    # Parse images
    $images = New-Object System.Collections.Generic.List[object]
    $current = $null

    for ($j = $imagesStart; $j -lt $lines.Count; $j++) {
        $line = $lines[$j]
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^-{3,}$') { continue }

        if ($line -match '^\s*Index:\s*(\d+)') {
            if ($current) { $images.Add([pscustomobject]$current) }
            $current = [ordered]@{}
            $current['Index'] = [int]$matches[1]
            continue
        }

        $kv = & $ParseKeyValue $line
        if ($kv) { $current[$kv.Key] = $kv.Value }
    }
    if ($current) { $images.Add([pscustomobject]$current) }

    # Build final object and cast some header fields
    $out = [ordered]@{}
    foreach ($k in $header.Keys) { $out[$k] = $header[$k] }
    $out['Images'] = $images.ToArray()

    foreach ($hName in @('Version', 'ImageCount', 'BootIndex')) {
        if ($out.Contains($hName) -and $out[$hName] -isnot [int]) {
            if ($out[$hName] -as [int]) { $out[$hName] = [int]$out[$hName] }
        }
    }
    foreach ($hBytes in @('ChunkSizeBytes', 'SizeBytes')) {
        if ($out.Contains($hBytes) -and $out[$hBytes] -isnot [long]) {
            $out[$hBytes] = & $ParseBytes ($out[$hBytes] -as [string])
        }
    }

    if ($ExpandImages) {
        $out['Images']
    }
    else {
        [pscustomobject]$out
    }
}



Export-ModuleMember -Function ConvertFrom-WimlibInfo, Get-WimEsdInfo, Get-WimEsdImage, Get-WimlibInfo

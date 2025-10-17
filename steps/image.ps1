# Image-related helpers split from main

function Ensure-Wimlib {
    param([string]$LocalPath)
    Log "Ensure-Wimlib: incoming path='$LocalPath'"
    if (Test-Path $LocalPath) {
        Log "Ensure-Wimlib: Found local bundled wimlib at '$LocalPath'"
        return $LocalPath
    }
    Log "Ensure-Wimlib: Local path missing, probing PATH..."
    $cmd = Get-Command "wimlib-imagex.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        Log "Ensure-Wimlib: Found in PATH at '$($cmd.Source)'"
        return $cmd.Source
    }
    Log "Ensure-Wimlib: NOT FOUND"
    throw "wimlib-imagex.exe not found. Place it in .\wimlib\ or add to PATH."
}

function Get-ImageList {
    param([string]$Path)
    Log "Get-ImageList: Path='$Path'"
    if (-not (Test-Path $Path)) { throw "Image file not found: $Path" }
    $fi = Get-Item $Path
    Log ("Get-ImageList: Size={0:N2} MB Extension={1}" -f ($fi.Length/1MB),$fi.Extension)
    $images = Get-WimlibInfo $Path -ExpandImages | Select-Object Index, Name, Build, TotalBytes
    Log "Get-ImageList: Retrieved $($images.Count) image record(s)."
    return $images
}

function Invoke-External {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$WorkingDirectory,
        [scriptblock]$OnStdOutLine,
        [scriptblock]$OnStdErrLine
    )
    Log ("Invoke-External: File='{0}' Args='{1}' WorkDir='{2}'" -f $FilePath, ($Arguments -join ' '), ($WorkingDirectory ?? "<inherit>"))
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $spl = @{
            FilePath = $FilePath
            ArgumentList = $Arguments
            PassThru = $true
            NoNewWindow = $true
            RedirectStandardOutput = $outFile
            RedirectStandardError  = $errFile
        }
        if ($WorkingDirectory) { $spl.WorkingDirectory = $WorkingDirectory }
        $proc = Start-Process @spl

        $loggedOut = 0
        $loggedErr = 0
        while (-not $proc.HasExited) {
            if (Test-Path $outFile) {
                $outLines = Get-Content -Path $outFile -ErrorAction SilentlyContinue
                for ($i=$loggedOut; $i -lt $outLines.Count; $i++) {
                    $line = $outLines[$i]
                    if ($line) { Log $line }
                    if ($OnStdOutLine -and $line) { & $OnStdOutLine $line }
                }
                $loggedOut = $outLines.Count
            }
            if (Test-Path $errFile) {
                $errLines = Get-Content -Path $errFile -ErrorAction SilentlyContinue
                for ($i=$loggedErr; $i -lt $errLines.Count; $i++) {
                    $line = $errLines[$i]
                    if ($line) { Log $line }
                    if ($OnStdErrLine -and $line) { & $OnStdErrLine $line }
                }
                $loggedErr = $errLines.Count
            }
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 150
        }

        foreach ($tuple in @(@($outFile, [ref]$loggedOut, $OnStdOutLine), @($errFile, [ref]$loggedErr, $OnStdErrLine))) {
            $file = $tuple[0]; $refIdx = $tuple[1]; $cb = $tuple[2]
            if (Test-Path $file) {
                $lines = Get-Content -Path $file -ErrorAction SilentlyContinue
                for ($i=$refIdx.Value; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]
                    if ($line) { Log $line }
                    if ($cb -and $line) { & $cb $line }
                }
                $refIdx.Value = $lines.Count
            }
        }

        $exit = $proc.ExitCode
        $sw.Stop()
        Log ("Invoke-External: ExitCode={0} Duration={1:N2}s StdOutLines={2} StdErrLines={3}" -f $exit,$sw.Elapsed.TotalSeconds,(Get-Content $outFile).Count,(Get-Content $errFile).Count)
        return $exit
    } finally {
        Remove-Item -Path $outFile,$errFile -ErrorAction SilentlyContinue
    }
}

function Apply-Image {
    param(
        [string]$WimlibPath,
        [string]$ImagePath,
        [int]$Index,
        [string]$ApplyDir
    )
    try {
        if (-not (Test-Path $ApplyDir)) {
            Log "Apply-Image: Creating target directory $ApplyDir"
            New-Item -ItemType Directory -Force -Path $ApplyDir | Out-Null
        }
        Log "Apply-Image: Index=$Index Source='$ImagePath' Target='$ApplyDir'"

        $phaseMap = @{
            'Creating files'              = (T 'StepApplyCreatingFiles')
            'Extracting file data'        = (T 'StepApplyExtracting')
            'Applying metadata to files'  = (T 'StepApplyApplyingMetadata')
        }
        $script:currentPhase = $null

        $script:currentPhase = 'Creating files'
        Start-Step $phaseMap[$script:currentPhase]
        Update-StepProgress -Percent 0

        $onOut = {
            param($line)
            try {
                $m = [regex]::Match($line, '^(Creating files|Extracting file data|Applying metadata to files):.*\((\d+)%\)')
                if ($m.Success) {
                    $phaseRaw = $m.Groups[1].Value
                    $pctInPhase = [int]$m.Groups[2].Value
                    $stepName = $phaseMap[$phaseRaw]

                    if ($script:currentPhase -ne $phaseRaw) {
                        if ($script:currentPhase -and $phaseMap.ContainsKey($script:currentPhase)) {
                            End-Step $phaseMap[$script:currentPhase] "OK"
                        }
                        Start-Step $stepName
                        $script:currentPhase = $phaseRaw
                    }

                    Update-StepProgress -Percent $pctInPhase
                }
            } catch { }
        }

        $args = @("apply",$ImagePath,$Index.ToString(),$ApplyDir,"--verbose")
        Log "Apply-Image: Command: $WimlibPath $($args -join ' ')"
        $exit = Invoke-External -FilePath $WimlibPath -Arguments $args -WorkingDirectory (Split-Path -Parent $WimlibPath) -OnStdOutLine $onOut
        if ($exit -ne 0) { throw "wimlib apply failed (exit code $exit)" }
        if (-not (Test-Path (Join-Path $ApplyDir 'Windows'))) {
            throw "wimlib apply completed but Windows directory not found in target."
        }

        $fileCount = (Get-ChildItem -LiteralPath $ApplyDir -Recurse -Force -File -ErrorAction SilentlyContinue).Count
        Log "Apply-Image: Completed. Files=$fileCount"

        if ($script:currentPhase -and $phaseMap.ContainsKey($script:currentPhase)) {
            End-Step $phaseMap[$script:currentPhase] "OK" "Files=$fileCount"
        } else {
            foreach ($p in @('Creating files','Extracting file data','Applying metadata to files')) {
                Start-Step $phaseMap[$p]
                Update-StepProgress -Percent 100
                End-Step $phaseMap[$p] "OK" ($(if ($p -eq 'Applying metadata to files') { "Files=$fileCount" } else { $null }))
            }
        }
    } catch {
        if ($script:currentPhase -and $phaseMap.ContainsKey($script:currentPhase)) {
            End-Step $phaseMap[$script:currentPhase] "FAILED" $_.Exception.Message
        }
        throw
    }
}

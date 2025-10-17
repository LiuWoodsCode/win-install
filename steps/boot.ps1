# UEFI boot configuration split from main

function Set-BootConfig {
    param(
        [Parameter(Mandatory)][string]$WindowsLetter,
        [Parameter(Mandatory)][string]$EfiLetter
    )
    Start-Step (T 'StepBCDBoot')
    try {
        $winPath = "${WindowsLetter}:\\Windows"
        $efiPart = "${EfiLetter}:"
        Log "Set-BootConfig: Configuring UEFI boot (bcdboot $winPath /s $efiPart /f UEFI)"
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $out = bcdboot $winPath /s $efiPart /f UEFI 2>&1
        $sw.Stop()
        $out | ForEach-Object { Log "bcdboot: $_" }
        Log ("Set-BootConfig: Duration {0:N2}s" -f $sw.Elapsed.TotalSeconds)
        End-Step (T 'StepBCDBoot') "OK"
    } catch {
        End-Step (T 'StepBCDBoot') "FAILED" $_.Exception.Message
        throw
    }
}

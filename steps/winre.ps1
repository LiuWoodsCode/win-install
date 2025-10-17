# Windows Recovery Environment configuration split from main

function Set-WinRE {
    param(
        [int]$ReMode,
        [bool]$TestMode,
        [string]$WindowsLetter,
        [string]$RecoveryLetter
    )
    Start-Step (T 'StepWinRE')
    try {
        if ($TestMode) { Log "WinRE: Skipping (Test Mode)"; End-Step (T 'StepWinRE') "OK" "Skipped TestMode"; return }
        switch ($ReMode) {
            1 {
                Log "WinRE: Full setup requested."
                $winreSrc = Join-Path "${WindowsLetter}:\\Windows" 'System32\Recovery\Winre.wim'
                $reTarget = "${RecoveryLetter}:\\Recovery\WindowsRE"
                if (-not (Test-Path $winreSrc)) { throw "Winre.wim not found at $winreSrc" }
                if (-not (Test-Path $reTarget)) { New-Item -ItemType Directory -Path $reTarget -Force | Out-Null }
                Copy-Item -LiteralPath $winreSrc -Destination (Join-Path $reTarget 'winre.wim') -Force
                $reagent = Join-Path "${WindowsLetter}:\\Windows" 'System32\ReAgentc.exe'
                & $reagent /SetREImage /Path $reTarget /Target "${WindowsLetter}:\\Windows" | ForEach-Object { Log $_ }
                & $reagent /Enable | ForEach-Object { Log $_ }
                End-Step (T 'StepWinRE') "OK"
            }
            2 {
                Log "WinRE: Skip installing to recovery partition, but enable if present."
                $reagent = Join-Path "${WindowsLetter}:\\Windows" 'System32\ReAgentc.exe'
                & $reagent /Enable | ForEach-Object { Log $_ }
                End-Step (T 'StepWinRE') "OK" "Enabled without moving image"
            }
            3 {
                Log "WinRE: Disabled per selection."
                $reagent = Join-Path "${WindowsLetter}:\\Windows" 'System32\ReAgentc.exe'
                & $reagent /Disable | ForEach-Object { Log $_ }
                End-Step (T 'StepWinRE') "OK" "Disabled"
            }
            default {
                Log "WinRE: Unknown mode $ReMode"
                End-Step (T 'StepWinRE') "OK" "Unknown mode"
            }
        }
    } catch {
        End-Step (T 'StepWinRE') "FAILED" $_.Exception.Message
        throw
    }
}

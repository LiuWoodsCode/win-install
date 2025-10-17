# Progress and logging helpers split from main

$Global:InstallSteps = @()
$Global:PlannedSteps = @()
$Global:CurrentStepIndex = -1
$Global:CurrentStepName = $null

function Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("HH:mm:ss")
    $line = "[$ts] $Message"
    if ($script:txtLog) { $script:txtLog.AppendText($line + [Environment]::NewLine) } else { Write-Host $line }
}

function Initialize-Progress {
    param([string[]]$Steps)
    $Global:PlannedSteps = @($Steps)
    $Global:CurrentStepIndex = -1
    $Global:CurrentStepName = $null
    if ($script:pbStep) { $script:pbStep.Value = 0 }
    if ($script:pbTotal) { $script:pbTotal.Value = 0 }
    if ($script:lblStepName) { $script:lblStepName.Text = (T 'StepLabelReady') }
    if ($script:lblTotal) { $script:lblTotal.Text = (T 'Overall0') }
}

function Update-TotalProgress {
    param([double]$CurrentStepPercent)
    try {
        $pct = 0
        if ($Global:PlannedSteps -and $Global:PlannedSteps.Count -gt 0 -and $Global:CurrentStepIndex -ge 0) {
            $pct = [Math]::Round((([double]$Global:CurrentStepIndex) + ($CurrentStepPercent/100.0)) / $Global:PlannedSteps.Count * 100)
        }
        $pct = [Math]::Max(0,[Math]::Min(100,[int]$pct))
        if ($script:pbTotal) { $script:pbTotal.Value = $pct }
        if ($script:lblTotal) { $script:lblTotal.Text = (T 'OverallFmt' $pct) }
    } catch { }
}

function Update-StepProgress {
    param([double]$Percent)
    try {
        $p = [Math]::Max(0,[Math]::Min(100,[int][Math]::Round($Percent)))
        if ($script:pbStep) { $script:pbStep.Value = $p }
        if ($script:lblStepName -and $Global:CurrentStepName) {
            $script:lblStepName.Text = (T 'StepLabelFmt' $Global:CurrentStepName $p)
        }
        Update-TotalProgress -CurrentStepPercent $p
    } catch { }
}

function Start-Step {
    param([string]$Name)
    $step = [ordered]@{
        Name     = $Name
        Start    = Get-Date
        End      = $null
        Status   = "RUNNING"
        Details  = ""
        Duration = $null
    }
    $Global:InstallSteps += [PSCustomObject]$step
    Log "=== START STEP: $Name ==="

    $Global:CurrentStepName = $Name
    if ($script:lblStepName) { $script:lblStepName.Text = (T 'StepLabelFmt' $Name 0) }
    if ($script:pbStep) { $script:pbStep.Value = 0 }
    if ($Global:PlannedSteps) {
        $idx = [Array]::IndexOf($Global:PlannedSteps, $Name)
        if ($idx -ge 0) { $Global:CurrentStepIndex = $idx } else { $Global:CurrentStepIndex++ }
    }
    Update-TotalProgress -CurrentStepPercent 0
}

function End-Step {
    param(
        [string]$Name,
        [string]$Status = "OK",
        [string]$Details
    )
    if ($Name -eq $Global:CurrentStepName) { Update-StepProgress -Percent 100 }

    $step = $Global:InstallSteps | Where-Object { $_.Name -eq $Name -and -not $_.End } | Select-Object -Last 1
    if ($step) {
        $step.End = Get-Date
        $step.Status = $Status
        if ($Details) { $step.Details = $Details }
        $step.Duration = "{0:N2}s" -f (($step.End - $step.Start).TotalSeconds)
        Log ("=== END STEP: {0} | Status: {1} | Duration: {2} ===" -f $step.Name,$step.Status,$step.Duration)
        if ($Details) { Log ("--- Details: {0}" -f $Details) }
    } else {
        Log "WARNING: End-Step called for '$Name' but no running step found."
    }
}

function Write-EnvironmentInfo {
    Log "Environment: PSVersion=$($PSVersionTable.PSVersion) Edition=$($PSVersionTable.PSEdition) OS=$([Environment]::OSVersion.VersionString) Arch=$([Environment]::Is64BitProcess) Culture=$([System.Globalization.CultureInfo]::CurrentCulture.Name)"
    Log "User: $([Environment]::UserName) Admin=$((Test-Admin)) Process=$PID HostProcessArch=$([Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)"
}

function Write-InstallSummary {
    if (-not $Global:InstallSteps -or $Global:InstallSteps.Count -eq 0) { return }
    Log ""
    Log "---------------- INSTALL SUMMARY (BEGIN) ----------------"
    $totalOk = 0; $totalFail = 0
    $t0 = $Global:InstallSteps | Sort-Object Start | Select-Object -First 1 -ExpandProperty Start
    $t1 = ($Global:InstallSteps | ForEach-Object { $_.End ?? $_.Start }) | Sort-Object | Select-Object -Last 1
    foreach ($s in $Global:InstallSteps) {
        if ($s.Status -eq 'OK') { $totalOk++ } elseif ($s.Status -eq 'FAILED') { $totalFail++ }
        $line = "* {0} :: {1,-6} :: {2,-8} :: {3}" -f $s.Name,$s.Status,$s.Duration,$s.Details
        Log $line
    }
    $elapsed = if ($t0 -and $t1) { "{0:N2}s" -f (($t1 - $t0).TotalSeconds) } else { "n/a" }
    Log "Steps OK=$totalOk Failed=$totalFail Total=$($Global:InstallSteps.Count) Elapsed=$elapsed"
    Log "---------------- INSTALL SUMMARY (END) ------------------"
}

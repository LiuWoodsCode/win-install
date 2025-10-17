# Localization utilities for win-install
# Dot-source this file and use T 'Key' [args]

$script:RES = @{}
$script:CURRENT_LANG = $null

function Set-UILanguage {
    param([string]$Culture)
    if (-not $Culture -or $Culture -eq '') {
        try { $Culture = [System.Globalization.CultureInfo]::CurrentUICulture.Name } catch { $Culture = 'en-US' }
    }
    $lang = $Culture.Split('-')[0].ToLower()
    if (-not $script:RES.ContainsKey($lang)) { $lang = 'en' }
    $script:CURRENT_LANG = $lang
}

function T {
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(ValueFromRemainingArguments=$true)][object[]]$Args
    )
    $lang = if ($script:CURRENT_LANG) { $script:CURRENT_LANG } else { 'en' }
    $dict = $script:RES[$lang]
    $fmt = if ($dict.ContainsKey($Key)) { $dict[$Key] } elseif ($script:RES['en'].ContainsKey($Key)) { $script:RES['en'][$Key] } else { $Key }
    if ($Args -and $Args.Count -gt 0) { return ($fmt -f $Args) } else { return $fmt }
}

$script:RES['en'] = @{
    AppTitle = 'Windows Installer (win-install)'
    PixelSetupTitle = 'PixelSetup'
    PixelSetupErrorTitle = 'PixelSetup Error'
    HeaderTitle = 'INSTALL WINDOWS (EXPERIMENTAL, NOT FINAL UI)'
    GroupImageTitle = '1) Image'
    ImagePathLabel = 'install.wim/esd path:'
    Browse = 'Browse...'
    ListImages = 'List Images'
    SelectIndexLabel = 'Select index:'
    FSLabel = 'Windows volume file system:'
    FSNTFS = 'NTFS (default)'
    FSReFS = 'ReFS (Windows 11 22H2+)'
    GroupWinRETitle = '2) WinRE / Recovery'
    ReFull = 'Full setup (create and enable WinRE)'
    ReSkip = 'Skip WinRE (keep Recovery partition empty)'
    ReNone = 'No Recovery partition at all'
    GroupTargetTitle = '3) Target'
    TestModeLabel = 'Test Mode (apply to C:\\Test, no disk changes)'
    RefreshDisks = 'Refresh Disks'
    GroupActionsTitle = '4) Actions'
    Install = 'Install'
    Close = 'Close'
    Repair = 'Repair...'
    ProgressTitle = 'Progress'
    StepLabelReady = 'Step: (ready)'
    StepLabelFmt = 'Step: {0} ({1}%)'
    Overall0 = 'Overall: 0%'
    OverallFmt = 'Overall: {0}%'
    ColumnNumber = 'Number'
    ColumnFriendlyName = 'FriendlyName'
    ColumnSizeGB = 'Size (GB)'
    ColumnStyle = 'Style'

    AdminRequired = 'This tool requires Administrator privileges.'
    STARequired = 'This script must run in STA mode. Launch PowerShell with -STA.'
    SelectValidImage = 'Please select a valid install.wim/esd path.'
    SelectIndexPrompt = 'Please list images and select an index.'
    InstallComplete = 'Installation complete.'
    RepairOnlyWinPE = 'Repair Environment only available in WinPE.'
    RecEnvNotFound = 'Could not locate RecEnv.exe in WinPE.'
    RecEnvLaunchFailed = 'Failed to launch RecEnv: {0}'

    ErrorTitle = 'Error'
    InfoTitle = 'Information'
    WarningTitle = 'Warning'

    StepInitialization = 'Initialization'
    StepTestModeNotice = 'Test Mode Notice'
    StepPartitioning = 'Partitioning'
    StepApplyCreatingFiles = 'Apply: Creating files'
    StepApplyExtracting = 'Apply: Extracting file data'
    StepApplyApplyingMetadata = 'Apply: Applying metadata to files'
    StepBCDBoot = 'BCDBoot'
    StepWinRE = 'WinRE'
    StepFinalization = 'Finalization'

    ImageEntryFmt = '#{0} - {1} (Build {2}, {3} GiB)'

    # NEW: Wizard navigation
    NavBack = '< Back'
    NavNext = 'Next >'
    NavCancel = 'Cancel'
    NavInstallNow = 'Install now'
}
# Pseudo-locale (qps-ploc) generated from English for UI testing
$script:RES['qps'] =
@{
    AppTitle = '[!!!Wîńđôŵš Įńšťâłłȅŕ (wîn-įńšťâłł)!!!]'
    PixelSetupTitle = '[!!!PîxȅĺŠėťůp!!!]'
    PixelSetupErrorTitle = '[!!!PîxȅĺŠėťůp Ėřřôŕ!!!]'
    HeaderTitle = '[!!!ĮŅŠŤÅŁŁ ŴĮŃĐŌŴŚ (ĘXƤĖŘĮMĘŇŦÅŁ, ŃŌŤ ƑĪŃÅŁ ŪĮ)!!!]'
    GroupImageTitle = '[!!!1) İmâģȅ!!!]'
    ImagePathLabel = '[!!!įńšťâĺľ.wîm/ȅśď ƥâťħ:!!!]'
    Browse = '[!!!Ɓřōŵśȅ...!!!]'
    ListImages = '[!!!Ŀįšť İmâĝȅš!!!]'
    SelectIndexLabel = '[!!!Šěĺȇçť īńďėx:!!!]'
    FSLabel = '[!!!Ŵįńđôŵš ʋōĺŭmȅ ƒıĺȅ šŷśţȅm:!!!]'
    FSNTFS = '[!!!ŃŤƑŚ (đĕƒâŭĺť)!!!]'
    FSReFS = '[!!!ŘȅƑŚ (Ŵîńđơŵš 11 22H2+)!!!]'
    GroupWinRETitle = '[!!!2) ŴįńŘĖ / Řȅčôvȇřŷ!!!]'
    ReFull = '[!!!Ƒŭļļ šȇţŭp (ćŕȇâťȅ āńď ęńâɓłȅ ŴįńŘĖ)!!!]'
    ReSkip = '[!!!Śķıƥ ŴįńŘĖ (ķȅȇp Řȅćôvěŕŷ pāŕťıţıôń ēmþţŷ)!!!]'
    ReNone = '[!!!Ńō Řȅćôvěŕŷ pāŕťıţıôń ȁť ȁļĺ!!!]'
    GroupTargetTitle = '[!!!3) Ŧâřġȅť!!!]'
    TestModeLabel = '[!!!Ťȅšť Mōđȇ (âƥƥĺŷ to C:\Ťȅśť, ŉō ďįśķ ċĥâńĝȅš)!!!]'
    RefreshDisks = '[!!!Ŗȅƒřȇśĥ Đĩšķš!!!]'
    GroupActionsTitle = '[!!!4) Âčţīőńš!!!]'
    Install = '[!!!Įńśťâłł!!!]'
    Close = '[!!!Čĺȍšȅ!!!]'
    Repair = '[!!!Řȇƥâįř...!!!]'
    ProgressTitle = '[!!!Ƥŗơģřȅšš!!!]'
    StepLabelReady = '[!!!Śťȇƥ: (ŕȇäđŷ)!!!]'
    StepLabelFmt = '[!!!Śťȇƥ: {0} ({1}%)!!!]'
    Overall0 = '[!!!Ōvȅřâŀľ: 0%!!!]'
    OverallFmt = '[!!!Ōvȅřâŀļ: {0}%!!!]'
    ColumnNumber = '[!!!Ňŭmƀȅř!!!]'
    ColumnFriendlyName = '[!!!ƑŕıȇńđĺŷŃȁmȅ!!!]'
    ColumnSizeGB = '[!!!Śıžȅ (ĜĮ)!!!]'
    ColumnStyle = '[!!!Šţƴľȅ!!!]'

    AdminRequired = '[!!!Ťĥįš ţōōł ŗȅɋũįŕȅš Āďmıņıšťŗåţıʋȅ ƥŕıʋıľȇģȩş.!!!]'
    STARequired = '[!!!Ťĥįš śĉřıƥţ mųśţ ŕŭņ īņ ŚŦȀ mőďȇ. Ŀâũńĉĥ PơŵȅřŠĥȅŀł ŵıťĥ -ŚŦȀ.!!!]'
    SelectValidImage = '[!!!Ƥĺȇâśȅ śȅĺȇĉţ â vȁļıđ įńšťâĺľ.wîm/ȅśď ƥâťħ.!!!]'
    SelectIndexPrompt = '[!!!Ƥĺȇâśȇ ȵıŝŧ ĺıŝţ İmâĝȅş âńď śȅľȇćţ ȃń ĭńďėx.!!!]'
    InstallComplete = '[!!!İńšťâĺĺȃťıōň ćŏmƿŀȅţȅ.!!!]'
    RepairOnlyWinPE = '[!!!Řȇƥâįř Ėňvıŗōňmęńŧ őńĺŷ ȁvāıłȁƄŀȇ īń ŴįńPĒ.!!!]'
    RecEnvNotFound = '[!!!Ćôŭļď ŉơţ Ɩŏçȃţȅ ŘȇćĖňv.exe īń ŴįńPĒ.!!!]'
    RecEnvLaunchFailed = '[!!!Ƒȃıĺȇď ţō ĺâŭňĉĥ ŘȇćĖňv: {0}!!!]'

    ErrorTitle = '[!!!Ęŕřŏŕ!!!]'
    InfoTitle = '[!!!Įńƒōŗmȁťıōń!!!]'
    WarningTitle = '[!!!Ŵȁŕņıňġ!!!]'

    StepInitialization = '[!!!Įńıţıâłıžȁťıōņ!!!]'
    StepTestModeNotice = '[!!!Ťȅšť Mōđȇ Ńơţıċȇ!!!]'
    StepPartitioning = '[!!!Pâŕţıťıōńıńģ!!!]'
    StepApplyCreatingFiles = '[!!!Åƥƥĺȳ: Ċřȇȁţįńģ Ƒıļȅš!!!]'
    StepApplyExtracting = '[!!!Åƥƥĺȳ: Ěxţřâćŧįńģ ƒıļȅ đâţȁ!!!]'
    StepApplyApplyingMetadata = '[!!!Åƥƥĺȳ: Åƥƥĺȳıńġ ɱȅţȁđâţȁ ţō ƒıļȅś!!!]'
    StepBCDBoot = '[!!!BĆĐƁŏōţ!!!]'
    StepWinRE = '[!!!ŴįńŘĖ!!!]'
    StepFinalization = '[!!!Ƒıńâļıžȁţıōņ!!!]'

    ImageEntryFmt = '[!!!#{0} - {1} (Бυılď {2}, {3} ĠĮƁ)!!!]'

    # NEW: Wizard navigation
    NavBack = '[!!!< Bȁčķ!!!]'
    NavNext = '[!!!Ńȅxţ >!!!]'
    NavCancel = '[!!!Ćȃńĉȅŀ!!!]'
    NavInstallNow = '[!!!İńşťâļł ŋōŵ!!!]'
}

# Initialize language on import
Set-UILanguage

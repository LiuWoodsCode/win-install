param(
    [switch]$MakeHidden = $false
)

if ($MakeHidden) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

    # Constants: 0 = Hide, 5 = Show
    $hWnd = [Win32]::GetConsoleWindow()
    if ($hWnd -ne [IntPtr]::Zero) {
        [Win32]::ShowWindow($hWnd, 0)
    }

}

wpeinit
. "$PSScriptRoot\MainNew copy.ps1"
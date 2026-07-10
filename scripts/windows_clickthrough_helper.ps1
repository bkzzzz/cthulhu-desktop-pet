param(
    [Parameter(Mandatory=$true)]
    [Int64]$WindowHandle,

    [Parameter(Mandatory=$true)]
    [string]$StatePath
)

$signature = @"
using System;
using System.Runtime.InteropServices;

public static class ClickthroughNative {
    public const int GWL_EXSTYLE = -20;
    public const long WS_EX_LAYERED = 0x00080000L;
    public const long WS_EX_TRANSPARENT = 0x00000020L;
    public const long WS_EX_NOACTIVATE = 0x08000000L;
    public const uint SWP_NOSIZE = 0x0001;
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOZORDER = 0x0004;
    public const uint SWP_NOACTIVATE = 0x0010;
    public const uint SWP_FRAMECHANGED = 0x0020;
    public const uint GA_ROOT = 2;

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr hWnd, uint gaFlags);

    [DllImport("user32.dll", EntryPoint="GetWindowLong")]
    public static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLong")]
    public static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", EntryPoint="GetWindowLongPtr")]
    public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLongPtr")]
    public static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    public static long GetExStyle(IntPtr hWnd) {
        return IntPtr.Size == 8 ? GetWindowLongPtr64(hWnd, GWL_EXSTYLE).ToInt64() : GetWindowLong32(hWnd, GWL_EXSTYLE);
    }

    public static void SetExStyle(IntPtr hWnd, long style) {
        if (IntPtr.Size == 8) {
            SetWindowLongPtr64(hWnd, GWL_EXSTYLE, new IntPtr(style));
        } else {
            SetWindowLong32(hWnd, GWL_EXSTYLE, unchecked((int)style));
        }
        // Rebuilding the frame makes transparent Godot windows briefly flash white
        // when hover hit testing toggles click-through.
        SetWindowPos(hWnd, IntPtr.Zero, 0, 0, 0, 0, SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    }
}
"@

Add-Type -TypeDefinition $signature

$hwnd = [ClickthroughNative]::GetAncestor([IntPtr]$WindowHandle, [ClickthroughNative]::GA_ROOT)
if ($hwnd -eq [IntPtr]::Zero) {
    $hwnd = [IntPtr]$WindowHandle
}
$lastState = ""

while ([ClickthroughNative]::IsWindow($hwnd)) {
    $state = $lastState
    if (Test-Path -LiteralPath $StatePath) {
        try {
            $state = (Get-Content -LiteralPath $StatePath -Raw).Trim()
        } catch {
            $state = $lastState
        }
    }

    if ($state -eq "exit") {
        break
    }

    if (($state -eq "0" -or $state -eq "1") -and $state -ne $lastState) {
        $style = [ClickthroughNative]::GetExStyle($hwnd)
        $style = $style -bor [ClickthroughNative]::WS_EX_NOACTIVATE
        if ($state -eq "1") {
            $style = $style -bor [ClickthroughNative]::WS_EX_LAYERED
            $style = $style -bor [ClickthroughNative]::WS_EX_TRANSPARENT
        } else {
            $style = $style -band (-bnot [ClickthroughNative]::WS_EX_TRANSPARENT)
        }
        [ClickthroughNative]::SetExStyle($hwnd, $style)
        $lastState = $state
    }

    Start-Sleep -Milliseconds 16
}

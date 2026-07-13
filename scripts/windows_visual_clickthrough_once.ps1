param(
    [Parameter(Mandatory=$true)]
    [Int64]$WindowHandle
)

$ErrorActionPreference = "Stop"

$signature = @"
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class NativeVisualClickthrough {
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

    [DllImport("user32.dll", EntryPoint="SetWindowLong", SetLastError=true)]
    public static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", EntryPoint="GetWindowLongPtr")]
    public static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint="SetWindowLongPtr", SetLastError=true)]
    public static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint flags);

    public static long GetStyle(IntPtr hwnd) {
        return IntPtr.Size == 8 ? GetWindowLongPtr64(hwnd, GWL_EXSTYLE).ToInt64() : GetWindowLong32(hwnd, GWL_EXSTYLE);
    }

    public static void Apply(IntPtr hwnd) {
        if (!IsWindow(hwnd)) throw new Win32Exception("Invalid Godot window handle");
        IntPtr root = GetAncestor(hwnd, GA_ROOT);
        if (root != IntPtr.Zero) hwnd = root;
        long style = GetStyle(hwnd) | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_NOACTIVATE;
        Marshal.GetLastWin32Error();
        if (IntPtr.Size == 8) {
            IntPtr result = SetWindowLongPtr64(hwnd, GWL_EXSTYLE, new IntPtr(style));
            int error = Marshal.GetLastWin32Error();
            if (result == IntPtr.Zero && error != 0) throw new Win32Exception(error);
        } else {
            int result = SetWindowLong32(hwnd, GWL_EXSTYLE, unchecked((int)style));
            int error = Marshal.GetLastWin32Error();
            if (result == 0 && error != 0) throw new Win32Exception(error);
        }
        if (!SetWindowPos(hwnd, IntPtr.Zero, 0, 0, 0, 0,
            SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED)) {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
"@

try {
    Add-Type -TypeDefinition $signature
    [NativeVisualClickthrough]::Apply([IntPtr]$WindowHandle)
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.ToString())
    exit 1
}

$AppId = 'BluetoothNotify.App.v3'
$AppDisplayName = 'Bluetooth Connection Monitor'
$IconPath = "$PSScriptRoot\bt_app.ico"
$ShortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$AppDisplayName.lnk"
$ExePath = "$PSScriptRoot\BluetoothNotify.exe"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

namespace ToastAumid {

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    internal class CShellLink { }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
    internal interface IShellLinkW {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszFile, int cchMaxPath, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszName, int cchMaxName);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszDir, int cchMaxPath);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszArgs, int cchMaxPath);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] System.Text.StringBuilder pszIconPath, int cchIconPath, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropVariant {
        public ushort vt;
        public ushort wReserved1, wReserved2, wReserved3;
        public IntPtr pointerValue;
    }

    [ComImport, Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPropertyStore {
        void GetCount(out uint cProps);
        void GetAt(uint iProp, out PropertyKey pkey);
        void GetValue(ref PropertyKey key, out PropVariant pv);
        void SetValue(ref PropertyKey key, ref PropVariant pv);
        void Commit();
    }

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey {
        public Guid fmtid;
        public uint pid;
        public PropertyKey(Guid fmtid, uint pid) { this.fmtid = fmtid; this.pid = pid; }
    }

    public class ShortcutHelper {
        public static void CreateShortcutWithAumid(string shortcutPath, string targetPath, string arguments, string iconPath, string aumid) {
            var link = (IShellLinkW)new CShellLink();
            link.SetPath(targetPath);
            link.SetArguments(arguments);
            link.SetIconLocation(iconPath, 0);

            var propStore = (IPropertyStore)link;

            var key = new PropertyKey(new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), 5); // PKEY_AppUserModel_ID

            PropVariant pv = new PropVariant();
            pv.vt = 31; // VT_LPWSTR
            pv.pointerValue = Marshal.StringToCoTaskMemUni(aumid);

            propStore.SetValue(ref key, ref pv);
            propStore.Commit();

            ((IPersistFile)link).Save(shortcutPath, true);

            Marshal.FreeCoTaskMem(pv.pointerValue);
        }
    }
}
"@

[ToastAumid.ShortcutHelper]::CreateShortcutWithAumid(
    $ShortcutPath,
    $ExePath,
    '',
    $IconPath,
    $AppId
)

Write-Output "Registered AUMID '$AppId' via shortcut: $ShortcutPath"

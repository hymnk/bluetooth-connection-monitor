# Bluetooth Connection Monitor

Windows 11 tray app that watches specific Bluetooth LE devices (e.g. a
keyboard/mouse shared between two PCs) and shows a toast notification plus a
color-coded tray icon whenever one connects or disconnects from this PC.

Built to solve one problem: when a keyboard/mouse is switched between two
PCs, it's not obvious which PC it's currently talking to. This makes that
state visible at a glance.

## Features

- Toast notification on connect (🟢) and disconnect (🔴), silent by default
- Tray icon reflects current state (green = all watched devices connected,
  red = at least one disconnected); hover for per-device status
- Runs hidden, no PowerShell console window
- Starts automatically at logon (Startup folder shortcut)

## Why not `Get-PnpDevice` / `Status`?

The obvious approach — polling `Get-PnpDevice` and checking `.Status` — does
**not** work for many Bluetooth LE input devices. If the device has the
`DEVPKEY_DeviceContainer_AlwaysShowDeviceAsConnected` property set to `True`
(common for keyboards/mice, to avoid UI flicker), `Status` stays `OK` even
while the device is disconnected.

This app instead uses the actual live link state via
[`Windows.Devices.Bluetooth.BluetoothLEDevice.ConnectionStatus`](https://learn.microsoft.com/uwp/api/windows.devices.bluetooth.bluetoothledevice),
which correctly reflects `Connected` / `Disconnected` in real time.

## Limitation: receiver-based connections (Logi Bolt/Unifying etc.)

If a mouse/keyboard connects through a USB dongle (Logi Bolt, Unifying, and
similar proprietary 2.4 GHz receivers) rather than the PC's own Bluetooth
radio, Windows has no visibility into that link at all — the receiver stays
"present" regardless of whether the paired device is actually in range. Such
devices **cannot** be monitored by this tool; only devices paired directly
over Bluetooth are supported. (This is also why the `MX Ergo S` entry in
`BluetoothNotify.ps1` assumes it's been switched to direct Bluetooth pairing.)

## Setup

1. Find the Bluetooth LE address of each device you want to watch:
   ```powershell
   Get-PnpDevice -Class Bluetooth -PresentOnly |
     Where-Object FriendlyName -match '<part of your device name>' |
     Select-Object FriendlyName, InstanceId
   ```
   The address is the 12 hex-digit segment in `InstanceId`, e.g.
   `BTHLE\DEV_ce20f1c02578\...` → `ce20f1c02578`.

2. Edit `$TargetDevices` at the top of `BluetoothNotify.ps1`:
   ```powershell
   $TargetDevices = @(
       @{ Name = 'Keychron K11 Max'; Address = 'ce20f1c02578' },
       @{ Name = 'MX Ergo S'; Address = 'd97908c41416' }
   )
   ```

3. Install the [ps2exe](https://github.com/MScholtes/PS2EXE) module (used to
   compile the script into a console-less `.exe`):
   ```powershell
   Install-Module ps2exe -Scope CurrentUser
   ```

4. Build and register:
   ```powershell
   .\build.ps1
   ```
   This generates the icons (if missing), compiles `BluetoothNotify.exe`,
   registers its app identity (AUMID) for toast notifications, and creates/
   updates the Startup folder shortcut so it launches at every logon.

5. Start it now (or just log off/on):
   ```powershell
   Start-Process .\BluetoothNotify.exe
   ```

## Files

| File | Purpose |
|---|---|
| `BluetoothNotify.ps1` | Main script: polls connection status, shows toasts, drives the tray icon |
| `create_icons.ps1` | Generates the blue/green/red Bluetooth glyph icons |
| `register_aumid.ps1` | Registers a Start Menu shortcut with a custom AppUserModelID so toasts show as "Bluetooth Connection Monitor" instead of "Windows PowerShell" |
| `update_startup_shortcut.ps1` | Creates/updates the Startup folder shortcut that launches the exe at logon |
| `build.ps1` | Runs the full build: icons → compile → register AUMID → register startup |

## Known limitations

- Toast notification duration isn't configurable beyond Windows' two presets
  (`short` ≈5s / `long` ≈25s); this app uses the default `short`.
- The small app icon shown in the toast header could not be made to display
  correctly for this unpackaged script-based app (a Windows Notification
  Platform restriction on non-MSIX apps); the toast body (title + message)
  and the tray icon are unaffected and clearly color-coded instead.
- Task Scheduler registration requires elevated (admin) rights; this project
  uses a Startup folder shortcut instead, which does not.

## Requirements

- Windows 11
- PowerShell 5.1 (Windows PowerShell; the WinRT interop used here does not
  work under PowerShell 7/pwsh)
- [ps2exe](https://github.com/MScholtes/PS2EXE) module for building the exe

# Bluetooth Connection Monitor

Windows 11 tray app that watches specific Bluetooth devices (LE keyboards/mice
shared between two PCs, and optionally classic devices such as headphones) and shows a toast notification plus a
color-coded tray icon whenever one connects or disconnects from this PC.

Built to solve one problem: when a keyboard/mouse is switched between two
PCs, it's not obvious which PC it's currently talking to. This makes that
state visible at a glance.

## Features

- Unobtrusive overlay on connect/disconnect: a small pill at the bottom-right
  (green/red dot + device name) that fades out after ~2s, never steals focus
  and is click-through. Standard Windows toasts are still available.
- Tray icon reflects current state (green = every category has at least one
  device connected, red = otherwise); hover for per-device status. Right-click
  → "Test notification" previews the overlay.
- Runs hidden, no PowerShell console window
- Starts automatically at logon (Startup folder shortcut)
- Tray icons are embedded in the script (base64), and all per-tick work is
  wrapped in try/catch — no runtime file dependency and no error dialogs
  from a transient failure

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

## Quick start (prebuilt exe)

1. Download `BluetoothNotify.exe` and `devices.sample.json` from the
   [latest release](https://github.com/hymnk/bluetooth-connection-monitor/releases/latest) into one folder.
2. Rename `devices.sample.json` to `devices.json` and edit it for your own
   devices (see *Setup* step 1 for how to find a device address and the
   [Configuration](#configuration) section for the fields).
3. Run `BluetoothNotify.exe`. A tray icon appears; right-click it for
   *Test notification* / *Exit*. To start it at every logon, put a shortcut
   to the exe in `shell:startup`.

The exe is unsigned, so Windows SmartScreen may warn on first run
(*More info* → *Run anyway*). If you would rather not trust a binary, build
it yourself from source as described below.

## Setup

1. Find the Bluetooth LE address of each device you want to watch:
   ```powershell
   Get-PnpDevice -Class Bluetooth -PresentOnly |
     Where-Object FriendlyName -match '<part of your device name>' |
     Select-Object FriendlyName, InstanceId
   ```
   The address is the 12 hex-digit segment in `InstanceId`, e.g.
   `BTHLE\DEV_ce20f1c02578\...` → `ce20f1c02578`.

2. Copy `devices.sample.json` to `devices.json` (next to the exe, or next to
   `BluetoothNotify.ps1` when running the script) and edit it — see
   [Configuration](#configuration). `devices.json` is git-ignored.

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
| `BluetoothNotify.ps1` | Main script: polls connection status, announces changes, drives the tray icon |
| `devices.sample.json` | Template for `devices.json` (your own devices; git-ignored) |
| `create_icons.ps1` | Generates the blue/green/red Bluetooth glyph icon files, used to (re)produce the base64 strings embedded in `BluetoothNotify.ps1` — not read at runtime |
| `register_aumid.ps1` | Registers a Start Menu shortcut with a custom AppUserModelID so toasts show as "Bluetooth Connection Monitor" instead of "Windows PowerShell" |
| `update_startup_shortcut.ps1` | Creates/updates the Startup folder shortcut that launches the exe at logon |
| `build.ps1` | Runs the full build: icons → compile → register AUMID → register startup |

## Notification style

Set in `devices.json`:

| Variable | Values |
|---|---|
| `NotifyStyle` | `'Overlay'` (default), `'Toast'`, `'Both'`, `'None'` (tray icon only) |
| `OverlayHoldMs` | How long the overlay stays fully visible, in ms (default `1800`) |

The overlay is a borderless `Form` subclass (compiled at startup via
`Add-Type`) using the `WS_EX_NOACTIVATE`/`WS_EX_TRANSPARENT`/`WS_EX_TOOLWINDOW`
styles, which is what makes it non-focus-stealing and click-through.

## Known limitations

- Windows toast duration isn't configurable beyond two presets (`short` ≈5s /
  `long` ≈25s) — the reason the default is the custom overlay instead.
- The small app icon shown in the toast header could not be made to display
  correctly for this unpackaged script-based app (a Windows Notification
  Platform restriction on non-MSIX apps); the toast body (title + message)
  and the tray icon are unaffected and clearly color-coded instead.
- Task Scheduler registration requires elevated (admin) rights; this project
  uses a Startup folder shortcut instead, which does not.
- Earlier versions loaded the tray icons from external `.ico` files in
  `%LOCALAPPDATA%\BluetoothNotify` at runtime; this occasionally failed at
  logon (path not found), spamming an error dialog on every timer tick. Fixed
  by embedding the icons as base64 directly in the script and wrapping the
  timer tick in try/catch so a transient failure never surfaces as a dialog.

## Requirements

- Windows 11
- PowerShell 5.1 (Windows PowerShell; the WinRT interop used here does not
  work under PowerShell 7/pwsh)
- [ps2exe](https://github.com/MScholtes/PS2EXE) module for building the exe

## Configuration

`devices.json` (next to the exe):

```json
{
  "NotifyStyle": "Overlay",
  "OverlayHoldMs": 1800,
  "Devices": [
    { "Name": "My Keyboard", "Address": "aabbccddeeff", "Category": "Keyboard" },
    { "Name": "My Mouse", "Address": "112233445566", "Category": "Mouse" },
    { "Name": "My Headphones", "Address": "0a1b2c3d4e5f", "Category": "Headphones", "Type": "Classic", "Required": false }
  ]
}
```

- `Category` groups interchangeable devices (e.g. two keyboards you swap
  between) — the tray icon stays green as long as at least one device in
  *each* category is connected, not necessarily all of them.
- `Type: "Classic"` — for BR/EDR devices such as headphones. Their audio link
  is **not** reported by the LE API (`BluetoothLEDevice` stays `Disconnected`
  while music is playing), so they are queried through `BluetoothDevice`.
  Leave it out for LE devices (keyboards/mice).
- `Required: false` — still notify on connect/disconnect and list the device
  in the tooltip, but never let it turn the tray icon red.
- `NotifyStyle` / `OverlayHoldMs` — see *Notification style* above.

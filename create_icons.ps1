# Generates the Bluetooth glyph icons used by BluetoothNotify (app icon + tray icons).
# Run this once before the first build, or whenever you want to regenerate the icons.

Add-Type -AssemblyName System.Drawing

function New-BtPng($path, $colorHex) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($colorHex)
    $bmp = New-Object System.Drawing.Bitmap 96,96
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $brush = New-Object System.Drawing.SolidBrush $c
    $g.FillEllipse($brush, 0, 0, 96, 96)
    $font = New-Object System.Drawing.Font('Segoe MDL2 Assets', 44)
    $white = [System.Drawing.Brushes]::White
    $glyph = [string][char]0xE702  # Bluetooth glyph in Segoe MDL2 Assets
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'
    $sf.LineAlignment = 'Center'
    $rect = New-Object System.Drawing.RectangleF(0, 0, 96, 96)
    $g.DrawString($glyph, $font, $white, $rect, $sf)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

function New-IcoFromPng($pngPath, $icoPath) {
    # Wraps the PNG directly in an ICO container (Vista+ PNG-in-ICO), which keeps
    # full 32bpp color - System.Drawing.Icon.FromHandle() alone quantizes to 16 colors.
    $png = [System.IO.File]::ReadAllBytes($pngPath)
    $fs = New-Object System.IO.FileStream($icoPath, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]1)
    $bw.Write([Byte]96); $bw.Write([Byte]96); $bw.Write([Byte]0); $bw.Write([Byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]$png.Length); $bw.Write([UInt32]22)
    $bw.Write($png)
    $bw.Close(); $fs.Close()
}

New-BtPng "$PSScriptRoot\bt_icon.png" '#0082FC'          # neutral blue, used for the app/shortcut icon
New-BtPng "$PSScriptRoot\bt_connected.png" '#107C10'      # green, tray icon when connected
New-BtPng "$PSScriptRoot\bt_disconnected.png" '#C42B1C'   # red, tray icon when disconnected

New-IcoFromPng "$PSScriptRoot\bt_icon.png" "$PSScriptRoot\bt_app.ico"
New-IcoFromPng "$PSScriptRoot\bt_connected.png" "$PSScriptRoot\bt_connected.ico"
New-IcoFromPng "$PSScriptRoot\bt_disconnected.png" "$PSScriptRoot\bt_disconnected.ico"

Write-Output 'Icons created.'

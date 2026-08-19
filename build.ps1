# Builds BluetoothNotify.exe from BluetoothNotify.ps1 and registers the app
# identity (AUMID) used for toast notifications. Run from this folder.
#   Requires: ps2exe module (Install-Module ps2exe -Scope CurrentUser)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path "$PSScriptRoot\bt_app.ico")) {
    & "$PSScriptRoot\create_icons.ps1"
}

Import-Module ps2exe
Invoke-ps2exe `
    -inputFile "$PSScriptRoot\BluetoothNotify.ps1" `
    -outputFile "$PSScriptRoot\BluetoothNotify.exe" `
    -iconFile "$PSScriptRoot\bt_app.ico" `
    -noConsole -STA `
    -title 'Bluetooth Connection Monitor' `
    -product 'Bluetooth Connection Monitor' `
    -version '1.0.0.0'

& "$PSScriptRoot\register_aumid.ps1"
& "$PSScriptRoot\update_startup_shortcut.ps1"

Write-Output 'Build complete. BluetoothNotify.exe will now start automatically at logon.'
Write-Output 'To start it immediately: Start-Process "$PSScriptRoot\BluetoothNotify.exe"'

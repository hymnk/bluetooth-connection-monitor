$exePath = "$PSScriptRoot\BluetoothNotify.exe"
$startupDir = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startupDir 'BluetoothConnectNotify.lnk'

$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $exePath
$shortcut.Arguments = ''
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.IconLocation = "$PSScriptRoot\bt_app.ico"
$shortcut.Description = 'Bluetooth connect/disconnect toast notifier'
$shortcut.Save()

Write-Output "Updated: $shortcutPath -> $exePath"

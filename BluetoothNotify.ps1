# Monitors real Bluetooth LE connection status (not the PnP "Status" property,
# which stays "OK" for devices with AlwaysShowDeviceAsConnected=True), shows a
# toast on connect/disconnect, and keeps a tray icon reflecting current status.

# Bluetooth LE device address(es) to watch. Find via:
#   Get-PnpDeviceProperty -InstanceId <InstanceId> -KeyName DEVPKEY_Bluetooth_DeviceAddress
$TargetDevices = @(
    @{ Name = 'Keychron K11 Max'; Address = 'ce20f1c02578' },
    @{ Name = 'MX Ergo S'; Address = 'd97908c41416' }
)
$PollIntervalSec = 1

Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Function Await($WinRtTask, $ResultType) {
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    $asTaskAsync = $asTask.MakeGenericMethod($ResultType)
    $netTask = $asTaskAsync.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

[Windows.Devices.Bluetooth.BluetoothLEDevice, Windows.Devices.Bluetooth, ContentType = WindowsRuntime] | Out-Null
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$AppId = 'BluetoothNotify.App.v3'

function Show-Toast {
    param([string]$Title, [string]$Message)
    $template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$Title</text>
      <text>$Message</text>
    </binding>
  </visual>
  <audio silent="true"/>
</toast>
"@
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId).Show($toast)
}

$devices = @{}
$lastStatus = @{}
foreach ($t in $TargetDevices) {
    $addr = [Convert]::ToUInt64($t.Address, 16)
    $op = [Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync($addr)
    $devices[$t.Name] = Await $op ([Windows.Devices.Bluetooth.BluetoothLEDevice])
    $lastStatus[$t.Name] = $null
}

# Icons are embedded as base64 (not loaded from external files) so the exe has
# no runtime dependency on files in AppData still being present/reachable.
$connectedIconB64 = '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'
$disconnectedIconB64 = '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'

$connectedIcon = New-Object System.Drawing.Icon((New-Object System.IO.MemoryStream(,[Convert]::FromBase64String($connectedIconB64))))
$disconnectedIcon = New-Object System.Drawing.Icon((New-Object System.IO.MemoryStream(,[Convert]::FromBase64String($disconnectedIconB64))))

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = $disconnectedIcon
$notifyIcon.Visible = $true
$notifyIcon.Text = 'Bluetooth Connection Monitor'

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$exitItem = $contextMenu.Items.Add('Exit')
$exitItem.Add_Click({
    $notifyIcon.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})
$notifyIcon.ContextMenuStrip = $contextMenu

function Update-TrayIcon {
    $lines = foreach ($name in $devices.Keys) { "$name`: $($lastStatus[$name])" }
    $allConnected = ($devices.Keys | ForEach-Object { $lastStatus[$_] -eq 'Connected' }) -notcontains $false
    $notifyIcon.Icon = if ($allConnected) { $connectedIcon } else { $disconnectedIcon }
    $tip = ($lines -join "`n")
    if ($tip.Length -gt 127) { $tip = $tip.Substring(0, 127) }
    $notifyIcon.Text = $tip
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $PollIntervalSec * 1000
$timer.Add_Tick({
    try {
        foreach ($name in $devices.Keys) {
            $status = $devices[$name].ConnectionStatus.ToString()

            if ($null -ne $lastStatus[$name] -and $status -ne $lastStatus[$name]) {
                if ($status -eq 'Connected') {
                    Show-Toast -Title "$([System.Char]::ConvertFromUtf32(0x1F7E2)) Bluetooth Connected" -Message "$name is now connected to this PC"
                } else {
                    Show-Toast -Title "$([System.Char]::ConvertFromUtf32(0x1F534)) Bluetooth Disconnected" -Message "$name has disconnected from this PC"
                }
            }
            $lastStatus[$name] = $status
        }
        Update-TrayIcon
    } catch {
        # Never let a transient error (e.g. a momentarily unreachable device)
        # surface as a message box on every tick.
    }
})

# Initialize status once before starting the timer loop
foreach ($name in $devices.Keys) { $lastStatus[$name] = $devices[$name].ConnectionStatus.ToString() }
Update-TrayIcon

$timer.Start()
[System.Windows.Forms.Application]::Run()

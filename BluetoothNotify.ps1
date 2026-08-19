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
$ScriptDir = "$env:LOCALAPPDATA\BluetoothNotify"

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

$logPath = "$ScriptDir\notify.log"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') script started" | Out-File -FilePath $logPath -Append -Encoding utf8

$devices = @{}
$lastStatus = @{}
foreach ($t in $TargetDevices) {
    $addr = [Convert]::ToUInt64($t.Address, 16)
    $op = [Windows.Devices.Bluetooth.BluetoothLEDevice]::FromBluetoothAddressAsync($addr)
    $devices[$t.Name] = Await $op ([Windows.Devices.Bluetooth.BluetoothLEDevice])
    $lastStatus[$t.Name] = $null
}

$connectedIcon = New-Object System.Drawing.Icon("$ScriptDir\bt_connected.ico")
$disconnectedIcon = New-Object System.Drawing.Icon("$ScriptDir\bt_disconnected.ico")

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
    foreach ($name in $devices.Keys) {
        $status = $devices[$name].ConnectionStatus.ToString()

        if ($null -ne $lastStatus[$name] -and $status -ne $lastStatus[$name]) {
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $name = $status" | Out-File -FilePath $logPath -Append -Encoding utf8
            if ($status -eq 'Connected') {
                Show-Toast -Title "$([System.Char]::ConvertFromUtf32(0x1F7E2)) Bluetooth Connected" -Message "$name is now connected to this PC"
            } else {
                Show-Toast -Title "$([System.Char]::ConvertFromUtf32(0x1F534)) Bluetooth Disconnected" -Message "$name has disconnected from this PC"
            }
        }
        $lastStatus[$name] = $status
    }
    Update-TrayIcon
})

# Initialize status once before starting the timer loop
foreach ($name in $devices.Keys) { $lastStatus[$name] = $devices[$name].ConnectionStatus.ToString() }
Update-TrayIcon

$timer.Start()
[System.Windows.Forms.Application]::Run()

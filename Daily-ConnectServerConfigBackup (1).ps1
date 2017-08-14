[CmdletBinding(SupportsShouldProcess=$True)]
param
(
[Parameter(Position=0, Mandatory = $false, HelpMessage="Creates 'scheduled task' in Windows Scheduler that can be adjusted in the future to perform synchronization cycle(s) at particular time interval")]
[Switch] $Schedule,
[Parameter(Position=1, Mandatory = $false, HelpMessage="Enter destination path for ZIP files")]
[String] $DestinationDirectory = "$env:temp"
)

# Switch to directory where script is located
pushd (split-path -parent $MyInvocation.MyCommand.Definition)

if ($schedule)
{
# If scheduled tasks needs to be recreated, run: "./DailyFIMDelta.ps1 -schedule"
$taskname = "Automated Daily AAD Connect Server Config Backup"
schtasks.exe /create /sc DAILY /MO 1 /st 09:00 /np /tn "$taskname" /tr "$PSHOME\powershell.exe -nonInteractive -c '. ''$($myinvocation.mycommand.definition)'''"
exit
}

function Test-IsNonInteractiveShell {
    if ([Environment]::UserInteractive) {
        foreach ($arg in [Environment]::GetCommandLineArgs()) {
            # Test each Arg for match of abbreviated '-NonInteractive' command.
            if ($arg -match '-NonI.*') {
                return $true
            }
        }
    }

    return $false
}

if (!(get-module -name ADSync))
{
import-module ADSync
}

Write-Verbose "Creating temp folder for configuration export"
$foldername = "$env:temp\$(Get-Date -format 'yyyyMMddhhmmss')"
new-item $foldername -ItemType Directory | Out-Null

Write-Verbose "Exporting configuration"
get-adsyncserverconfiguration -Path $foldername

$destination = "$DestinationDirectory\AADConnectBackup-$(Get-Date -format 'yyyyMMddhhmmss').zip"

Write-Verbose "If ZIP file already exists, remove it before creating new ZIP"
If(Test-path $destination) {Remove-item $destination}

Write-Verbose "Zipping up configuration directory"
Add-Type -assembly "system.io.compression.filesystem"
[io.compression.zipfile]::CreateFromDirectory($FolderName, $Destination) 


If (!(Test-IsNonInteractiveShell))
{
  Write-Verbose "Running in Interactive Mode, creating popup"

# test-path ICO file, then find it if false

  [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

  $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon 

  $objNotifyIcon.Icon = "C:\Program Files\Internet Explorer\images\bing.ico"
  $objNotifyIcon.BalloonTipIcon = "Info" 
  $objNotifyIcon.BalloonTipText = "Backup of current AAD Connect configuration has been saved to $destination" 
  $objNotifyIcon.BalloonTipTitle = "AAD Connect Backup Complete"
 
  $objNotifyIcon.Visible = $True 
  $objNotifyIcon.ShowBalloonTip(10000)
}

Write-Verbose "Deleting temp folder"
Remove-Item $foldername -force -recurse

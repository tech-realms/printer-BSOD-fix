if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
    exit;
}

Set-ExecutionPolicy Bypass -Scope CurrentUser

$UpdatePauseDayInterval = 7

function WusaResultMessage($ResultCode) {
    Switch($resultCode) {
        0x240007 { "Update was already uninstalled" }
        0x240005 { "Reboot required." }
        0x242015 { "Update in progress." }
    }
}

Write-Output "Uninstalling KB5000802..."
$TwoUpdateResult = Start-Process -FilePath "wusa.exe" -ArgumentList "/uninstall /kb:5000802 /norestart" -Verb RunAs -Wait -PassThru
Write-Output (WusaResultMessage -ResultCode $TwoUpdateResult.ExitCode)
Write-Output "Uninstalling KB5000808..."
$EightUpdateResult = Start-Process -FilePath "wusa.exe" -ArgumentList "/uninstall /kb:5000808 /norestart" -Verb RunAs -Wait -PassThru
Write-Output (WusaResultMessage -ResultCode $EightUpdateResult.ExitCode)

#Stops Windows Update and disables it on Startup
Stop-Service wuauserv
Set-Service wuauserv -StartupType Disabled

#Prompt user to select # of days to pause updates for
$newdate = (Get-Date).AddDays($UpdatePauseDayInterval)

#Create a New Scheduled Task to run at date specified above
New-ScheduledTaskTrigger -At $newdate -Once

#Sets new task action to open powershell and start the update service
$action = New-ScheduledTaskAction -Execute "Powershell.exe" `
-Argument '-NoProfile -WindowStyle Hidden -command {Start-Service wuauserv}' 

#Sets trigger action to happen once at the new date specified
$trigger = New-ScheduledTaskTrigger -at $newdate -Once

#Creates the New Scheduled Task
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "PauseWinUpdates" -Description "Powershell script to pause Windows Updates until a certain date that is specified by the user"

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

Restart-Computer -Confirm

Set-ExecutionPolicy Undefined -Scope CurrentUser

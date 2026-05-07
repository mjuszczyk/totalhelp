# DeShitifyWindows.ps1
# Script to make Windows more familiar and less bloated
# Run as Administrator

# Check for admin rights
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script must be run as an Administrator!" -ForegroundColor Red
    exit 1
}

# Remove bloatware apps
$BloatApps = @(
    "Microsoft.3DBuilder",
    "Microsoft.BingWeather",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MixedReality.Portal",
    "Microsoft.OneConnect",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.SkypeApp",
    "Microsoft.Wallet",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "microsoft.windowscommunicationsapps",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.YourPhone",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo"
)
foreach ($app in $BloatApps) {
    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

# Restore full right-click context menu (Windows 11)
Write-Host "Restoring full right-click context menu..."
reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f
reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve

# Move taskbar icons to the left (Windows 11)
Write-Host "Aligning taskbar icons to the left..."
$TaskbarRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $TaskbarRegPath -Name "TaskbarAl" -Value 0

# Disable Widgets and News/Interests
Write-Host "Disabling Widgets and News/Interests..."
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f

# Disable Cortana
Write-Host "Disabling Cortana..."
reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f

# Disable Microsoft Teams auto-start
Write-Host "Disabling Microsoft Teams auto-start..."
reg.exe delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v com.squirrel.Teams.Teams /f

# Show file extensions and hidden files
Write-Host "Showing file extensions and hidden files..."
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f

# Remove OneDrive (if present)
Write-Host "Removing OneDrive if present..."
if (Test-Path "C:\\Windows\\System32\\OneDriveSetup.exe") {
    Start-Process "C:\\Windows\\System32\\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait
}

# Disable “Meet Now” in the taskbar
Write-Host "Disabling Meet Now in the taskbar..."
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f

# Disable Snap Layouts suggestions
Write-Host "Disabling Snap Layouts suggestions..."
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f

# Remove Chat from the taskbar
Write-Host "Removing Chat from the taskbar..."
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f

# Disable Start menu web search
Write-Host "Disabling Start menu web search..."
reg.exe add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f

# Set default Explorer view to “This PC”
Write-Host "Setting default Explorer view to 'This PC'..."
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f

# Restart Explorer to apply changes
Write-Host "Restarting Explorer to apply changes..."
Stop-Process -Name explorer -Force
Start-Process explorer

Write-Host "Windows has been de-bloated and made more familiar!" -ForegroundColor Green

# Check if running as an administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`nThis script must be run as an Administrator. Please re-run this script as an Administrator!" -ForegroundColor Red
	Start-Sleep -Seconds 10
    return
}

# Import the module
if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "`nPSWindowsUpdate module is not installed." -ForegroundColor Red
    $userInput = Read-Host "Would you like to install the PSWindowsUpdate module? (Y/N)"
    if ($userInput -eq "Y") {
        Write-Host "`nAttempting to install PSWindowsUpdate module..."
        Install-Module PSWindowsUpdate -Confirm:$false -Force -Scope CurrentUser
        Write-Host "`nPSWindowsUpdate module has been installed successfully." -ForegroundColor Green
    }
} else {
    Write-Host "`nPSWindowsUpdate module is already installed." -ForegroundColor Green
}

# Define a function to display the menu
function Show-Menu {
    param (
        [string]$Title = 'Windows Update Manager'
    )
    Clear-Host
    Write-Host "`n================ $Title ================" -ForegroundColor Cyan
    Write-Host "`n1: Check for updates"
    Write-Host "2: Install all updates"
    Write-Host "3: Install only Windows updates"
    Write-Host "4: Install selective updates"
    Write-Host "5: Exit"
    Write-Host "`n=========================================" -ForegroundColor Cyan
}

# Start the main loop
do {
    Show-Menu
    $userChoice = Read-Host "`nEnter your choice"
    switch ($userChoice) {
        '1' {
            Write-Host "`nInitiating check for updates..."
            Get-WindowsUpdate -MicrosoftUpdate
            Write-Host "`nCheck for updates completed." -ForegroundColor Green
        }
        '2' {
            Write-Host "`nInitiating installation of all updates..."
            $reboot = Read-Host "`nDo you want to allow reboot after installing updates? (Y/N)"
            if ($reboot -eq "Y") {
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
            } else {
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll
            }
            Write-Host "`nInstallation of all updates completed." -ForegroundColor Green
        }
        '3' {
            Write-Host "`nInitiating installation of only Windows updates..."
            $reboot = Read-Host "`nDo you want to allow reboot after installing updates? (Y/N)"
            if ($reboot -eq "Y") {
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot -NotCategory "Drivers","Firmware"
            } else {
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -NotCategory "Drivers","Firmware"
            }
            Write-Host "`nInstallation of only Windows updates completed." -ForegroundColor Green
        }
        '4' {
            Write-Host "`nInitiating installation of selective updates..."
            $updates = Get-WindowsUpdate -MicrosoftUpdate
            $updates | ForEach-Object -Begin { $i = 0 } -Process { Write-Host "`n$($i): $($_.Title)"; $i += 1 }
            $indices = Read-Host "`nEnter the numbers of the updates you want to install (separated by commas)"
            $indices = $indices -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^[0-9]+$' } | ForEach-Object { [int]$_ }
            $selectedUpdates = $indices | ForEach-Object { if ($_ -ge 0 -and $_ -lt $updates.Count) { $updates[$_] } }
            if (-not $selectedUpdates) {
                Write-Host "`nNo valid updates selected. Returning to menu." -ForegroundColor Yellow
                break
            }
            $reboot = Read-Host "`nDo you want to allow reboot after installing updates? (Y/N)"
            if ($reboot -eq "Y") {
                $selectedUpdates | Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
            } else {
                $selectedUpdates | Install-WindowsUpdate -MicrosoftUpdate -AcceptAll
            }
            Write-Host "`nInstallation of selected updates completed." -ForegroundColor Green
        }
        '5' {
            Write-Host "`nExiting..."
            break
        }
        default {
            Write-Host "`nInvalid choice. Please try again." -ForegroundColor Red
        }
    }
    $pause = Read-Host "`nPress Enter to continue or type 'q' to quit menu pause"
    if ($pause -eq 'q') { break }
} while ($true)

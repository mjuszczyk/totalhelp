#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# =========================
# Begin: deshitifywindows.ps1
# =========================

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

# Track errors for summary
$removalErrors = @()
foreach ($app in $BloatApps) {
    try {
        Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -ErrorAction Stop
    } catch {
        $removalErrors += "AppxPackage: $app - $($_.Exception.Message)"
    }
    try {
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online -ErrorAction Stop
    } catch {
        $removalErrors += "ProvisionedPackage: $app - $($_.Exception.Message)"
    }
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

# Disable "Meet Now" in the taskbar
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

# Set default Explorer view to "This PC"
Write-Host "Setting default Explorer view to 'This PC'..."
reg.exe add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f

# Restart Explorer to apply changes
Write-Host "Restarting Explorer to apply changes..."
Stop-Process -Name explorer -Force
Start-Process explorer

if ($removalErrors.Count -gt 0) {
    Write-Host "\nCompleted with some errors during app removal:" -ForegroundColor Yellow
    $removalErrors | ForEach-Object { Write-Host $_ -ForegroundColor DarkYellow }
} else {
    Write-Host "Windows has been deshitified!" -ForegroundColor Green
}

# =========================
# End: deshitifywindows.ps1
# =========================

# =========================
# Begin: windows-enable-rdp.ps1
# =========================

Write-Host "Enabling Remote Desktop..."

# Enable RDP connections
Set-ItemProperty `
    -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
    -Name "fDenyTSConnections" `
    -Value 0 `
    -Type DWord

# Ensure the RDP service is enabled and running
Write-Host "Configuring Remote Desktop Services (TermService)..."
Set-Service -Name "TermService" -StartupType Automatic
Start-Service -Name "TermService"

# Ensure firewall allows inbound TCP 3389
Write-Host "Configuring Windows Firewall for RDP (TCP 3389)..."
$ruleName = "Allow RDP TCP 3389"

if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 3389 `
        -Action Allow `
        -Profile Any | Out-Null
    Write-Host "Created firewall rule: $ruleName"
} else {
    Set-NetFirewallRule -DisplayName $ruleName -Enabled True -Action Allow -Profile Any
    Write-Host "Firewall rule already exists; ensured it is enabled and set to allow."
}

Write-Host ""
Write-Host "Done. RDP has been enabled, TermService is running, and TCP 3389 is allowed through the firewall."

# =========================
# End: windows-enable-rdp.ps1
# =========================

# =========================
# Begin: windows-configure-sshd.ps1
# =========================

Write-Host "Installing OpenSSH Server capability..."

$capability = Get-WindowsCapability -Online |
    Where-Object Name -like "OpenSSH.Server*"

if ($capability.State -ne "Installed") {
    Add-WindowsCapability -Online -Name $capability.Name
} else {
    Write-Host "OpenSSH Server already installed."
}

Write-Host "Enabling and starting sshd..."

Set-Service -Name sshd -StartupType Automatic
Start-Service sshd

Write-Host "Adding Windows Firewall rule for TCP 22..."

$ruleName = "OpenSSH Server (sshd) - TCP 22"

if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 22 `
        -Action Allow `
        -Profile Any
} else {
    Write-Host "Firewall rule already exists."
}

Write-Host "Checking for PowerShell 7..."

$pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue

if (-not $pwsh) {
    $installedWithWinget = $false
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($winget) {
        Write-Host "PowerShell 7 not found. Installing with winget..."
        Write-Host "Running: winget install Microsoft.PowerShell --scope machine..."

        & winget install `
            --id Microsoft.PowerShell `
            --source winget `
            --scope machine `
            --accept-package-agreements `
            --accept-source-agreements

        if ($LASTEXITCODE -eq 0) {
            $installedWithWinget = $true
        } else {
            Write-Host "Winget install returned exit code $LASTEXITCODE. Falling back to MSI installer..."
        }
    } else {
        Write-Host "winget is not available. Falling back to MSI installer..."
    }

    if (-not $installedWithWinget) {
        $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq "Arm64") {
            "arm64"
        } elseif ([Environment]::Is64BitOperatingSystem) {
            "x64"
        } else {
            "x86"
        }

        Write-Host "Downloading latest PowerShell MSI for architecture: $arch"

        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $msi = $release.assets | Where-Object { $_.name -match "PowerShell-.*-win-$arch\.msi$" } | Select-Object -First 1

        if (-not $msi) {
            throw "Could not find a matching PowerShell MSI in latest release assets for architecture $arch."
        }

        $msiPath = Join-Path $env:TEMP $msi.name
        Invoke-WebRequest -Uri $msi.browser_download_url -OutFile $msiPath

        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "MSI installation failed with exit code $($proc.ExitCode)."
        }

        Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
    }

    # Refresh PATH to pick up newly installed pwsh
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
}

if (-not $pwsh) {
    # Check fallback path directly since PATH might not be updated yet
    $fallback = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (Test-Path $fallback) {
        Write-Host "Found PowerShell 7 at fallback path: $fallback"
        $pwshPath = $fallback
    } else {
        throw "PowerShell 7 installation failed or was not found at $fallback"
    }
} else {
    $pwshPath = $pwsh.Source
}

Write-Host "Setting PowerShell 7 as default OpenSSH shell:"
Write-Host $pwshPath

New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null

Set-ItemProperty `
    -Path "HKLM:\SOFTWARE\OpenSSH" `
    -Name DefaultShell `
    -Value $pwshPath

Remove-ItemProperty `
    -Path "HKLM:\SOFTWARE\OpenSSH" `
    -Name DefaultShellCommandOption `
    -ErrorAction SilentlyContinue

Write-Host "Restarting sshd..."

Restart-Service sshd

Write-Host "Installing authorized public key for tela..."

$sshDir = "C:\ProgramData\ssh"
$authKeysFile = "$sshDir\administrators_authorized_keys"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Write-Host "Created SSH directory: $sshDir"
}

$publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPbkZUMWUTVz7MOa6D8HcrMY9uS0z+Yc3ZP/xq754SkB mjuszczyk@tela"

if (Test-Path $authKeysFile) {
    $content = Get-Content $authKeysFile -Raw
    if ($content -notlike "*$publicKey*") {
        Add-Content -Path $authKeysFile -Value $publicKey
        Write-Host "Added tela's public key to $authKeysFile"
    } else {
        Write-Host "tela's public key already present in $authKeysFile"
    }
} else {
    Set-Content -Path $authKeysFile -Value $publicKey
    Write-Host "Created $authKeysFile with tela's public key"
}

# Set proper permissions for SSH to accept the file
Write-Host "Setting permissions on authorized_keys file..."

# Remove inheritance and set explicit permissions
$acl = Get-Acl $authKeysFile
$acl.SetAccessRuleProtection($true, $false)
$acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

# Grant full control to SYSTEM and Administrators
$systemSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")
$adminsSid = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")

$rule1 = New-Object System.Security.AccessControl.FileSystemAccessRule($systemSid, "FullControl", "Allow")
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule($adminsSid, "FullControl", "Allow")

$acl.AddAccessRule($rule1)
$acl.AddAccessRule($rule2)

Set-Acl -Path $authKeysFile -AclObject $acl

Write-Host ""
Write-Host "Done."
Write-Host "Test SSH login from tela with:"
Write-Host "  ssh -i <private_key_path> Administrator@<windows_machine_ip>"
Write-Host ""
Write-Host "Or test locally with:"
Write-Host "  ssh localhost"
Write-Host ""
Write-Host "PowerShell 7 path:"
Write-Host "  $pwshPath"

# =========================
# End: windows-configure-sshd.ps1
# =========================

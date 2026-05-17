#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

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
    Write-Host "PowerShell 7 not found. Installing with winget..."

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue

    if (-not $winget) {
        throw "winget is not available. Install App Installer from Microsoft Store, then rerun this script."
    }

    winget install `
        --id Microsoft.PowerShell `
        --source winget `
        --scope machine `
        --accept-package-agreements `
        --accept-source-agreements

    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
}

if (-not $pwsh) {
    $fallback = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (Test-Path $fallback) {
        $pwsh = $fallback
    } else {
        throw "PowerShell 7 installation failed."
    }
}

Write-Host "Configuring pwsh as the default SSH shell..."

$sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
$pwshPath = $pwsh.Source

if (-not (Test-Path $sshdConfigPath)) {
    throw "sshd_config not found at $sshdConfigPath"
}

$config = Get-Content $sshdConfigPath

# Remove any existing ForceCommand or Subsystem lines for powershell
$config = $config | Where-Object { $_ -notmatch '^(ForceCommand|Subsystem\s+powershell)' }

# Add ForceCommand for pwsh
$config += "ForceCommand $pwshPath -sshs -NoLogo -NoProfile"

Set-Content -Path $sshdConfigPath -Value $config -Force

Write-Host "Restarting sshd to apply changes..."
Restart-Service sshd

Write-Host "OpenSSH and PowerShell 7 are configured. pwsh is now the default SSH shell."

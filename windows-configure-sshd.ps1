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

    Write-Host "Running: winget install Microsoft.PowerShell --scope machine..."
    
    & winget install `
        --id Microsoft.PowerShell `
        --source winget `
        --scope machine `
        --accept-package-agreements `
        --accept-source-agreements
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Winget install returned exit code $LASTEXITCODE. Retrying..."
        Start-Sleep -Seconds 3
        & winget install `
            --id Microsoft.PowerShell `
            --source winget `
            --scope machine `
            --accept-package-agreements `
            --accept-source-agreements
    }

    # Refresh PATH to pick up newly installed pwsh
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
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

Write-Host ""
Write-Host "Done."
Write-Host "Test locally with:"
Write-Host "  ssh localhost"
Write-Host ""
Write-Host "PowerShell 7 path:"
Write-Host "  $pwshPath"
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
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
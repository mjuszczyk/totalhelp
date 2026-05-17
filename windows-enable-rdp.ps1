#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

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

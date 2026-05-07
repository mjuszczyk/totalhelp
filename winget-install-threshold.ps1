# winget-install.ps1
# Installs common apps using winget
# Run as Administrator for best results

$apps = @(
    @{ Name = "Google Chrome"; Id = "Google.Chrome" },
    @{ Name = "Mozilla Firefox"; Id = "Mozilla.Firefox" },
    @{ Name = "VLC Media Player"; Id = "VideoLAN.VLC" },
    @{ Name = "7-Zip"; Id = "7zip.7zip" },
    @{ Name = "WireGuard"; Id = "WireGuard.WireGuard" },
    @{ Name = "Adobe Acrobat Reader"; Id = "Adobe.Acrobat.Reader.64-bit" },
    @{ Name = "KeePass"; Id = "DominikReichl.KeePass" },
    @{ Name = "Google Drive"; Id = "Google.Drive" },
    @{ Name = "Zoom"; Id = "Zoom.Zoom" }
)

foreach ($app in $apps) {
    Write-Host "Installing $($app.Name)..." -ForegroundColor Cyan
    winget install --id $($app.Id) --silent --accept-package-agreements --accept-source-agreements
}

Write-Host "All selected apps have been installed (or were already present)." -ForegroundColor Green

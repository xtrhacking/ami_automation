# PowerShell userdata script for test-windows
# Lab: test-windows
# OS: windows-server-2022
# Description: Simple Windows Server 2022 test lab with IIS and sample web app

Write-Host "============================================"
Write-Host "Starting lab setup: test-windows"
Write-Host "============================================"

# Display environment variables
Write-Host "Lab Name: $env:LAB_NAME"
Write-Host "OS Type: $env:OS_TYPE"
Write-Host "Build Files: $env:BUILD_FILES"

# Install IIS Web Server
Write-Host "Installing IIS Web Server..."
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Write-Host "IIS installed successfully!"

# Install additional IIS features
Write-Host "Installing IIS features..."
Install-WindowsFeature -Name Web-Asp-Net45
Install-WindowsFeature -Name Web-Net-Ext45
Write-Host "IIS features installed!"

# Create web application directory
Write-Host "Creating web application directory..."
New-Item -ItemType Directory -Force -Path "C:\inetpub\wwwroot\testapp" | Out-Null

# Copy sample web files from build files
if (Test-Path "$env:BUILD_FILES\index.html") {
    Write-Host "Copying web files from build-files..."
    Copy-Item -Path "$env:BUILD_FILES\*" -Destination "C:\inetpub\wwwroot\testapp\" -Recurse -Force
    Write-Host "Web files copied successfully!"
} else {
    Write-Host "Warning: No build files found. Creating default content..."
    @"
<!DOCTYPE html>
<html>
<head>
    <title>Test Windows Lab</title>
    <style>
        body { font-family: Arial; margin: 40px; background: #f0f0f0; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; }
        .info { background: #e3f2fd; padding: 10px; border-radius: 4px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class='container'>
        <h1>🪟 Test Windows Lab</h1>
        <div class='info'>
            <strong>Lab:</strong> $env:LAB_NAME<br>
            <strong>OS:</strong> $env:OS_TYPE<br>
            <strong>Status:</strong> ✅ Lab setup completed successfully!
        </div>
        <p>This is a test Windows Server 2022 lab created by ami_automation.</p>
    </div>
</body>
</html>
"@ | Out-File -FilePath "C:\inetpub\wwwroot\testapp\index.html" -Encoding UTF8
}

# Configure IIS
Write-Host "Configuring IIS..."
Import-Module WebAdministration
New-WebApplication -Name "testapp" -Site "Default Web Site" -PhysicalPath "C:\inetpub\wwwroot\testapp" -Force
Write-Host "IIS configured!"

# Enable firewall rule for HTTP
Write-Host "Configuring Windows Firewall..."
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue
Write-Host "Firewall configured!"

# Display completion message
Write-Host "============================================"
Write-Host "✅ Lab setup completed successfully!"
Write-Host "Web app available at: http://localhost/testapp/"
Write-Host "============================================"

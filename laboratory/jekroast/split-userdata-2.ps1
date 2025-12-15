
# Create domain
Write-Host "[*] Creating XTR.local domain..."
$SecPassword = ConvertTo-SecureString "Xtr_VeryHardPass$" -AsPlainText -Force
Install-ADDSForest `
    -CreateDnsDelegation:$false `
    -DomainName "XTR.local" `
    -DomainNetbiosName "XTR" `
    -InstallDns:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "7" `
    -ForestMode "7" `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$true `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true `
    -SafeModeAdministratorPassword $SecPassword

Write-Host "[+] AD Domain created"

# Wait for AD to be ready
Write-Host "[*] Waiting for AD services to start..."
Start-Sleep -Seconds 60

# Add AD management tools
Write-Host "[*] Installing AD management tools..."
Add-WindowsFeature RSAT-AD-PowerShell
Add-WindowsFeature RSAT-AD-Tools
Import-Module ActiveDirectory

# Restart

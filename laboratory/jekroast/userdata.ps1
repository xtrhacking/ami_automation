#
# JekRoast Lab Provisioning Script
# This script configures a Windows Server as an Active Directory Domain Controller
# for the JekRoast security lab
#

$ErrorActionPreference = "Stop"

Write-Host "============================================"
Write-Host "JekRoast Lab Provisioning Started"
Write-Host "============================================"

# Disable Windows Defender
Write-Host "[*] Disabling Windows Defender..."
try {
    New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\" -Name "Windows Defender" -ErrorAction Ignore
    Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" 1
    New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft' -Name "Windows Defender" -Force -ea 0
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -PropertyType DWORD -Force -ea 0
    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableRoutinelyTakingAction" -Value 1 -PropertyType DWORD -Force -ea 0

    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
        -DisableIntrusionPreventionSystem $true -DisableIOAVProtection $true -DisableScriptScanning $true `
        -DisableArchiveScanning $true -DisableCatchupFullScan $true -DisableCatchupQuickScan $true `
        -DisableEmailScanning $true -DisableRemovableDriveScanning $true `
        -DisableScanningMappedNetworkDrivesForFullScan $true -DisableScanningNetworkFiles $true `
        -SignatureDisableUpdateOnStartupWithoutEngine $true -DisableBlockAtFirstSeen $true `
        -SevereThreatDefaultAction 6 -MAPSReporting 0 -HighThreatDefaultAction 6 `
        -ModerateThreatDefaultAction 6 -LowThreatDefaultAction 6 -SubmitSamplesConsent 2 -ErrorAction Stop

    # Exclude C drive from scans
    Add-MpPreference -ExclusionPath "C:\"
    Write-Host "[+] Windows Defender disabled"
}
catch {
    Write-Host "[-] Failed to disable Windows Defender: $_"
}

# Install Chocolatey
Write-Host "[*] Installing Chocolatey..."
$testchoco = $false
try { choco -v; $testchoco = $true } catch { $testchoco = $false }
if (-not $testchoco) {
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "[+] Chocolatey installed"
    }
    catch {
        Write-Host "[-] Failed to install Chocolatey: $_"
        throw
    }
}
else {
    Write-Host "[+] Chocolatey already installed"
}

# Install required tools
Write-Host "[*] Installing required tools..."
choco install microsoft-edge -y
Write-Host "[+] Installed Microsoft Edge"

choco install sysinternals -y
Write-Host "[+] Installed SysInternals"

choco install apimonitor -y
Write-Host "[+] Installed APIMonitor"

choco install apache-httpd --params '"/installLocation:C:\HTTPD /port:8080"' -y
Write-Host "[+] Installed Apache HTTPD"

# Rename computer to Extreme-DC
Write-Host "[*] Renaming computer to Extreme-DC..."
Rename-Computer -NewName "Extreme-DC" -Force
Write-Host "[+] Computer renamed"

# Install Active Directory Domain Services
Write-Host "[*] Installing Active Directory Domain Services..."
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment

# Restart
Restart-Computer -Force

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
Restart-Computer -Force

# Ease password policy
Write-Host "[*] Configuring password policy..."
Set-ADDefaultDomainPasswordPolicy -Identity XTR.local `
    -ComplexityEnabled $false `
    -MinPasswordLength 1 `
    -PasswordHistoryCount 1 `
    -LockoutThreshold 1000

# Create computers
Write-Host "[*] Creating computer accounts..."
$computers = @("DESK_01", "DESK_02", "NOTE_03")
foreach ($computer in $computers) {
    try {
        New-ADComputer -Name $computer `
            -AccountPassword (ConvertTo-SecureString 'Xtr3m3H@ck!2024' -AsPlainText -Force) `
            -Enabled $true
        Write-Host "[+] Created computer: $computer"
    }
    catch {
        Write-Host "[!] Computer $computer might already exist"
    }
}

# Create OUs
Write-Host "[*] Creating Organizational Units..."
$ous = @("Gerentes", "Usuarios", "SuporteTI")
foreach ($ou in $ous) {
    try {
        New-ADOrganizationalUnit -Name $ou -Path "DC=XTR,DC=local"
        Write-Host "[+] Created OU: $ou"
    }
    catch {
        Write-Host "[!] OU $ou might already exist"
    }
}

# Create users
Write-Host "[*] Creating user accounts..."
$users = @{
    "465-9346" = @{ Name = "Acacio"; Surname = "Muniz"; Password = "acfPassw0rd!"; Admin = $false }
    "adm465-9346" = @{ Name = "Acacio"; Surname = "Muniz"; Password = "EsseEhMeuPassw0rd!"; Admin = $true }
    "465-1300" = @{ Name = "Pedro"; Surname = "Silva"; Password = "basPassw0rd!"; Admin = $false }
    "465-8099" = @{ Name = "Maria"; Surname = "Jose"; Password = "rose1994"; Admin = $false }
    "465-2467" = @{ Name = "Tito"; Surname = "Silva"; Password = "xbox360"; Admin = $false }
}

foreach ($samAccount in $users.Keys) {
    $user = $users[$samAccount]
    try {
        New-ADUser -Name $user.Surname `
            -Surname $user.Name `
            -SamAccountName $samAccount `
            -UserPrincipalName ($samAccount + "@XTR.local") `
            -Path "OU=Usuarios,DC=XTR,DC=local" `
            -AccountPassword (ConvertTo-SecureString $user.Password -AsPlainText -Force) `
            -Enabled $true
        Write-Host "[+] Created user: $samAccount ($($user.Name) $($user.Surname))"
    }
    catch {
        Write-Host "[!] User $samAccount might already exist"
    }
}

# Configure specific users
Write-Host "[*] Configuring user permissions..."
Add-ADGroupMember -Identity "Remote Management Users" -Members "465-2467" -ErrorAction SilentlyContinue
Set-ADUser -Identity "465-8099" -ServicePrincipalNames @{Add='HTTP/thewallserver'} -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "DnsAdmins" -Members "465-8099" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Remote Management Users" -Members "465-8099" -ErrorAction SilentlyContinue
Add-ADGroupMember -Identity "Server Operators" -Members "465-8099" -ErrorAction SilentlyContinue

# Create admin accounts
Write-Host "[*] Creating admin accounts..."
try {
    New-ADUser -Name "xtrAdmin" `
        -AccountPassword (ConvertTo-SecureString 'Xtr3m3H@ck!2024' -AsPlainText -Force) `
        -Enabled $true
    Add-ADGroupMember -Identity "Domain Admins" -Members "xtrAdmin"
    Add-ADGroupMember -Identity "Domain Admins" -Members "adm465-9346"
    Write-Host "[+] Admin accounts created"
}
catch {
    Write-Host "[!] Admin accounts might already exist"
}

# Enable PowerShell logging
Write-Host "[*] Enabling PowerShell logging..."

# Process Creation Logging
auditpol /set /category:"detailed tracking" /subcategory:"Process Creation" /success:enable | Out-Null

# Command line in process creation events
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
New-ItemProperty -Path $registryPath -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -PropertyType DWORD -Force -ea 0 | Out-Null

# Module Logging
$registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
New-ItemProperty -Path $registryPath -Name "EnableModuleLogging" -Value 1 -PropertyType DWORD -Force -ea 0 | Out-Null

$registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames"
if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
New-ItemProperty -Path $registryPath -Name "*" -Value "*" -Force -ea 0 | Out-Null

# Script Block Logging
$registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
New-ItemProperty -Path $registryPath -Name "EnableScriptBlockLogging" -Value 1 -PropertyType DWORD -Force -ea 0 | Out-Null
New-ItemProperty -Path $registryPath -Name "EnableScriptBlockInvocationLogging" -Value 1 -PropertyType DWORD -Force -ea 0 | Out-Null

# PowerShell Transcription
$registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription"
if (!(Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
New-ItemProperty -Path $registryPath -Name "EnableInvocationHeader" -Value 1 -PropertyType DWORD -Force -ea 0 | Out-Null
New-ItemProperty -Path $registryPath -Name "EnableTranscripting" -Value 1 -PropertyType DWORD -Force -ea 0 | Out-Null
New-ItemProperty -Path $registryPath -Name "OutputDirectory" -Value "C:\PowerShell_Logs\" -Force -ea 0 | Out-Null

Write-Host "[+] PowerShell logging enabled"

# Configure Explorer
Write-Host "[*] Configuring Explorer..."
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-ItemProperty $key Hidden 1
Set-ItemProperty $key HideFileExt 0
Set-ItemProperty $key ShowSuperHidden 1

# Correcao para pegar a variavel do local dos builds
# Write-Host "[*] Copying lab files..."
# if (Test-Path "C:\Users\Public\lab-files") {
#     Copy-Item -Path "C:\Users\Public\lab-files\*" -Destination "C:\Users\Public\" -Recurse -Force
#     Write-Host "[+] Lab files copied"
# }

# Copy lab files
Write-Host "[*] Copying lab files..."
if (Test-Path "$env:BUILD_FILES") {
    Copy-Item -Path "$env:BUILD_FILES\*" -Destination "C:\Users\Public\" -Recurse -Force
    Write-Host "[+] Lab files copied"
}

# Create flag files
Write-Host "[*] Creating flag files..."
New-Item -Path "C:\Users\465-2467\Desktop" -ItemType Directory -Force | Out-Null
Add-Content -Path "C:\Users\465-2467\Desktop\local.txt" -Value "Extreme{5c31c1ace6e1d61a5bea9609f0b9e51d7c919a51}"

New-Item -Path "C:\Users\Administrator\Desktop" -ItemType Directory -Force | Out-Null
Add-Content -Path "C:\Users\Administrator\Desktop\proof.txt" -Value "Extreme{5b73deb4abcec133eb5f93717649f8777f91e797}"
Write-Host "[+] Flag files created"

# Clean up
Write-Host "[*] Cleaning up..."
# Correcao para pegar a variavel do local dos builds
#Remove-Item -Path "C:\Users\Public\lab-files" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:BUILD_FILES" -Recurse -Force -ErrorAction SilentlyContinue
# O provision.ps1 = userdata.ps1 nao é copiado para a maquina
#Remove-Item -Path "C:\Users\Public\provision.ps1" -Force -ErrorAction SilentlyContinue

Write-Host "============================================"
Write-Host "JekRoast Lab Provisioning Completed!"
Write-Host "============================================"
Write-Host ""
Write-Host "Lab Details:"
Write-Host "  - Computer: Extreme-DC"
Write-Host "  - Domain: XTR.local"
Write-Host "  - Safe Mode Password: Xtr_VeryHardPass$"
Write-Host "  - Admin Account: xtrAdmin / Xtr3m3H@ck!2024"
Write-Host "  - Apache HTTPD: Port 8080"
Write-Host ""
Write-Host "AMI is ready to be created."
Write-Host "============================================"

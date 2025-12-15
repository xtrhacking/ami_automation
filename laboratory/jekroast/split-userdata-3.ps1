
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

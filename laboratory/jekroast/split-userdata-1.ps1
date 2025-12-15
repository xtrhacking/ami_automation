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

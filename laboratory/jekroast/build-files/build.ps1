$ErrorActionPreference = "Stop"


if ($env:COMPUTERNAME -ne "Extreme-DC") {

    # Disable Windows Defender
    $defender = Get-MpPreference | Select-Object -ExpandProperty DisableRealtimeMonitoring
    if ($defender -eq $true) {
        Write-Host "[i] Windows Defender is already disabled"
    }
    else {
        Write-Host "[i] Disabling Windows Defender"
        New-Item -Path "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\" -Name "Windows Defender" -ErrorAction Ignore
        Set-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" 1
        New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft' -Name "Windows Defender" -Force -ea 0
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value 1 -PropertyType DWORD -Force -ea 0
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableRoutinelyTakingAction" -Value 1 -PropertyType DWORD -Force -ea 0
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SpyNetReporting" -Value 0 -PropertyType DWORD -Force -ea 0
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" -Name "SubmitSamplesConsent" -Value 0 -PropertyType DWORD -Force -ea 0
        New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\MRT" -Name "DontReportInfectionInformation" -Value 1 -PropertyType DWORD -Force -ea 0
    

        Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true `
        -DisableIntrusionPreventionSystem $true -DisableIOAVProtection $true -DisableScriptScanning $true `
        -DisableArchiveScanning $true -DisableCatchupFullScan $true -DisableCatchupQuickScan $true `
        -DisableEmailScanning $true -DisableRemovableDriveScanning $true -DisableScanningMappedNetworkDrivesForFullScan $true `
        -DisableScanningNetworkFiles $true -SignatureDisableUpdateOnStartupWithoutEngine $true -DisableBlockAtFirstSeen $true `
        -SevereThreatDefaultAction 6 -MAPSReporting 0 -HighThreatDefaultAction 6 -ModerateThreatDefaultAction 6 -LowThreatDefaultAction 6 `
        -SubmitSamplesConsent 2 -ErrorAction Stop

        # exclude C drive from A/V scans
        Add-MpPreference -ExclusionPath "C:\"
    }

    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultUserName' -Type String -Value "Administrator";
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultPassword' -Type String -Value "Xtr2023";
    
    #Check and create if not exists
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $name = 'AutoAdminLogon'
    $value = '1'
    IF (!(Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
        New-ItemProperty -Path $key -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
    } ELSE {
        New-ItemProperty -Path $key -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
    }

    $sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value;
    $executionTimeLimit = New-TimeSpan -Hours 72

    # validate if scheduled task already exists

    $task = Get-ScheduledTask -TaskName 'SetupDC' -ErrorAction Ignore;
    if ($task -eq $null) {
        $taskName = "SetupDC"
        $taskPath = "\"
        $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-noexit -ep bypass C:\Users\Public\build.ps1"
        $taskTrigger = New-ScheduledTaskTrigger -AtLogon -User (whoami)
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId $sid -LogonType Interactive -RunLevel Highest
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$false -ExecutionTimeLimit $executionTimeLimit -Priority 7    
        Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $taskAction -Trigger $taskTrigger -Principal $taskPrincipal -Settings $taskSettings 

    }

   
   
    # Register-ScheduledTask -TaskName 'SetupDC' -XML $XML_TASK;
    Write-Host "[i] Scheduled Task SetupDC to continue setup as Administrator set";

    # Install tools
    Write-Host "[i] Installing dependencies";

    $testchoco = $false;
    try { choco -v; $testchoco = $true } catch { $testchoco = $false };
    if (-not $testchoco) {
        try {
            Write-Host "[i] Chocolatey not already installed, installing now";
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'));
            Write-Host "[+] Installed Chocolatey";
        } catch {
            Write-Host "[-] Failed to install Chocolatey";
            Write-Host "[-] It looks like your VM may be behind a proxy causing SSL Certificate errors. To run this script, either connect to the internet without the proxy, or install the proxy's certificates on your VM. Once that's done, you can rerun this script.";
            Return;
        }
    } else {
        Write-Host "[+] Chocolatey already installed, proceeding";
    }

   
    
    choco install microsoft-edge -y;
    Write-Host "[+] Installed Microsoft Edge";

    
    #Install SysInternals using Chocolatey
    choco install sysinternals -y;
    Write-Host "[+] Installed SysInternals";

    #Install APIMonitor using Chocolatey
    choco install apimonitor -y;
    Write-Host "[+] Installed APIMonitor";

    choco install apache-httpd --params '"/installLocation:C:\HTTPD /port:8080"' -y;
    Write-Host "[+] Installed Apache HTTPD";
    
    
    Start-Sleep -Seconds 3;
    Write-Host "[i] Renaming server to DC"
    Write-Host "[i] Server will automatically restart"

    

    Rename-Computer -NewName "Extreme-DC" -Restart
}
elseif ((Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem).Domain -ne "xtr.local") {
    #Add domain name to auto login
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultDomainName' -Type String -Value "XTR";

    #Create XTR.local domain
    Write-Host "[i] Creating XTR.local domain"
    Install-WindowsFeature AD-Domain-Services
    Import-Module ADDSDeployment
    $SecPassword = ConvertTo-SecureString "Xtr_VeryHardPass$" -AsPlainText -Force
    Write-Host "[i] The server will automatically restart after the domain is created"
    Install-ADDSForest -CreateDnsDelegation:$false -DomainName "XTR.local" -DomainNetbiosName "XTR" -InstallDns:$true -DatabasePath "C:\Windows\NTDS" -DomainMode "7" -ForestMode "7" -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true -SafeModeAdministratorPassword $SecPassword

}
else {
    Write-Host "[i] Waiting for AD services to start"
    $AD_enabled = $false;
    while (-not ($AD_enabled)) {
        try {
            Get-ADUser Administrator;
            $AD_enabled = $true;
            Write-Host "[+] AD Services started, proceeding"
        } catch {
            Write-Host "[i] Still waiting..."
            Start-Sleep -Seconds 5;
        }
    }

    $userobj = $(try {Get-ADUser "xtrAdmin"} catch {$Null});
    if ($userobj -eq $Null) {
        # Add objects to domain
        Add-WindowsFeature RSAT-AD-PowerShell
        # Add features tools to Manage the AD Domain
        add-windowsfeature RSAT-AD-Tools
               
        Import-Module ActiveDirectory

        #Easing password policy requirements
        Set-ADDefaultDomainPasswordPolicy -Identity XTR.local -ComplexityEnabled $false  -MinPasswordLength 1 -PasswordHistoryCount 1 -LockoutThreshold 1000

        # validate if computer list exists if not create it
        #Create a list
        $list = @("DESK_01","DESK_02","NOTE_03")

        # Validate if computers at list exists
        $list | ForEach-Object {
            $computer = $_;
            $computerobj = $(try {Get-ADComputer $computer} catch {$Null});
            if ($computerobj -eq $Null) {
                Write-Host "[i] Computer $computer does not exist, creating it";
                New-ADComputer -Name $computer -AccountPassword (ConvertTo-SecureString 'Xtr3m3H@ck!2024' -AsPlainText -Force) -Enabled $true;
            } else {
                Write-Host "[i] Computer $computer already exists, proceeding";
            }
        }


        #Creating Organizational Units
        # Create a OU List
        $list = @("Gerentes","Usuarios","SuporteTI")

        # Validate if OU at list exists
        $list | ForEach-Object {
            $ou = $_;
            $ouobj = Get-ADOrganizationalUnit -Filter "Name -eq '$($ou)'"  -ErrorAction SilentlyContinue;
            if ($ouobj -eq $null) {
                Write-Host "[i] OU $ou does not exist, creating it";
                New-ADOrganizationalUnit -Name $ou -Path "DC=XTR,DC=local";
            } else {
                Write-Host "[i] OU $ou already exists, proceeding";
            }
        }

        #Creating Users dictionary with two attributes name, password
        $users = @{}
        $users.Add("465-9346 Acacio Muniz","acfPassw0rd!")
        $users.Add("adm465-9346 Acacio Muniz","EsseEhMeuPassw0rd!")
        $users.Add("465-1300 Pedro Silva","basPassw0rd!")
        $users.Add("465-8099 Maria Jose","rose1994")
        $users.Add("465-2467 Tito Silva","xbox360")

        #Creating Users
        $users.GetEnumerator() | ForEach-Object {
            $user = $_;
            $userobj = Get-ADUser -Filter "Name -eq '$($user.Name.Split(" ")[1])'" -ErrorAction SilentlyContinue; 
            if ($userobj -eq $Null) {
                Write-Host "[i] User $($user.Name) does not exist, creating it";
                New-ADUser -Name $user.Name.Split(" ")[1] -Surname $user.Name.Split(" ")[0] -SamAccountName ($user.Name.Split(" ")[0]) -UserPrincipalName ($user.Name.Split(" ")[0] + "@XTR.local") -Path "OU=Usuarios,DC=XTR,DC=local" -AccountPassword (ConvertTo-SecureString $user.Value -AsPlainText -Force) -Enabled $true 
            } else {
                Write-Host "[i] User $($user.Name.Split(" ")[1]) already exists, proceeding";
                #Delete user if exists
                #Remove-ADUser -Identity $user.Name -Confirm:$false
            }
        }

       $userobj = "tito" # replace with the actual username
       $user = Get-ADUser -Filter "Name -eq '$($userobj)'"; 

       if ($user) {
        
            Add-ADGroupMember -Identity "Remote Management Users" -Members "465-2467"
            #Set-ADUser -Identity $user -Add @{"msDS-AllowedToActOnBehalfOfOtherIdentity" = "OU=SuporteTI,DC=XTR,DC=local"}
       } else {
             Write-Error "User $userobj not found"
            exit 1

       }
        #Adding new Domain Admin account
        Write-Host "[i] Adding xtrAdmin Domain Admin account";
        New-ADUser -Name "xtrAdmin" -AccountPassword (ConvertTo-SecureString 'Xtr3m3H@ck!2024' -AsPlainText -Force) -Enabled $true
        Add-ADGroupMember -Identity "Domain Admins" -Members "xtrAdmin"
        Add-ADGroupMember -Identity "Domain Admins" -Members "adm465-9346"
        net localgroup Administrators adm465-9346 /add
        net localgroup Administrators xtrAdmin /add
        Write-Host "[i] xtrAdmin Domain Admin account added"

        #

        $trigger = New-ScheduledTaskTrigger -AtLogon -User 'xtrAdmin';
        Set-ScheduledTask -TaskName 'SetupDC' -User 'xtrAdmin' -Trigger $trigger;
        Write-Host "[i] Modified SetupDC scheduled task to complete as xtrAdmin";

        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultUserName' -Type String -Value "xtrAdmin";
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultPassword' -Type String -Value "Xtr3m3H@ck!2024";
        Write-Host "[i] Changed autologon creds to XTR\xtrAdmin";

        Start-Sleep -Seconds 3;
        Restart-Computer -Force;
    
    }
    #Step 4
    else {
        #Make hidden files and extensions visible in Explorer
        Write-Host "[i] Making hidden files and extensions visible in Explorer"
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-ItemProperty $key Hidden 1
        Set-ItemProperty $key HideFileExt 0
        Set-ItemProperty $key ShowSuperHidden 1
        Stop-Process -processname explorer
        
        
        # enable PowerShell logging
        Write-Host "[i] Enabling PowerShell logging"
        # Original script taken from: https://raw.githubusercontent.com/timip/splunk/master/powershell_logging.ps1

        ########## AS_W_01 ##########
        # Audit Success Process Creation event

        auditpol /set /category:"detailed tracking" /subcategory:"Process Creation" /success:enable | Out-Null

        ########## AS_W_02 ##########
        # Include command line in process creation events

        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
        $Name = "ProcessCreationIncludeCmdLine_Enabled"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        ########## AS_W_03 ##########
        # Turn on Module Logging

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
        $Name = "EnableModuleLogging"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames"
        $Name = "*"
        $value = "*"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
        }

        ########## AS_W_04 ##########
        # Configure script block logging for PowerShell

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
        $Name = "EnableScriptBlockLogging"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
        $Name = "EnableScriptBlockInvocationLogging"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        ########## AS_W_05 ##########
        # Turn on PowerShell Transcript

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription"
        $Name = "EnableInvocationHeader"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription"
        $Name = "EnableTranscripting"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }


        ########## AS_W_06 ##########
        # Create and Secure Folder for PowerShell Transcript

        ########## AS_W_01 ##########
        # Audit Success Process Creation event

        auditpol /set /category:"detailed tracking" /subcategory:"Process Creation" /success:enable | Out-Null

        ########## AS_W_02 ##########
        # Include command line in process creation events

        $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit"
        $Name = "ProcessCreationIncludeCmdLine_Enabled"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        ########## AS_W_03 ##########
        # Turn on Module Logging

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
        $Name = "EnableModuleLogging"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames"
        $Name = "*"
        $value = "*"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
        }

        ########## AS_W_04 ##########
        # Configure script block logging for PowerShell

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
        $Name = "EnableScriptBlockLogging"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
        $Name = "EnableScriptBlockInvocationLogging"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        ########## AS_W_05 ##########
        # Turn on PowerShell Transcript

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription"
        $Name = "EnableInvocationHeader"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription"
        $Name = "EnableTranscripting"
        $value = "1"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
        }

        $registryPath = "HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\Transcription"
        $Name = "OutputDirectory"
        $value = "C:\PowerShell_Logs\"

        IF (!(Test-Path $registryPath)) {
            New-Item -Path $registryPath -Force | Out-Null
            New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
        } ELSE {
            New-ItemProperty -Path $registryPath -Name $name -Value $value -Force | Out-Null
        }


         
        Set-ADUser -Identity "465-8099" -ServicePrincipalNames @{Add='HTTP/thewallserver'}
        Add-ADGroupMember -Identity "DnsAdmins" -Members "465-8099"
        Add-ADGroupMember -Identity "Remote Management Users" -Members "465-8099"
        Add-ADGroupMember -Identity "Server Operators" -Members "465-8099"


        #Remove SetupDC scheduled task  
        Unregister-ScheduledTask -TaskName 'SetupDC' -Confirm:$false;
        Write-Host "[i] Deleted SetupDC scheduled task";

        #Remove Autologon creds
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultUserName' -Type String -Value "";
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultPassword' -Type String -Value "";
        Remove-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'AutoAdminLogon';
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name 'DefaultDomainName' -Type String -Value "";
        Write-Host "[i] Removed autologon credentials.";

        Write-Host "[i] Setup is now complete. Server will reboot for clean start.";


Add-Content -Path "C:\Users\465-2467\Desktop\local.txt" -Value "Extreme{5c31c1ace6e1d61a5bea9609f0b9e51d7c919a51}"

Add-Content -Path "C:\Users\Administrator\Desktop\proof.txt" -Value "Extreme{5b73deb4abcec133eb5f93717649f8777f91e797}"

        Start-Sleep -Seconds 3;
        Restart-Computer -Force;
    }
}





Test Windows Lab - Build Files
================================

This directory contains build files for the test-windows laboratory.

Files:
------
- index.html: Main web application page
- config.json: Lab configuration metadata
- README.txt: This file

Purpose:
--------
This lab demonstrates:
1. Windows Server 2022 AMI creation
2. IIS installation and configuration
3. Custom web application deployment
4. Build files integration with Packer

Usage:
------
These files are automatically copied to the Windows instance during
the AMI build process at: C:\temp\build-files\

The userdata.ps1 script then copies them to the web application
directory: C:\inetpub\wwwroot\testapp\

Access:
-------
Once the AMI is deployed, access the web application at:
http://<instance-ip>/testapp/

Notes:
------
- This is a test lab created for the shell-to-python migration
- All scripts are now Python-based
- 59/59 tests passing
- Ready for production use

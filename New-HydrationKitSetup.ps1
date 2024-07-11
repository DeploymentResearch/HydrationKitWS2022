<#
    .SYNOPSIS
    Sample script for the Hydration Kit

    .DESCRIPTION
    Creates the Hydration Kit deployment share. 
    The script must be run under an administrative account context and its only been tested with PowerShell 5.1
    
    .NOTES
    Created: 8/24/2021
    Version: 1.1

    Author : Johan Arwidmark
    Twitter: @jarwidmark
    Blog   : http://deploymentresearch.com

    Disclaimer: This script is provided "AS IS" with no warranties, confers no rights and 
    is not supported by the author or DeploymentArtist..

    .PARAMETER Path
    Specifies the path for Hydration Kit installation directory.
    
    .PARAMETER ShareName
    Specifies the SMB share name for Hydration Kit.


    .EXAMPLE
   .\New-HydrationKitSetup.ps1 -Path C:\CMLab -ShareName CMLab
#>

#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [parameter(Mandatory=$true, HelpMessage="Specify the path for Hydration Kit installation directory.")]
    [ValidateNotNullOrEmpty()]
    [string]$Path,
        [parameter(Mandatory=$true, HelpMessage="Specify the SMB share name for Hydration Kit.")]
    [ValidateNotNullOrEmpty()]
    [string]$ShareName

)

# Some basic validations

# Verify that MDT 8456 is installed
if (!((Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -eq "Microsoft Deployment Toolkit (6.3.8456.1000)"}).Displayname).count) {
    Write-Warning "MDT 8456 not installed, aborting..."
    Break
}

# Verify that UEFI HotFix for MDT 8456 (KB4564442) is installed
$MDTInstallDir = ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir).TrimEnd('\')
$X64HotFixPath = "$MDTInstallDir\Templates\Distribution\Tools\x64\Microsoft.BDD.Utility.dll"
$X64HotFixVersion = (Get-Item $X64HotFixPath).VersionInfo.ProductPrivatePart

If (!($X64HotFixVersion -ge 1001)){
    Write-Warning "MDT 8456 HotFix (KB4564442) is not installed, aborting..."
    Write-Warning "The updated Microsoft.BDD.Utility.dll file needs to be copied to the MDT installation directory"
    Write-Warning "See KB4564442 for details"
    Break
}

# Verify that Windows ADK and Windows ADK WinPE Addon are installed 
if (!((Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -match "Windows Assessment and Deployment Kit*"}).Displayname).count) {
    Write-Warning "Windows ADK is not installed, aborting..."
    Break
}
if (!((Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object {$_.DisplayName -match "Windows Assessment and Deployment Kit Windows Preinstallation Environment*"}).Displayname).count) {
    Write-Warning "Windows ADK WinPE Addon is not installed, aborting..."
    Break
}

# Verify that the SMB share doesn't exist already
If (Get-SmbShare | Where-Object { $_.Name -eq "$ShareName"}){
    Write-Warning "Hydration Kit share $ShareName already exist, please cleanup and try again. Aborting..."
    Break
}

# Verify that the folder or deployment share doesn't exist already
if (Test-Path -Path "$Path") {
    Write-Warning "Hydration Kit folder $Path already exist, please cleanup and try again. Aborting..."
    Break
}

# Verify that the PSDrive doesnt exist already
if (Test-Path -Path "DS001:") {
    Write-Warning "DS001: PSDrive already exist, please cleanup and try again. Aborting..."
    Break
}

# Check free disk space. Minimum for the Hydration Kit is 50 GB
$KitRootDrive = Split-Path -Path $Path -Qualifier
$NeededFreeSpace = 50GB
$NeededFreeSpaceInGB = [MATH]::ROUND($NeededFreeSpace /1GB)
$Disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$KitRootDrive'" 
$FreeSpace = $Disk.FreeSpace
$FreeSpaceInGB = [MATH]::ROUND($FreeSpace /1GB)
#Write-Output "Checking free space on $KitRootDrive"
#Write-Output "Hydration Kit requires $NeededFreeSpaceInGB GB"

if($FreeSpace -lt $NeededFreeSpace){
    Write-Warning "You need at least $NeededFreeSpaceInGB GB of free disk space on $KitRootDrive "
    Write-Warning "Available free disk space on C: is $FreeSpaceInGB GB"
    Write-Warning "Aborting script..."
    Break
}
Else {
    # Write-Output "All OK, available free disk space on C: is $FreeSpaceInGB GB"
}


# Validation OK, create the Hydration Deployment Share
$MDTServer = (get-wmiobject win32_computersystem).Name

Add-PSSnapIn Microsoft.BDD.PSSnapIn -ErrorAction SilentlyContinue | Out-Null
New-Item -Path "$Path\DS" -ItemType Directory | Out-Null
New-SmbShare -Name $ShareName -Path "$Path\DS" -ChangeAccess EVERYONE | Out-Null
New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root "$Path\DS" -Description "Hydration Kit ConfigMgr" -NetworkPath "\\$MDTServer\$ShareName" | add-MDTPersistentDrive | Out-Null

New-Item -Path "$Path\ISO\Content\Deploy" -ItemType Directory | Out-Null
New-Item -path "DS001:\Media" -enable "True" -Name "MEDIA001" -Comments "" -Root "$Path\ISO" -SelectionProfile "Everything" -SupportX86 "False" -SupportX64 "True" -GenerateISO "True" -ISOName "HydrationCMWS2022.iso"  | Out-Null
New-PSDrive -Name "MEDIA001" -PSProvider "MDTProvider" -Root "$Path\ISO\Content\Deploy" -Description "Hydration Kit ConfigMgr Media" -Force | Out-Null

# Configure MEDIA001 Settings (disable MDAC) - Not needed in the Hydration Kit
Set-ItemProperty -Path MEDIA001: -Name Boot.x86.FeaturePacks -Value ""
Set-ItemProperty -Path MEDIA001: -Name Boot.x64.FeaturePacks -Value ""

# Copy sample files to Hydration Deployment Share
$ScriptPath = $PSScriptRoot
Copy-Item -Path "$ScriptPath\Source\Hydration\Applications" -Destination "$Path\DS" -Recurse -Force
Copy-Item -Path "$ScriptPath\Source\Hydration\Control" -Destination "$Path\DS" -Recurse -Force
Copy-Item -Path "$ScriptPath\Source\Hydration\Scripts" -Destination "$Path\DS" -Recurse -Force
Copy-Item -Path "$ScriptPath\Source\Hydration\Tools\Modules" -Destination "$Path\DS\Tools" -Recurse -Force -verbose
Copy-Item -Path "$ScriptPath\Source\Media\Control" -Destination "$Path\ISO\Content\Deploy" -Recurse -Force

# Create target folder structure for the operating systems
New-Item -Path "$Path\DS\Operating Systems\WS2022\sources\sxs" -ItemType Directory -Force
New-Item -Path "$Path\DS\Operating Systems\Windows 10\sources\sxs" -ItemType Directory -Force
New-Item -Path "$Path\DS\Operating Systems\Windows 11\sources\sxs" -ItemType Directory -Force

# Create target folder structure for application sources
New-Item -Path "$Path\DS\Applications\Install - SQL Server Management Studio" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - Windows ADK 11\Source" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - Windows ADK 11 WinPE Addon\Source" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - SQL Server 2019 Standard\Source" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - ConfigMgr\Source" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - ConfigMgr\PreReqs" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - MDT" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - SQL Server 2019 Express\Source" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - SQL Server 2019 Reporting Services\Source" -ItemType Directory -Force
New-Item -Path "$Path\DS\Applications\Install - Microsoft ODBC Driver 18" -ItemType Directory -Force

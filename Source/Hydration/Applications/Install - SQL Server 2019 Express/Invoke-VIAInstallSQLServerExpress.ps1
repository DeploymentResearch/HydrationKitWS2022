<#
.Synopsis
    Script for Hydration Kit for Windows Server 2022
.DESCRIPTION
    Script for Hydration Kit for Windows Server 2022
.EXAMPLE
    C:\Setup\Scripts\Invoke-VIAInstallSQLServerExpress.ps1 -Setup "C:\Setup\SQL_2019_Express\SQLEXPR_x64_ENU.exe" -SQLINSTANCENAME "SQLExpress" -SQLINSTANCEDIR "E:\SQLDB"
.NOTES
    Created:	 2021-12-22
    Version:	 1.0

    Author - Johan Arwidmark
    Twitter: @jarwidmark
    Blog   : http://deploymentresearch.com

    Disclaimer:
    This script is provided "AS IS" with no warranties, confers no rights and 
    is not supported by the authors or Deployment Artist.
.LINK
    http://www.deploymentfundamentals.com
#>

[cmdletbinding(SupportsShouldProcess=$True)]
Param (
[Parameter(Mandatory=$false,Position=0)]
  $Setup = ".\Source\SQLEXPR_x64_ENU.exe",

  [Parameter(Mandatory=$false,Position=1)]
  $SQLINSTANCENAME = "SQLExpress",

  [Parameter(Mandatory=$false,Position=2)]
  $SQLINSTANCEDIR = "E:\SQLDB"
)

# Check for elevation
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Oupps, you need to run this script from an elevated PowerShell prompt!`nPlease start the PowerShell prompt as an Administrator and re-run the script."
	Write-Warning "Aborting script..."
    Throw
}

Function Invoke-Exe{
    [CmdletBinding(SupportsShouldProcess=$true)]

    param(
        [parameter(mandatory=$true,position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Executable,

        [parameter(mandatory=$true,position=1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Arguments,

        [parameter(mandatory=$false,position=2)]
        [ValidateNotNullOrEmpty()]
        [int]
        $SuccessfulReturnCode = 0
    )

    Write-Verbose "Running $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru"
    $ReturnFromEXE = Start-Process -FilePath $Executable -ArgumentList $Arguments -NoNewWindow -Wait -Passthru

    Write-Verbose "Returncode is $($ReturnFromEXE.ExitCode)"

    if(!($ReturnFromEXE.ExitCode -eq $SuccessfulReturnCode)) {
        throw "$Executable failed with code $($ReturnFromEXE.ExitCode)"
    }
}

$unattendFile = New-Item "$env:temp\ConfigutionFile.ini" -type File -Force
set-Content $unattendFile "[OPTIONS]"
add-Content $unattendFile "ACTION=Install"
add-Content $unattendFile "ROLE=""AllFeatures_WithDefaults"""
add-Content $unattendFile "ENU=""True"""
add-Content $unattendFile "QUIET=""True"""
add-Content $unattendFile "QUIETSIMPLE=""False"""
add-Content $unattendFile "UpdateEnabled=""False"""
add-Content $unattendFile "FEATURES=""SQLENGINE"""
add-Content $unattendFile "UpdateSource=""MU"""
add-Content $unattendFile "HELP=""False"""
add-Content $unattendFile "INDICATEPROGRESS=""False"""
add-Content $unattendFile "X86=""False"""
add-Content $unattendFile "INSTALLSHAREDDIR=""C:\Program Files\Microsoft SQL Server"""
add-Content $unattendFile "INSTALLSHAREDWOWDIR=""C:\Program Files (x86)\Microsoft SQL Server"""
add-Content $unattendFile "INSTANCENAME=""$SQLINSTANCENAME"""
add-Content $unattendFile "INSTANCEID=""$SQLINSTANCENAME"""
add-Content $unattendFile "SQMREPORTING=""False"""
add-Content $unattendFile "ERRORREPORTING=""False"""
add-Content $unattendFile "INSTANCEDIR=""$SQLINSTANCEDIR"""
add-Content $unattendFile "AGTSVCACCOUNT=""NT AUTHORITY\NETWORK SERVICE"""
add-Content $unattendFile "AGTSVCSTARTUPTYPE=""Disabled"""
add-Content $unattendFile "COMMFABRICPORT=""0"""
add-Content $unattendFile "COMMFABRICNETWORKLEVEL=""0"""
add-Content $unattendFile "COMMFABRICENCRYPTION=""0"""
add-Content $unattendFile "MATRIXCMBRICKCOMMPORT=""0"""
add-Content $unattendFile "SQLSVCSTARTUPTYPE=""Automatic"""
add-Content $unattendFile "FILESTREAMLEVEL=""0"""
add-Content $unattendFile "ENABLERANU=""True"""
add-Content $unattendFile "SQLCOLLATION=""SQL_Latin1_General_CP1_CI_AS"""
add-Content $unattendFile "SQLSVCACCOUNT=""NT AUTHORITY\NETWORK SERVICE"""
add-Content $unattendFile "SQLSYSADMINACCOUNTS=""BUILTIN\Administrators"""
add-Content $unattendFile "ADDCURRENTUSERASSQLADMIN=""True"""
add-Content $unattendFile "TCPENABLED=""1"""
add-Content $unattendFile "NPENABLED=""1"""
add-Content $unattendFile "BROWSERSVCSTARTUPTYPE=""Automatic"""
add-Content $unattendFile "IACCEPTSQLSERVERLICENSETERMS=""True"""

Write-Verbose "Unpack SQL Express 2019"
Invoke-Exe -Executable $Setup -Arguments "/q /x:C:\SQLtmp"
Write-Verbose "Install SQL Express 2019, please wait"
Invoke-Exe -Executable C:\SQLtmp\SETUP.EXE -Arguments "/ConfigurationFile=$unattendFile"

Remove-Item C:\SQLtmp -Recurse -Force


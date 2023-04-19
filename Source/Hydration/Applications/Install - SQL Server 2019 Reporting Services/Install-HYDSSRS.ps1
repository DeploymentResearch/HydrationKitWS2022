<#

************************************************************************************************************************

Created:	2021-11-22
Version:	1.0

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the author or DeploymentArtist.

Author - Johan Arwidmark
    Twitter: @jarwidmark
    Blog   : http://deploymentresearch.com

************************************************************************************************************************

#>



$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$Deployroot = $tsenv.Value("DeployRoot")
$env:PSModulePath = $env:PSModulePath + ";$deployRoot\Tools\Modules"

Import-Module -Name HydrationLogging

Set-HYDLogPath
write-HYDLog -Message "Starting setup... "


# Figure out Source path
If($psISE){
    $SourcePath = Split-Path -parent $psISE.CurrentFile.FullPath
}
else{
    $SourcePath = $PSScriptRoot
}

# Install SQL Server 2019 Reporting Services 
$SetupFile = "$SourcePath\Source\SQLServerReportingServices.exe"
$Arguments = "/IAcceptLicenseTerms /Quiet /Norestart /Edition=Eval /Log $LogPath\SQLServerReportingServiceslog.txt"

# Validation
if (!(Test-Path -path $SetupFile)) {Write-HYDLog "Could not find SQL Server 2019 Reporting Services Setup files, aborting..." -LogLevel 2;Break}

Write-HYDLog "About to run the following command: $SetupFile $Arguments" 
Start-Process -FilePath $SetupFile -ArgumentList $Arguments -NoNewWindow -Wait -Passthru

Write-HYDLog "Starting configuration of SSRS"
#############################################################
# Code to configure SSRS graciously provided 
# by Sven Aelterman (@svenaelterman)
#############################################################
function Get-ConfigSet(){
	return Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v15\Admin" `
		-class MSReportServer_ConfigurationSetting -ComputerName localhost
}

# Allow importing of sqlps module
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force -Scope Process

# Retrieve the current configuration
$configset = Get-ConfigSet

If (! $configset.IsInitialized)
{
	# Get the ReportServer and ReportServerTempDB creation script
	[string]$dbscript = $configset.GenerateDatabaseCreationScript("ReportServer", 1033, $false).Script

	# Import the SQL Server PowerShell module
    Import-Module "C:\Program Files (x86)\Microsoft SQL Server\150\Tools\PowerShell\Modules\sqlps\sqlps.psd1" -DisableNameChecking | Out-Null

	# Establish a connection to the database server (localhost)
	$conn = New-Object Microsoft.SqlServer.Management.Common.ServerConnection -ArgumentList $env:ComputerName
	$conn.ApplicationName = "SSRS Configuration Script"
	$conn.StatementTimeout = 0
	$conn.Connect()
	$smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $conn

	# Create the ReportServer and ReportServerTempDB databases
	$db = $smo.Databases["master"]
	$db.ExecuteNonQuery($dbscript)

	# Set permissions for the databases
	$dbscript = $configset.GenerateDatabaseRightsScript($configset.WindowsServiceIdentityConfigured, "ReportServer", $false, $true).Script
	$db.ExecuteNonQuery($dbscript)

	# Set the database connection info
	$configset.SetDatabaseConnection("(local)", "ReportServer", 2, "", "")

	$configset.SetVirtualDirectory("ReportServerWebService", "ReportServer", 1033)
	$configset.ReserveURL("ReportServerWebService", "http://+:80", 1033)

	# For SSRS 2016-2017-2019 only, older versions have a different name
	$configset.SetVirtualDirectory("ReportServerWebApp", "Reports", 1033)
	$configset.ReserveURL("ReportServerWebApp", "http://+:80", 1033)

	$configset.InitializeReportServer($configset.InstallationID)

	# Re-start services?
	$configset.SetServiceState($false, $false, $false)
	Restart-Service $configset.ServiceName
	$configset.SetServiceState($true, $true, $true)

	# Update the current configuration
	$configset = Get-ConfigSet

	# Output to screen
	$configset.IsReportManagerEnabled
	$configset.IsInitialized
	$configset.IsWebServiceEnabled
	$configset.IsWindowsServiceEnabled
	$configset.ListReportServersInDatabase()
	$configset.ListReservedUrls();

	$inst = Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v15" `
		-class MSReportServer_Instance -ComputerName localhost

	$inst.GetReportServerUrls()
}


Write-HYDLog "SSRS Setup completed..." 

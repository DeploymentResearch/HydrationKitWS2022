<#

************************************************************************************************************************

Created:	2021-12-28
Version:	1.0

Disclaimer:
This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the author or DeploymentArtist.

Author - Johan Arwidmark
    Twitter: @jarwidmark
    Blog   : http://deploymentresearch.com
Author - Andrew Johnson
    Twitter: @andrewjnet
    Blog   : http://andrewj.net

************************************************************************************************************************

#>


$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$Deployroot = $tsenv.Value("DeployRoot")
$env:PSModulePath = $env:PSModulePath + ";$deployRoot\Tools\Modules"

Import-Module -Name HydrationLogging

# Figure out Source path
If($psISE){
    $SourcePath = Split-Path -parent $psISE.CurrentFile.FullPath
}
else{
    $SourcePath = $PSScriptRoot
}

#Load config file containing install parameters
. "$($sourcePath)\HYDCMRSPConfig.ps1"

Set-HYDLogPath
Write-HYDLog -Message "Starting setup... "

Import-Module "E:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1" -DisableNameChecking | Out-Null
$SiteInfo = Get-CIMInstance -Namespace "root\SMS" -ClassName "SMS_ProviderLocation"
New-PSDrive -Name "$($SiteInfo.SiteCode)" -psprovider CMsite -root "$($SiteInfo.Machine)"
Set-Location "$($SiteInfo.SiteCode):\"

#Create Reporting Services Point Credentials
Write-HYDLog -Message "Creating Reporting Services Point Account in ConfigMgr: $SSRSUsername"

try {
    $Secure = ConvertTo-SecureString -String $SSRSPassword -AsPlainText -Force
    New-CMAccount -Name $SSRSUsername -Password $Secure -SiteCode $SiteInfo.SiteCode
}
catch {
    Write-HYDLog -message "$PSItem.Exception.Message" 
}


$RSPInstallParams = @{
    SiteCode             = $SiteInfo.SiteCode
    SiteSystemServerName = $SiteInfo.Machine
    Username             = $SSRSUsername 
    ReportServerInstance = $SSRSInstanceName
}

Write-HYDLog -Message "Starting configuration of ConfigMgr Reporting Services Point"
try{
    Add-CMReportingServicePoint @RSPInstallParams
}
catch {
    Write-HYDLog -message "$PSItem.Exception.Message" 
    Write-HYDLog -Message "$RSPInstallParams"
}


#Install Validation
$ReportingServicesPoint = Get-CMReportingServicePoint

if (!$ReportingServicesPoint) {
    Write-HYDLog -Message "ConfigMgr Reporting Services Point configuration failed! aborting..." -LogLevel 2; Break
}
else {
    Write-HYDLog -Message "ConfigMgr Reporting Services Point configuration completed successfully."
}
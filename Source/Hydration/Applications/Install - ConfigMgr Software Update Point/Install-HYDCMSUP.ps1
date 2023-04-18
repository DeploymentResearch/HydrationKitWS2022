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

Set-HYDLogPath
Write-HYDLog -Message "Starting setup... "

Write-HYDLog -Message "Adding ConfigMgr Software Update Point role"

#Import-Module "E:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1" -DisableNameChecking | Out-Null
#$SiteInfo = Get-PSDrive -PSProvider CMSite
#Set-Location "$($SiteInfo.Name):\"
Import-Module "E:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1" -DisableNameChecking | Out-Null
$SiteInfo = Get-CIMInstance -Namespace "root\SMS" -ClassName "SMS_ProviderLocation"
New-PSDrive -Name "$($SiteInfo.SiteCode)" -psprovider CMsite -root "$($SiteInfo.Machine)"
Set-Location "$($SiteInfo.SiteCode):\"

try {
    Add-CMSoftwareUpdatePoint -SiteSystemServerName $SiteInfo.Machine -SiteCode $SiteInfo.SiteCode
}
catch {
    Write-HYDLog -message "$PSItem.Exception.Message" 
}


$SUPSchedule = New-CMSchedule  -Start 19:00:00 -RecurInterval Days -RecurCount 1

$SUPInstallParams = @{
    SiteCode                    = $SiteInfo.SiteCode
    EnableCallWsusCleanupWizard = $true
    Schedule                    = $SUPSchedule

}

Write-HYDLog -Message "Configuring ConfigMgr Software Update Point"

try {
    Set-CMSoftwareUpdatePointComponent @SUPInstallParams
}

catch {
    Write-HYDLog -message "$PSItem.Exception.Message" 
    Write-HYDLog -Message "$SUPInstallParams"
}

Write-HYDLog -Message "Starting SUP Sync. This initial sync will take some time."

Sync-CMSoftwareUpdate -FullSync $true

$SoftwareUpdatePoint = Get-CMSoftwareUpdatePoint

if (!$SoftwareUpdatePoint) {
    Write-HYDLog -Message "ConfigMgr Software Update Point configuration failed! aborting..." -LogLevel 2; Break
}
else {
    Write-HYDLog -Message "ConfigMgr Software Update Point configuration completed successfully."
}
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

Write-HYDLog -Message "Creating NO_SMS_ON_DRIVE.SMS"

New-Item C:\NO_SMS_ON_DRIVE.SMS -ItemType file -Force

if (!(Test-Path -Path C:\NO_SMS_ON_DRIVE.SMS)) {
    Write-HYDLog -Message "Failed to create C:\NO_SMS_ON_DRIVE.SMS. aborting..." -LogLevel 2; Break
}
else{
    Write-HYDLog -Message "C:\NO_SMS_ON_DRIVE.SMS created successfully."
}
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
. "$($sourcePath)\HYDWSUSConfig.ps1"

Set-HYDLogPath
Write-HYDLog -Message "Starting setup... "
Write-HYDLog -Message "Installing WSUS features"

Install-WindowsFeature -Name 'UpdateServices-DB','UpdateServices-Services','UpdateServices-RSAT','UpdateServices-API','UpdateServices-UI'

Write-HYDLog -Message "Creating Wsus Content directory at $wsusContentPath"

New-Item -Path $wsusContentPath -ItemType Directory

Write-HYDLog -Message "Configuring WSUS"


$WsusUtilFile = "C:\Program Files\Update Services\Tools\WsusUtil.exe"
$Arguments = "postinstall SQL_INSTANCE_NAME=$sqlInstanceName CONTENT_DIR=$wsusContentPath"
#Wsus Post Install config
#Write-HYDLog "About to run the following command: $SetupFile $Arguments" 
Start-Process -FilePath $WsusUtilFile -ArgumentList $Arguments -NoNewWindow -Wait -Passthru


$wsusServer = Get-WsusServer

if(!$wsusServer){
    Write-HYDLog "WSUS configuration failed! aborting..." -LogLevel 2; Break
}
else{
    Write-HYDLog -Message "WSUS configuration completed successfully."
}
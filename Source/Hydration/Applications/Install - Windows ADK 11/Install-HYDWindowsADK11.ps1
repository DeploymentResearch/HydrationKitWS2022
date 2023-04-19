<#

************************************************************************************************************************

Created:	2021-10-07
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

$SetupFile = "$PSScriptRoot\Source\adksetup.exe"
$Arguments = "/Features OptionId.DeploymentTools OptionId.ImagingAndConfigurationDesigner OptionId.ICDConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"

# Validation
if (!(Test-Path -path $SetupFile)) {Write-HYDLog "Could not find Windows ADK 10 Setup files, aborting..." -LogLevel 2;Break}

# Install Windows ADK 11
Write-HYDLog "About to run the following command: $SetupFile $Arguments" 
Start-Process -FilePath $SetupFile -ArgumentList $Arguments -NoNewWindow -Wait -Passthru

Write-HYDLog "Setup completed..." 



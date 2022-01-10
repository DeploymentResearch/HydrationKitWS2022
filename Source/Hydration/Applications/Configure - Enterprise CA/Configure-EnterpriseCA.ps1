<#
Solution: Hydration
Purpose: Used to create the ViaMonstra Root CA
Version: 1.2 - January 10, 2013

This script is provided "AS IS" with no warranties, confers no rights and 
is not supported by the authors or Deployment Artist. 

Author - Johan Arwidmark
    Twitter: @jarwidmark
    Blog   : http://deploymentresearch.com
#>


# Determine where to do the logging 
$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$logPath = $tsenv.Value("LogPath") 
$logFile = "$logPath\$($myInvocation.MyCommand).log" 

# Start the logging 
Start-Transcript $logFile 
Write-Host "Logging to $logFile" 

# Configure Enterprise CA
Install-AdcsCertificationAuthority `    –CAType EnterpriseRootCA `    –CACommonName "ViaMonstraRootCA" `    –KeyLength 2048 `    –HashAlgorithm SHA1 `    –CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `    -ValidityPeriod Years `    -ValidityPeriodUnits 5 `
    -Force

# Stop logging 
Stop-Transcript


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

Import-Module -Name HydrationLogging -Verbose

Set-HYDLogPath
write-HYDLog -Message "Starting configuration... "

# Selecting the first network adapter
$Interface = Get-NetAdapter -Name *Ethernet* | Select -First 1
$ifIndex = Get-NetIPAddress -InterfaceIndex $Interface.ifIndex -AddressFamily IPv4
$IPAddress = $ifIndex.IPv4Address

write-HYDLog -Message "The DHCP Server have the IP address: $IPAddress"

# Authorize DHCP SERVER
Add-DhcpServerInDC -DnsName $env:COMPUTERNAME -IPAddress $IPAddress
write-HYDLog -Message "The Server with the name $env:COMPUTERNAME is Authorized in Active Directory"

# Notify Server Manager that AD and DHCP configuration are completed
write-HYDLog -Message "Removing AD and DHCP Flag in Server Manager"
set-ItemProperty HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -name ConfigurationState -Value 0x000000002
set-ItemProperty HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\10 -name ConfigurationStatus -Value 0x000000002


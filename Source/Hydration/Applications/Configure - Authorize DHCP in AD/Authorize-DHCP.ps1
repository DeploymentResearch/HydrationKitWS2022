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


Function Set-HYDLogPath{

    try
    {
        # Check for running Task Sequence, and use it's log path
        $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
        $global:LogPath = $tsenv.Value("LogPath")
        If($psISE){
            $global:LogFile = "$($psISE.CurrentFile.DisplayName.Split(".")[0]).log"
        }
        else{
            $global:LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
        }
		Start-HYDLog -FilePath $($LogPath + "\" + $LogFile)
    }
    catch
    {
        # Assume no task sequence is running, set log path to C:\Windows\Temp   
        $global:LogPath = "C:\Windows\Temp"
        If($psISE){
            $global:LogFile = "$($psISE.CurrentFile.DisplayName.Split(".")[0]).log"
        }
        else{
            $global:LogFile = "$($($script:MyInvocation.MyCommand.Name).Substring(0,$($script:MyInvocation.MyCommand.Name).Length-4)).log"		
        }
		Start-HYDLog -FilePath $($LogPath + "\" + $LogFile)

    }
}

Function Start-HYDLog{
[CmdletBinding()]
    param (
	[string]$FilePath
    )
	
    try
    {
        if (!(Test-Path $FilePath))
	{
	    ## Create the log file
	    New-Item $FilePath -Type File | Out-Null
	}
		
	## Set the global variable to be used as the FilePath for all subsequent Write-Log
	## calls in this session
	$global:ScriptLogFilePath = $FilePath
    }
    catch
    {
        Write-Error $_.Exception.Message
    }
}

Function Write-HYDLog{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [Parameter()]
    [ValidateSet(1, 2, 3)]
	[string]$LogLevel=1,
	[Parameter(Mandatory = $false)]
    [bool]$writetoscreen = $true   
   )
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'
    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), "$($LogFile.Split(".")[0])", $LogLevel
    $Line = $Line -f $LineFormat
    Add-Content -Value $Line -Path $ScriptLogFilePath
    if($writetoscreen){
        switch ($LogLevel)
        {
            '1'{
                Write-Verbose -Message $Message
                }
            '2'{
                Write-Warning -Message $Message
                }
            '3'{
                Write-Error -Message $Message
                }
            Default {
            }
        }
    }
    if($writetolistbox -eq $true){
        $result1.Items.Add("$Message")
    }
}

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


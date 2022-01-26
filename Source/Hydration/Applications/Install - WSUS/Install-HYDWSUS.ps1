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
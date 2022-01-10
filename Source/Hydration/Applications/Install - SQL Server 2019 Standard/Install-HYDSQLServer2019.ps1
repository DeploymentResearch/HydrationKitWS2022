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
write-HYDLog -Message "Starting setup... "

# Figure out Source path
If($psISE){
    $SourcePath = Split-Path -parent $psISE.CurrentFile.FullPath
}
else{
    $SourcePath = $PSScriptRoot
}

$SetupFile = "$SourcePath\Source\Setup.exe"
$ConfigurationFile = "$SourcePath\ConfigurationFile.ini"

# If SQLSYSADMINACCOUNTS is specified in the CM01.INI file, copy configuration file to a temporary location so it can be updated
$ConfigurationFile = "$SourcePath\ConfigurationFile.ini"
$SQLSYSADMINACCOUNTS = $tsenv.Value("SQLSYSADMINACCOUNTS")
If ($SQLSYSADMINACCOUNTS -ne ""){
    $TempFolder = "C:\Windows\Temp"
    Copy-Item -Path $ConfigurationFile -Destination $TempFolder
    $FinalConfigurationFile = "$TempFolder\ConfigurationFile.ini"
    $ConfigurationFileData = Get-Content $ConfigurationFileData 
    $OriginalSQLSYSADMINACCOUNTS = "SQLSYSADMINACCOUNTS=`"VIAMONSTRA\Administrator`" `"BUILTIN\Administrators`""
    $UpdatedSQLSYSADMINACCOUNTS = "SQLSYSADMINACCOUNTS=`"$SQLSYSADMINACCOUNTS`" `"BUILTIN\Administrators`"" # always add local administrators
    $ConfigurationFileData | ForEach-Object { $_.replace("$OriginalSQLSYSADMINACCOUNTS","$UpdatedSQLSYSADMINACCOUNTS") } | Set-Content $ConfigurationFileData
}
Else{
    $FinalConfigurationFile = $ConfigurationFile
}

# Validation
if (!(Test-Path -path $SetupFile)) {Write-HYDLog "Could not find SQL Server Setup files, aborting..." -LogLevel 2;Break}
if (!(Test-Path -path $FinalConfigurationFile)) {Write-HYDLog "Could not find SQL Server configuration files, aborting..." -LogLevel 2;Break}

# Install SQL Server
$Arguments = "/configurationfile=""$FinalConfigurationFile"""
Write-HYDLog "About to run the following command: $SetupFile $Arguments" 
Start-Process -FilePath $SetupFile -ArgumentList $Arguments -NoNewWindow -Wait -Passthru

Write-HYDLog "Setup completed..." 


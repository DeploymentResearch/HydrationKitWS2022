<#

************************************************************************************************************************

Created:	2023-1-28
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
If ($psISE) {
    $SourcePath = Split-Path -parent $psISE.CurrentFile.FullPath
}
else {
    $SourcePath = $PSScriptRoot
}

Set-HYDLogPath
Write-HYDLog -Message "Starting setup... "
Write-HYDLog -Message "Importing List of users"
$NewUsers = Import-Csv -Path "$($sourcePath)\ADUserList.csv"
Write-HYDLog -Message "Importing List of new OUs"
$NewOUs = Import-CSV -Path "$($sourcePath)\ADOUList.csv"
Write-HYDLog -Message "Creating Hydration OUs"

foreach ($OU in $NewOUs) {
    New-ADOrganizationalUnit -Name $OU.Name -Path $OU.Path
    try {
        $Filter = "name -eq '$($OU.Name)'"
        Get-ADOrganizationalUnit -Filter $Filter | Select-Object name,distinguishedname
        
        Write-HYDLog "OU $($OU.Name) created"
    }
    catch {
        Write-HYDLog "Failed to create OU $($OU.Name)"
    }
}

foreach ($User in $NewUsers) {
    $SecurePassword = ConvertTo-SecureString $User.Password -AsPlainText -Force
    New-ADUser -Name $User.SAMAccountName -AccountPassword $SecurePassword -Description $User.Description -Path $User.Path -Enabled $true -PasswordNeverExpires ([System.Convert]::ToBoolean($User."Password Expires"))
    try {
        Get-ADUser -Identity $User.SAMAccountName
        Write-HYDLog "User $($User.SAMAccountName) created"
    }
    catch {
        Write-HYDLog "Failed to create user $($User.SAMAccountName)"
    }
}
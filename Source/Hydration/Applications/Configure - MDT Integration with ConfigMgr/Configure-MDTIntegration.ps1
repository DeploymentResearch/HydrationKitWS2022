$TSEnv = New-Object -COMObject Microsoft.SMS.TSEnvironment 
$Deployroot = $tsenv.Value("DeployRoot")
$env:PSModulePath = $env:PSModulePath + ";$deployRoot\Tools\Modules"

Import-Module -Name HydrationLogging

# Check for elevation
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "Oupps, you need to run this script from an elevated PowerShell prompt!`nPlease start the PowerShell prompt as an Administrator and re-run the script."
	Write-Warning "Aborting script..."
    Throw
}

# Integrate MDT with ConfigMgr
$SiteServer = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
$SiteCode = (Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS" -Class "SMS_ProviderLocation").SiteCode
$MDTInstallDir = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Deployment 4' -Name Install_Dir).Install_Dir

# Getting CM console installation folder via registry, because the $env:SMS_ADMIN_UI_PATH method requires console to be started once
$CMConsoleInstallDir = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\SMS\Setup' -Name 'UI Installation Directory').'UI Installation Directory'
$MOF  = "$CMConsoleInstallDir\Bin\Microsoft.BDD.CM12Actions.mof"

Copy-Item "$MDTInstallDir\Bin\Microsoft.BDD.CM12Actions.dll" "$CMConsoleInstallDir\Bin\Microsoft.BDD.CM12Actions.dll"  
Copy-Item "$MDTInstallDir\Bin\Microsoft.BDD.Workbench.dll" "$CMConsoleInstallDir\Bin\Microsoft.BDD.Workbench.dll"  
Copy-Item "$MDTInstallDir\Bin\Microsoft.BDD.ConfigManager.dll" "$CMConsoleInstallDir\Bin\Microsoft.BDD.ConfigManager.dll"  
Copy-Item "$MDTInstallDir\Bin\Microsoft.BDD.CM12Wizards.dll" "$CMConsoleInstallDir\Bin\Microsoft.BDD.CM12Wizards.dll"  
Copy-Item "$MDTInstallDir\Bin\Microsoft.BDD.PSSnapIn.dll" "$CMConsoleInstallDir\Bin\Microsoft.BDD.PSSnapIn.dll"  
Copy-Item "$MDTInstallDir\Bin\Microsoft.BDD.Core.dll" "$CMConsoleInstallDir\Bin\Microsoft.BDD.Core.dll"  
Copy-Item "$MDTInstallDir\SCCM\Microsoft.BDD.CM12Actions.mof" $MOF  
Copy-Item "$MDTInstallDir\Templates\CM12Extensions\*" "$CMConsoleInstallDir\XmlStorage\Extensions\" -Force -Recurse  
(Get-Content $MOF).Replace('%SMSSERVER%', $SiteServer).Replace('%SMSSITECODE%', $SiteCode) | Set-Content $MOF | Out-Null
& "C:\Windows\System32\wbem\mofcomp.exe" "$CMConsoleInstallDir\Bin\Microsoft.BDD.CM12Actions.mof" | Out-Null
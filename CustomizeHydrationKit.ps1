<#
.Synopsis
    Script to Customize Johan Arwidmarks Hydration kit for ConfigMgr
.DESCRIPTION
    Created: 2017-04-31
    Updated: 2023-07-31
    Version: 2.0
        - Rewritten to be run on the DeploymentShare
        - Updated for WS2022 Hydration Kit
        - Creates a backup of all changed files (.org) and can be rerun if wanted. 
          NOTE!! When rerun it will restore the original file before applying changes again and any manual changes on affected files will be lost!!
    Changelog:
        - Edited by Andrew Johnson (@andrewjnet) to include:
        - Client sequence customization
        - Active Directory user/OU customization        

    Author : Matt Benninge
    Twitter: @matbg

    Disclaimer: This script is provided "AS IS" with no warranties, confers no rights and 
    is not supported by the author or DeploymentArtist..

    This version is only tested with the following Hydration Kit:
    https://github.com/DeploymentResearch/HydrationKitWS2022

    This should be used after the deployementshare has been created and on the deploymentshare created.

    Uncomment any value that you do not whish to be customized and that value will be skipped.

.EXAMPLE
    NA
#>
#Requires -RunAsAdministrator 
#Requires -Version 3

#Set the path to the created deploymentshare
$HydrationSource = "D:\CMLab"

#Change Domain and OU structure, these values will be changed in all files where applicable
$NewDomainName = "corp.mydomain.org" #Default = corp.viamonstra.com
$NewDomainRoot = "dc=corp,dc=mydomain,dc=org"
$NewMachineOU = "ou=Servers,ou=MyDomain,dc=corp,dc=mydomain,dc=org" #Default = ou=Servers,ou=ViaMonstra,dc=corp,dc=viamonstra,dc=com
$NewOrgName = "MyDomain" #Default = ViaMonstra or VIAMONSTRA
$NewTimeZoneName = "W. Europe Standard Time" #Default = Pacific Standard Time

#Change Admin Passwd
# $NewPasswd = "newpass" #Default = P@ssw0rd

#General IP settings, used in all files where applicable, default for all these are on the 192.168.25.x net
$NewOSDAdapter0DNSServerList = "10.10.5.200" #Also used for DC01 ip-adress
$newOSDAdapter0Gateways= "10.10.5.1"
$NewOSDAdapter0SubnetMask= "255.255.255.0"
$NewADSubNet = "10.10.5.0"

#DC01 - set DHCP scope on DC01
$NewDHCPScopes0StartIP="10.10.5.100"
$NewDHCPScopes0EndIP="10.10.5.199"

#Set IP-adress for CM01
$NewCM01OSDAdapter0IPAddressList= "10.10.5.214"

#Set IP-adress for DP01
$NewDP01OSDAdapter0IPAddressList= "10.10.5.245"

#Set IP-adress for MDT01
$NewMDT01OSDAdapter0IPAddressList= "10.10.5.210"

#Set IP-adress for FS01
$NewFS01OSDAdapter0IPAddressList= "10.10.5.213"

#Set IP-adress for PC0001
$NewPC0001OSDAdapter0IPAddressList= "10.10.5.11"

#Set IP-adress for PC0002
$NewPC0002OSDAdapter0IPAddressList= "10.10.5.12"

#Set IP-adress for PC0003
$NewPC0003OSDAdapter0IPAddressList= "10.10.5.13"

#Set IP-adress for PC0004
$NewPC0004OSDAdapter0IPAddressList= "10.10.5.14"


#------------------ Do Not change below this line-----------------#
$ResultList = $null
$ResultList = [System.Collections.Generic.List[object]]::new()
Function Update-HKContent {
    param(
        [string]$fileName,
        [string]$orgValue,
        [string]$newValue,
        [switch]$ToUpper
    )

    $Properties = [ordered]@{
        OrgValue = $orgValue
        NewValue = $newValue
        Filename = $fileName
    }

    if(test-path $fileName) {
        if (test-path "$fileName.org") {
            Write-Debug "$fileName already has an org backup"
            $content = Get-Content "$fileName"
        } else {
            Write-Debug "Creating a copy of original file in $filename.org"
            Copy-Item $fileName "$fileName.org"
            $content = Get-Content "$fileName"
        }
        if($ToUpper) {
            $content.Replace($orgValue,$newValue.ToUpper()) | Set-Content $fileName
            $Properties.NewValue = $newValue.ToUpper()
        } else {
            $content.Replace($orgValue,$newValue) | Set-Content $fileName

        }
        $ResultList.Add((New-Object PsObject -Property $Properties))

    } else {
        Write-Warning "$filename not found, skipping!"
    }

}

function Update-HKContentRecurse {
    param(
        $SourceFiles,
        [string]$pattern,
        [string]$newValue,
        [switch]$ToUpper
    )

    $foundFiles = $SourceFiles | Select-String -pattern $pattern | Group-Object path | Select-Object name
    foreach($file in $foundFiles)
    {
            Update-HKContent -fileName $file.Name -orgValue $pattern -newValue $newValue -ToUpper:$ToUpper
    }
}

#restore original files if previously edited
$orgFiles = Get-ChildItem -recurse -Path $HydrationSource\ISO -Include ("*.org")
$orgFiles += Get-ChildItem -recurse -Path $HydrationSource\DS -Include ("*.org")
if($orgFiles)
{
    foreach($orgFile in $orgFiles)
    {
        $fileName = $orgFile.FullName -replace "$([System.IO.Path]::GetFileNameWithoutExtension($orgFile.FullName)).org","$([System.IO.Path]::GetFileNameWithoutExtension($orgFile.FullName))"
        Copy-Item $orgFile.FullName $fileName -force
    }
    
}

#Update CreateHydrationDeploymentShare.ps1
#If($NewMDTPath){(Update-HKContent -fileName $HydrationSource\Source\CreateHydrationDeploymentShare.ps1 -orgValue 'C:' -newValue $NewMDTPath) | Set-Content $HydrationSource\Source\CreateHydrationDeploymentShare.ps1}

#Update Customsettings.ini
If($NewTimeZoneName){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\CustomSettings.ini -orgValue 'Pacific Standard Time' -newValue $NewTimeZoneName}

#Update Customsettings_CM01.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_CM01.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_CM01.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewCM01OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_CM01.ini -orgValue '192.168.25.214' -newValue $NewCM01OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_CM01.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Customsettings_DC01.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DC01.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DC01.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DC01.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }
If($NewADSubNet){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DC01.ini -orgValue '192.168.25.0' -newValue $NewADSubNet }
If($NewDHCPScopes0StartIP){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DC01.ini -orgValue '192.168.25.100' -newValue $NewDHCPScopes0StartIP }
If($NewDHCPScopes0EndIP){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DC01.ini -orgValue '192.168.25.199' -newValue $NewDHCPScopes0EndIP }


#Update Customsettings_MDT01.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_MDT01.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_MDT01.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewMDT01OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_MDT01.ini -orgValue '192.168.25.210' -newValue $NewMDT01OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_MDT01.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Customsettings_DP01.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DP01.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DP01.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewDP01OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DP01.ini -orgValue '192.168.25.245' -newValue $NewDP01OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_DP01.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Customsettings_FS01.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_FS01.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_FS01.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewFS01OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_FS01.ini -orgValue '192.168.25.213' -newValue $NewFS01OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_FS01.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Customsettings_PC0001.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0001.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0001.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewPC0001OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0001.ini -orgValue '192.168.25.11' -newValue $NewPC0001OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0001.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Customsettings_PC0002.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0002.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0002.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewPC0002OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0002.ini -orgValue '192.168.25.12' -newValue $NewPC0002OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0002.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Customsettings_PC0003.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0003.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0003.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewPC0003OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0003.ini -orgValue '192.168.25.13' -newValue $NewPC0003OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0003.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Customsettings_PC0004.ini
If($NewOSDAdapter0DNSServerList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0004.ini -orgValue '192.168.25.200' -newValue $NewOSDAdapter0DNSServerList }
If($newOSDAdapter0Gateways){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0004.ini -orgValue '192.168.25.1' -newValue $newOSDAdapter0Gateways }
If($NewPC0004OSDAdapter0IPAddressList){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0004.ini -orgValue '192.168.25.14' -newValue $NewPC0004OSDAdapter0IPAddressList }
If($NewOSDAdapter0SubnetMask){Update-HKContent -fileName $HydrationSource\ISO\Content\Deploy\Control\Customsettings_PC0004.ini -orgValue '255.255.255.0' -newValue $NewOSDAdapter0SubnetMask }

#Update Scripts
If($NewADSubNet){Update-HKContent -fileName "$($HydrationSource)\ISO\Content\Deploy\Applications\Configure - Create AD Subnets\Configure-CreateADSubnets.ps1" -orgValue '192.168.25.0' -newValue $NewADSubNet }

$sourceFiles = Get-ChildItem -recurse -Path "$HydrationSource\ISO" -Include ("*.ini","*.ps1","*.vbs","*.wsf","*.xml","*.csv")
$sourceFiles += Get-ChildItem -recurse -Path "$HydrationSource\DS" -Include ("*.ini","*.ps1","*.vbs","*.wsf","*.xml","*.csv")
# $sourceFiles | Select-String -Pattern 'VIAMONSTRA'

#Update Domain Name
If($NewMachineOU) { Update-HKContentRecurse -SourceFiles $sourceFiles -pattern 'ou=Servers,ou=ViaMonstra,dc=corp,dc=viamonstra,dc=com' -NewValue $NewMachineOU }

#Update Domain Name
If($NewDomainName) { Update-HKContentRecurse -SourceFiles $sourceFiles -pattern 'corp.viamonstra.com' -NewValue $NewDomainName }

#Update Domain Root
If($NewDomainRoot) { Update-HKContentRecurse -SourceFiles $sourceFiles -pattern 'dc=corp,dc=viamonstra,dc=com' -NewValue $NewDomainRoot }
If($NewDomainRoot) { Update-HKContentRecurse -SourceFiles $sourceFiles -pattern 'DC=corp,DC=viamonstra,DC=com' -NewValue $NewDomainRoot }

#Update ORGName
If($NewOrgName) { 
    Update-HKContentRecurse -SourceFiles $sourceFiles -pattern 'ViaMonstra' -NewValue $NewOrgName
    Update-HKContentRecurse -SourceFiles $sourceFiles -pattern 'VIAMONSTRA' -NewValue $NewOrgName -ToUpper
}

#Update password
If($NewPasswd) {  Update-HKContentRecurse -SourceFiles $sourceFiles -pattern 'P@ssw0rd' -NewValue $NewPasswd }

Write-Host "The following changes have been done:"

$ResultList | Sort-Object -Property FileName |Format-Table

Write-host -ForegroundColor Yellow "Update your boot ISO MEDIA001 for the changes to take effect!"
<#
    .SYNOPSIS
        Sample script for Hydration Kit

    .DESCRIPTION
        Created: 2019-10-13
        Version: 1.0

        Author : Johan Arwidmark
        Twitter: @jarwidmark
        Blog   : http://deploymentresearch.com

        Disclaimer: This script is provided "AS IS" with no warranties, confers no rights and 
        is not supported by the author or DeploymentArtist..

    .EXAMPLE
        NA

    .PARAMETER VMLocation
    Specify the location for the VMs.

    .PARAMETER ISO
    Specify the Hydration Kit ISO path.

    .PARAMETER VMNetwork
    Specify the Hyper-V Virtual Network.

    .PARAMETER SelectVMs
    Specify the VMs that should be created. If this parameter is not specified, all server VMs are created. (DC01, CM01, MDT01, DP01, FS01)

#>

# Requires the script to be run under an administrative account context.
#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [parameter(Mandatory=$true, HelpMessage="Specify the location for the VMs.")]
    [ValidateNotNullOrEmpty()] 
    [string]$VMLocation, 
    [parameter(Mandatory=$true, HelpMessage="Specify the Hydration Kit ISO path.")]
    [ValidateNotNullOrEmpty()]
    [string]$ISO,
    [parameter(Mandatory=$true, HelpMessage="Specify the Hyper-V Virtual Network.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMNetwork,
    [parameter(Mandatory = $false, HelpMessage = "Specify the VMs to be created (DC, CM, MDT, DP, FS, Clients). All Server VMs are created by default.")]
    [ValidateNotNullOrEmpty()]
    $SelectVMs = @('DC', 'CM', 'MDT', 'DP', 'FS', 'Clients')
)

# Below are details for each VM
$VMSettings = @()
switch ($SelectVMs) {
    'CM' {
        $VMSettings += [pscustomobject]@{ VMName = "CM01"; VMMemory = 16384MB; VMDiskSize = 300GB; VMCPUCount = 4 }
    }
    'DC' {
        $VMSettings += [pscustomobject]@{ VMName = "DC01"; VMMemory = 2048MB; VMDiskSize = 100GB; VMCPUCount = 2 }
    }
    'DP' {
        $VMSettings += [pscustomobject]@{ VMName = "DP01"; VMMemory = 4096MB; VMDiskSize = 300GB; VMCPUCount = 2 }
    }
    'FS' {
        $VMSettings += [pscustomobject]@{ VMName = "FS01"; VMMemory = 2048MB; VMDiskSize = 300GB; VMCPUCount = 2 }
    }
    'MDT' {
        $VMSettings += [pscustomobject]@{ VMName = "MDT01"; VMMemory = 4096MB; VMDiskSize = 300GB; VMCPUCount = 2 }
    }
    'Clients' {
        $VMSettings += [pscustomobject]@{ VMName = "PC0001"; VMMemory = 4096MB; VMDiskSize = 60GB; VMCPUCount = 2 }
        $VMSettings += [pscustomobject]@{ VMName = "PC0002"; VMMemory = 4096MB; VMDiskSize = 60GB; VMCPUCount = 2 }
        $VMSettings += [pscustomobject]@{ VMName = "PC0003"; VMMemory = 4096MB; VMDiskSize = 60GB; VMCPUCount = 2 }
        $VMSettings += [pscustomobject]@{ VMName = "PC0004"; VMMemory = 4096MB; VMDiskSize = 60GB; VMCPUCount = 2 }
    }
}

# Verify that the Hydration Kit ISO path exist
if (!(Test-Path -Path "$ISO")) {
    Write-Warning "Hydration Kit ISO not found in location $ISO, aborting script..."
    Break
}

# Check for Hyper-V Virtual Machine Management Service
$Service = Get-Service -Name "Hyper-V Virtual Machine Management"
if ($Service.Status -ne "Running"){
    Write-Warning "Hyper-V Virtual Machine Management service not started, aborting script..."
    Break
}

# Check for  Hyper-V Switch
$VMSwitchNameCheck = Get-VMSwitch | Where-Object -Property Name -EQ $VMNetwork
if (!($VMSwitchNameCheck.Name -eq $VMNetwork)){
    Write-Warning "The $VMNetwork Hyper-V Virtual Switch does not exist. aborting script..."
    Break
}

Write-Output "Validation steps completed, starting to create the Hydration Kit VMs"

# Create the VMs
foreach($row in $VMSettings){
    $VMName = $row.VMName
    $VMMemory = $row.VMMemory
    $VMDiskSize = $row.VMDiskSize
    $VMCPUCount = $row.VMCPUCount

    Write-Output "Creating VM $VMName in $VMLocation"
    New-VM -Name $VMName -Generation 2 -BootDevice CD -MemoryStartupBytes $VMMemory -SwitchName $VMNetwork -Path $VMLocation -NoVHD | Out-Null
    New-VHD -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" -SizeBytes $VMDiskSize | Out-Null
    Add-VMHardDiskDrive -VMName $VMName -Path "$VMLocation\$VMName\Virtual Hard Disks\$VMName-Disk1.vhdx" | Out-Null
    Set-VMProcessor -VMName $VMName -Count $VMCPUCount | Out-Null
    Set-VMDvdDrive -VMName $VMName -Path $ISO | Out-Null
}

Write-Output "Hydration Kit VMs created"

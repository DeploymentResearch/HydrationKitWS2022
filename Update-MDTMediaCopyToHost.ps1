#If you need to copy the media from your Deployment Share, run this optional script locally on the Deployment Share server to update MDT Media and copy it to another host
$DeploymentShareName = "CMLab"
$DSRootPath = "D:\CMLab"
$HostPath = "\\HyperV01\c$\ISO"
$MediaFilename = "CMLab.iso"

Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
if (!(Get-PSDrive | Where-Object name -eq $DeploymentShareName)) {
    New-PSDrive -name $DeploymentShareName -PSProvider MDTProvider -root "$DSRootPath\DS" 
}
Update-MDTMedia -Path "$($DeploymentShareName):\MEDIA\MEDIA001"
robocopy "$DSRootPath\ISO" $HostPath $MediaFilename  /MT:32 /v /J /NOOFFLOAD
#param([string] $DeploymentId = "ibu-devo-911",
#	  [string] $ResourceGroupName = "ibu-devo-911",
#	  [string] $AzureSubscriptionId = "SUBSCRIPTION-ID",
#	  [string] $ArmTemplateUrl = "NO-TEMPLATE-URL",
#	# These parameter should be passed by Secure Files
#	  [string] $LicensePath = "NO-LICENSE-FILE",
#	  [string] $Location = "westeurope",
#	  [string] $CertificateFilePath = "NO-CERTIFICATE-FILE",
#	  [string] $CertificatePassword = "NO-CERTIFICATE-PASSWORD")
param([string] $DeploymentId = "ibu-devo-911",
	  [string] $ResourceGroupName = "ibu-devo-911",
	  [string] $AzureSubscriptionId = "575f0a7c-17d6-4c66-b207-f770cbd5bbd4",
	  [string] $ArmTemplateUrl = "https://emeasitecore9storageblob.blob.core.windows.net/911/arm911xpas/azuredeploy.json?st=2019-07-29T14%3A30%3A00Z&se=2020-10-16T14%3A30%3A00Z&sp=rl&sv=2018-03-28&sr=c&sig=o5N0eIAOL4DVfDyMzkko162Xq6TQku4mA3AMqmb3ZTE%3D",
	# These parameter should be passed by Secure Files
	  [string] $LicensePath = "C:\ibu\license\license.xml",
	  [string] $Location = "westeurope",
	  [string] $CertificateFilePath = "C:\projects\EA1FAC1B9F10605EEA1DDC62E6A76C15E590051A.pfx",
	  [string] $CertificatePassword = "secret")

Import-Module "C:\projects\DevOps\Sitecore.SampleAzureProject\DevOps\Tools\SAT-2.3.0\Sitecore.Cloud.Cmdlets.psm1"

$agentReleaseDirectory = $Env:AGENT_RELEASEDIRECTORY
$releasePrimaryArtifactSourceAlias = $Env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
$rootPath = "$agentReleaseDirectory\$releasePrimaryArtifactSourceAlias\DevOps\Scripts"

# Specify the parameters for the deployment 
#$ArmParametersPath = "$rootPath\azuredeploy.parameters.json"
$ArmParametersPath = "C:\projects\DevOps\Sitecore.SampleAzureProject\DevOps\Scripts\azuredeploy.parameters.json"

$certificateBlob = $null

# read the contents of your authentication certificate
if ($CertificateFilePath) {
  $certificateBlob = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($CertificateFilePath))
}

#region Create Params Object
# license file needs to be secure string and adding the params as a hashtable is the only way to do it
$additionalParams = New-Object -TypeName Hashtable
$additionalParams.Set_Item('applicationInsightsLocation',$Location)
$additionalParams.Set_Item('location',$Location)
$additionalParams.Set_Item('deploymentId',$DeploymentId)

# Inject Certificate Blob and Password into the parameters
if ($certificateBlob) {
  $additionalParams.Set_Item('authCertificateBlob',$certificateBlob)
}
if ($certificatePassword) {
  $additionalParams.Set_Item('authCertificatePassword',$certificatePassword)
}

Write-Host "Setting Azure RM context..."
Set-AzureRmContext -SubscriptionID $AzureSubscriptionId

Write-Host "Starting ARM deployment..."

Start-SitecoreAzureDeployment -location $Location -Name $ResourceGroupName -ArmTemplateUrl $ArmTemplateUrl -ArmParametersPath $ArmParametersPath -LicenseXmlPath $LicensePath -SetKeyValue $additionalParams

Write-Host "Deployment Complete."
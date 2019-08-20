param([string] $DeploymentId = "ibu-devo-911",
	  [string] $ResourceGroupName = "ibu-devo-911",
	  [string] $AzureSubscriptionId = "SUBSCRIPTION-ID",
	  [string] $ArmTemplateUrl = "NO-TEMPLATE-URL",
	# These parameter should be passed by Secure Files
	  [string] $LicensePath = "NO-LICENSE-FILE",
	  [string] $Location = "westeurope",
	  [string] $CertificateFilePath = "NO-CERTIFICATE-FILE",
	  [string] $CertificatePassword = "NO-CERTIFICATE-PASSWORD")

$agentReleaseDirectory = $Env:AGENT_RELEASEDIRECTORY
$releasePrimaryArtifactSourceAlias = $Env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
$rootPath = "$agentReleaseDirectory\$releasePrimaryArtifactSourceAlias\DevOps\Scripts"
$toolsPath = "$agentReleaseDirectory\$releasePrimaryArtifactSourceAlias\DevOps\Tools"

# Specify the parameters for the deployment 
$ArmParametersPath = "$rootPath\azuredeploy.parameters.json"

Import-Module "$toolsPath\SAT-2.3.0\Sitecore.Cloud.Cmdlets.psm1"

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

Set-AzureRmContext -SubscriptionID $AzureSubscriptionId

Start-SitecoreAzureDeployment -location $Location -Name $ResourceGroupName -ArmTemplateUrl $ArmTemplateUrl -ArmParametersPath $ArmParametersPath -LicenseXmlPath $LicensePath -SetKeyValue $additionalParams
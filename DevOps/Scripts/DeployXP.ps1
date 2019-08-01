param([string] $DeploymentId = "ibu-devo-911",
	  [string] $ResourceGroupName = "ibu-devo-911",
	  [string] $AzureSubscriptionId = "575f0a7c-17d6-4c66-b207-f770cbd5bbd4",
	  [string] $ArmTemplateUrl = "NO-TEMPLATE-URL",
	# These parameter should be passed by Secure Files
	  [string] $LicensePath = "NO-LICENSE-FILE",
	  [string] $Location = "westeurope",
	  [string] $CertificateFilePath = "NO-CERTIFICATE-FILE",
	  [string] $CertificatePassword = "NO-CERTIFICATE-PASSWORD")

$agentReleaseDirectory = $Env:AGENT_RELEASEDIRECTORY
$releasePrimaryArtifactSourceAlias = $Env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
$rootPath = "$agentReleaseDirectory\$releasePrimaryArtifactSourceAlias\DevOps\Scripts"

# Specify the parameters for the deployment 
#$ArmTemplateUrl = "https://emeasitecore9storageblob.blob.core.windows.net/911/arm911xpas/azuredeploy.json?st=2019-07-29T14%3A30%3A00Z&se=2020-10-16T14%3A30%3A00Z&sp=rl&sv=2018-03-28&sr=c&sig=o5N0eIAOL4DVfDyMzkko162Xq6TQku4mA3AMqmb3ZTE%3D"
$ArmParametersPath = "$rootPath\azuredeploy.parameters.json"

$certificateBlob = $null

$Name = $DeploymentId

# read the contents of your Sitecore license file
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path $LicensePath | Out-String

# read the contents of your authentication certificate
if ($CertificateFilePath) {
  $certificateBlob = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($CertificateFilePath))
}

#region Create Params Object
# license file needs to be secure string and adding the params as a hashtable is the only way to do it
$additionalParams = New-Object -TypeName Hashtable

$params = Get-Content $ArmParametersPath -Raw | ConvertFrom-Json

if ($params | Get-Member -Name parameters) {
  $params = $params.parameters
}

foreach($p in $params | Get-Member -MemberType *Property)
{
  $additionalParams.Add($p.Name, $params.$($p.Name).value)
}

$additionalParams.Set_Item('licenseXml',$licenseFileContent)
$additionalParams.Set_Item('deploymentId',$Name)
$additionalParams.Set_Item('location',$Location)
$additionalParams.Set_Item('location',$Location)
$additionalParams.Set_Item('applicationInsightsLocation',$Location)

# Inject Certificate Blob and Password into the parameters
if ($certificateBlob) {
  $additionalParams.Set_Item('authCertificateBlob',$certificateBlob)
}
if ($certificatePassword) {
  $additionalParams.Set_Item('authCertificatePassword',$certificatePassword)
}

#region Validate Resouce Group Name	
Write-Host "Validating Resource Group Name..."
if(!($ResourceGroupName -cmatch '^(?!.*--)[a-z0-9]{2}(|([a-z0-9\-]{0,37})[a-z0-9])$'))
{
	Write-Error "Name should only contain lowercase letters, digits or dashes,
				 dash cannot be used in the first two or final character,
				 it cannot contain consecutive dashes and is limited between 2 and 40 characters in length!"
	Break;		
}
	
#endregion
Write-Host "Setting Azure RM context..."
Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
	Write-Host "Check if resource group already exists..."
$notPresent = Get-AzureRmResourceGroup -Name $ResourceGroupName -ev notPresent -ea 0

if (!$notPresent) 
{
	New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
}

Write-Host "Starting ARM deployment..."
New-AzureRmResourceGroupDeployment `
		-Name $Name `
		-ResourceGroupName $ResourceGroupName `
		-TemplateUri $ArmTemplateUrl `
		-TemplateParameterObject $additionalParams `
		# -AsJob
		# -DeploymentDebugLogLevel All -Debug -Verbose

Write-Host "Deployment Complete."
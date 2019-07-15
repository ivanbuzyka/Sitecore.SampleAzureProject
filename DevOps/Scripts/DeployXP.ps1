param([string] $DeploymentId = "ibu-xp-911", 
      [string] $SubscriptinId = "575f0a7c-17d6-4c66-b207-f770cbd5bbd4")

$rootPath = ".\DevOps\Scripts"
$rootPath1 = Get-Location
Write-Host "Root path is: $rootPath1"
# Specify the parameters for the deployment 
$ArmTemplateUrl = "https://emeasitecore9storageblob.blob.core.windows.net/911/arm911xp/azuredeploy.json?st=2019-06-12T09%3A35%3A00Z&se=2019-07-14T09%3A35%3A00Z&sp=rl&sv=2018-03-28&sr=c&sig=6nzXZZpyKgiRlUcT1jNCR4DKkReSk9RfcsRxoU8VOxU%3D"
$ArmParametersPath = "$rootPath\azuredeploy.parameters.json"
$licenseFilePath = "$rootPath\license.xml"

# Specify the certificate file path and password if you want to deploy Sitecore 9.0 XP or XDB configurations
$certificateFilePath = "$rootPath\EA1FAC1B9F10605EEA1DDC62E6A76C15E590051A.pfx" 
$certificatePassword = "secret"
$certificateBlob = $null

$Name = $DeploymentId #"ibu-xp-911"
$location = "westeurope"
$AzureSubscriptionId = $SubscriptinId

# read the contents of your Sitecore license file
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path $licenseFilePath | Out-String

# read the contents of your authentication certificate
if ($certificateFilePath) {
  $certificateBlob = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($certificateFilePath))
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

# Inject Certificate Blob and Password into the parameters
if ($certificateBlob) {
  $additionalParams.Set_Item('authCertificateBlob',$certificateBlob)
}
if ($certificatePassword) {
  $additionalParams.Set_Item('authCertificatePassword',$certificatePassword)
}

#endregion

#region Service Principle Details

# By default this script will prompt you for your Azure credentials but you can update the script to use an Azure Service Principal instead by following the details at the link below and updating the four variables below once you are done.
# https://azure.microsoft.com/en-us/documentation/articles/resource-group-authenticate-service-principal/

$UseServicePrincipal = $false
$TenantId = "SERVICE_PRINCIPAL_TENANT_ID"
$ApplicationId = "SERVICE_PRINCIPAL_APPLICATION_ID"
$ApplicationPassword = "SERVICE_PRINCIPAL_APPLICATION_PASSWORD"

#endregion

try 
{
	
	#region Validate Resouce Group Name	

	Write-Host "Validating Resource Group Name..."
	if(!($Name -cmatch '^(?!.*--)[a-z0-9]{2}(|([a-z0-9\-]{0,37})[a-z0-9])$'))
	{
		Write-Error "Name should only contain lowercase letters, digits or dashes,
					 dash cannot be used in the first two or final character,
					 it cannot contain consecutive dashes and is limited between 2 and 40 characters in length!"
		Break;		
	}
		
	#endregion
	
	Write-Host "Setting Azure RM Context..."

 	if($UseServicePrincipal -eq $true)
	{
		#region Use Service Principle
		$secpasswd = ConvertTo-SecureString $ApplicationPassword -AsPlainText -Force
		$mycreds = New-Object System.Management.Automation.PSCredential ($ApplicationId, $secpasswd)
		Login-AzureRmAccount -ServicePrincipal -Tenant $TenantId -Credential $mycreds
		
		Set-AzureRmContext -SubscriptionID $AzureSubscriptionId -TenantId $TenantId
		#endregion
	}
	else
	{
		#region Use Manual Login
		try 
		{
			Write-Host "inside try"
			Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
		}
		catch 
		{
			Write-Host "inside catch"
			Login-AzureRmAccount
			Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
		}
		#endregion		
	}
	
 	Write-Host "Check if resource group already exists..."
	$notPresent = Get-AzureRmResourceGroup -Name $Name -ev notPresent -ea 0
	
	if (!$notPresent) 
	{
		New-AzureRmResourceGroup -Name $Name -Location $location
	}
	
	# Write-Host "Starting ARM deployment..."
	# New-AzureRmResourceGroupDeployment `
	# 		-Name $Name `
	# 		-ResourceGroupName $Name `
	# 		-TemplateUri $ArmTemplateUrl `
	# 		-TemplateParameterObject $additionalParams `
	# 		# -DeploymentDebugLogLevel All -Debug -Verbose
			
	# Write-Host "Deployment Complete."
}
catch 
{
	Write-Error $_.Exception.Message
	Break 
}
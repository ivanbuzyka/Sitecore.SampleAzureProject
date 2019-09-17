param(	[string] $ResourceGroupName = "ibu1",	
	[string] $WebAppName = "ibu1-cm",
	[string] $SlotName = "test",
	[string] $SqlDbCopyName = "ibu1-master-db",
	[string] $ConnectionStringName = "master",
	[string] $ConnectionStringValue = "connstringvalue"
    )
	
	Write-Host "Setting connection string for "

	$webApp = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName
	
	$connStringsList = $webApp.SiteConfig.ConnectionStrings	
	$hashItems = New-Object System.Collections.HashTable

	ForEach ($keyValuePair in $connStringsList) {
		$setting =  @{Type=$keyValuePair.Type.ToString();Value=$keyValuePair.ConnectionString.ToString()}
		$hashItems[$keyValuePair.Name] = $setting
	}

	$hashItems[$ConnectionStringName] = @{Type="SQLAzure".ToString();Value=$ConnectionStringValue.ToString()}
	  
	Set-AzureRmWebAppSlot -ConnectionStrings $hashItems -Name $WebAppName -Slot $SlotName -ResourceGroupName $ResourceGroupName
	#Set-AzureRmWebAppSlotConfigName -ResourceGroupName $ResourceGroupName -Name $WebAppName -AppSettingNames @($settingName)
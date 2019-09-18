param(	[string] $ResourceGroupName = "ibu1",	
	[string] $WebAppName = "ibu1-cm",
	[string] $SlotName = "test",
	[string] $ConnectionStringName = "master",	
	[string] $SqlServerName = "ibu1-sql.database.windows.net",
	[string] $DbName = "ibu1-master-db",
	[string] $DbUserName = "masteruser",
	[string] $DbPassword = "password"
    )
	
	Write-Host "Setting connection string for "

	$composedConnectionString = "Encrypt=True;TrustServerCertificate=False;Data Source=$SqlServerName,1433;Initial Catalog=$DbName;User Id=$DbUserName;Password=$DbPassword;"

	Write-Host "Composed connection string: $composedConnectionString"

	$webApp = Get-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $WebAppName -Slot $SlotName
	
	$connStringsList = $webApp.SiteConfig.ConnectionStrings	
	$hashItems = New-Object System.Collections.HashTable

	ForEach ($keyValuePair in $connStringsList) {
		$setting =  @{Type=$keyValuePair.Type.ToString();Value=$keyValuePair.ConnectionString.ToString()}
		$hashItems[$keyValuePair.Name] = $setting
	}

	$hashItems[$ConnectionStringName] = @{Type="SQLAzure";Value=$composedConnectionString}
	
	Write-Host "ConnectionStrings list:"
	$hashItems | Format-Table -AutoSize

	Set-AzureRmWebAppSlot -ConnectionStrings $hashItems -Name $WebAppName -Slot $SlotName -ResourceGroupName $ResourceGroupName
	#Set-AzureRmWebAppSlotConfigName -ResourceGroupName $ResourceGroupName -Name $WebAppName -AppSettingNames @($settingName)
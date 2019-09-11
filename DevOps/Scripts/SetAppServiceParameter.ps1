param([string] $WebAppName = "ibu1-cm",
	  [string] $ResourceGroupName = "ibu1",	  
	  [string] $LocalenvDefine = "development",
	  [string] $SlotName = "pre-prod")

	  $settingName = "localenv:define"	  

	  $webApp = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName
	  
	  $appSettings = $webApp.SiteConfig.AppSettings
	  
	  $newAppSettings = @{}
	  ForEach ($item in $appSettings) {
	  $newAppSettings[$item.Name] = $item.Value
	  }
	  
	  $newAppSettings[$settingName] = $LocalenvDefine
	  
	  Set-AzureRmWebAppSlot -AppSettings $newAppSettings -Name $WebAppName -Slot $SlotName -ResourceGroupName $ResourceGroupName
	  Set-AzureRmWebAppSlotConfigName -ResourceGroupName $ResourceGroupName -Name $WebAppName -AppSettingNames @($settingName)
	  
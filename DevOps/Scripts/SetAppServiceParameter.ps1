param([string] $WebAppNamePrefix = "ibu1",
	  [string] $ResourceGroupName = "ibu1",	  
	  [string] $LocalenvDefine = "production")

	  $webAppName = "$WebAppNamePrefix-cm"

	  $webApp = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $webAppName
	  
	  $appSettings = $webApp.SiteConfig.AppSettings
	  
	  $newAppSettings = @{}
	  ForEach ($item in $appSettings) {
	  $newAppSettings[$item.Name] = $item.Value
	  }
	  
	  $newAppSettings['localenv:define'] = $LocalenvDefine
	  
	  Set-AzureRmWebApp -AppSettings $newAppSettings -Name $webAppName -ResourceGroupName $ResourceGroupName
	  
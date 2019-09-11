param(	[string] $ResourceGroupName = "ibu1",	
	[string] $SqlServerName = "ibu1-sql",
	[string] $SqlDbName = "ibu1-master-db",
	[string] $SqlDbCopyName = "ibu1-master-db-temp"
    )
	
	Write-Host "Copying Production DBs"
	Write-Host "Removing old copies if they exists"

	Remove-AzureRmSqlDatabase -DatabaseName $SqlDbCopyName `
	-ServerName $SqlServerName `
	-ResourceGroupName $ResourceGroupName `
	-Force `
	-ErrorAction SilentlyContinue


	New-AzureRMSqlDatabaseCopy -ResourceGroupName $ResourceGroupName `
	-ServerName $SqlServerName `
	-DatabaseName $SqlDbName `
	-CopyResourceGroupName $ResourceGroupName `
    -CopyServerName $SqlServerName `
	-CopyDatabaseName $SqlDbCopyName
	
	Write-Host "Copying complete"
param(	[string] $CMWebAppName = "ibu1-cm",
    [string] $CDWebAppName = "ibu1-cd",
    [string] $CMAppServicePlan = "ibu1-cm-hp",
    [string] $CDAppServicePlan = "ibu1-cd-hp",
    [string] $ResourceGroupName = "ibu1",
    [string] $SlotName = "pre-prod",
    [string] $location = "west europe"
    )
    #
    ##$agentReleaseDirectory = $Env:AGENT_RELEASEDIRECTORY
    ##$releasePrimaryArtifactSourceAlias = $Env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
    ##$rootPath = "$agentReleaseDirectory\$releasePrimaryArtifactSourceAlias\DevOps\Scripts"
    #
    $storagename = "backupstorscdevops1109"
    $container = "appbackup"
    $backupPrefix = "backup$(Get-Random -Minimum 1000 -Maximum 9999)"
    $cmBackupName = "$backupPrefix-cm"
    $cdBackupName = "$backupPrefix-cd"

    # Create storage account if it does not exist
    $storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $storagename -ErrorAction SilentlyContinue
    if ($null -eq $storage) {
        $storage = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $storagename -SkuName Standard_LRS -Location $location	
    }

    # Create storage container if it does not exist
    $storageContainer = Get-AzStorageContainer -Context $storage.Context -Name $container -ErrorAction SilentlyContinue
    if ($null -eq $storageContainer) {
        New-AzStorageContainer -Name $container -Context $storage.Context
    }

    ## Generates an SAS token for the storage container, valid for one month.
    ## NOTE: You can use the same SAS token to make backups in Web Apps until -ExpiryTime
    $sasUrl = New-AzStorageContainerSASToken -Name $container -Permission rwdl -Context $storage.Context -StartTime (Get-Date).AddDays(-1) -ExpiryTime (Get-Date).AddMonths(1) -FullUri
    Write-Host "Backup SAS URL: $sasUrl"
    
    ##Get-AzWebAppBackupList -ResourceGroupName $ResourceGroupName -Name $CMWebAppName

    $availableBackups = Get-AzWebAppBackupList -ResourceGroupName $ResourceGroupName -Name $CMWebAppName | Where-Object {$_.BackupStatus -eq "Succeeded"} | Sort-Object -Property Created -Descending
    if ($null -eq $availableBackups) {
        #Create backup here	
        $cmBackup = New-AzWebAppBackup -ResourceGroupName $ResourceGroupName -Name $CMWebAppName -StorageAccountUrl $sasUrl -BackupName $cmBackupName
        while ($true) {
            $backupStatus = Get-AzWebAppBackup -ResourceGroupName $ResourceGroupName -Name $CMWebAppName -BackupId $cmBackup.BackupId            
            if ($backupStatus.BackupStatus -eq "Succeeded") {		
                Write-Host "Backups: $cmBackupName suceeded"
                break
            }
            Start-Sleep -Seconds 10
        }
	}

    $latestBackup = (Get-AzWebAppBackupList -ResourceGroupName $ResourceGroupName -Name $CMWebAppName | Sort-Object -Property Created -Descending)[0]

    #TODO: create slot
    # Cleanup first
    Remove-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $CMWebAppName -Slot $SlotName -ErrorAction SilentlyContinue
    #$slotCM = New-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $CMWebAppName -AppServicePlan $CMAppServicePlan -Slot $SlotName
    Restore-AzWebAppBackup -ResourceGroupName $ResourceGroupName -Name $CMWebAppName -Slot $SlotName -StorageAccountUrl $sasUrl -BlobName $latestBackup.BackupName

    #$slotCD = New-AzWebAppSlot -ResourceGroupName $ResourceGroupName -Name $CDWebAppName -AppServicePlan $CMAppServicePlan -Slot $SlotName
    #TODO: Restore to slot
    #TODO: Remove storage account

    Write-Host "Deployment Complete."
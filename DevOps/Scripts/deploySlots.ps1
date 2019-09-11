param(	[string] $WebAppName = "ibu1-cm",    
    [string] $AppServicePlan = "ibu1-cm-hp",
    [string] $ResourceGroupName = "ibu1",
    [string] $SlotName = "pre-prod"
    )
	
	Write-Host "Copying Production webap app to $SlotName slot"
	Write-Host "Removing $SlotName if it exists"
	Remove-AzureRMWebAppSlot -ResourceGroupName $ResourceGroupName -Name $WebAppName -Slot $SlotName -ErrorAction SilentlyContinue -Force

	$ProdSlot = Get-AzureRMWebAppSlot -ResourceGroupName $ResourceGroupName -Name $WebAppName -Slot Production
	New-AzureRMWebAppSlot -ResourceGroupName $ResourceGroupName -Name $WebAppName -Slot $SlotName -AppServicePlan $AppServicePlan -SourceWebApp $ProdSlot

	Write-Host "Copying complete"
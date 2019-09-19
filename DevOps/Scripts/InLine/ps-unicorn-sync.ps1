# Write your PowerShell commands here.
# Exampel secret here

Write-Host "Unicorn sync..."

Import-Module $(System.DefaultWorkingDirectory)/_ivanbuzyka_Sitecore.SampleAzureProject/DevOps/Tools/Unicorn -Verbose

Sync-Unicorn -ControlPanelUrl "$(CMPreProdUrl)/unicorn.aspx" -SharedSecret "YOUR-SECRET-HERE" -Verbose
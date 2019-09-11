# Write your PowerShell commands here.

Write-Host "Publishing to Web..."

$url = "$(CmUrl)/-/script/v2/master/PublishAllSmart?user=admin&password=Sitecore12345#!"

Write-Host "Calling $url ..."
Invoke-RestMethod -Uri $url
# Write your PowerShell commands here.

Write-Host "Publishing to Web via remoting..."

Import-Module -Name SPE -RequiredVersion 5.1.0

$session = New-ScriptSession -Username admin -Password Sitecore12345#! -ConnectionUri $(CMPreProdUrl)
Invoke-RemoteScript -Session $session -ScriptBlock { Get-Item -Path master:\content | Publish-Item -Recurse -PublishMode Smart }
Stop-ScriptSession -Session $session
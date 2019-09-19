# Write your PowerShell commands here.

Write-Host "Installing SPE Remoting module..."

Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
Install-Module -Name SPE -RequiredVersion 5.1.0 -Force -Verbose -Scope CurrentUser

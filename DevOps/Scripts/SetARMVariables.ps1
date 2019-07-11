$rootDirectory = $Env:BUILD_SOURCESDIRECTORY

Write-Host "Hello World from $Env:AGENT_NAME."
Write-Host "My ID is $Env:AGENT_ID."
Write-Host "AGENT_WORKFOLDER contents:"
gci $Env:AGENT_WORKFOLDER
Write-Host "AGENT_BUILDDIRECTORY contents:"
gci $Env:AGENT_BUILDDIRECTORY
Write-Host "BUILD_SOURCESDIRECTORY contents:"
gci $Env:BUILD_SOURCESDIRECTORY
Write-Host "Current path is:"
Get-Location | Write-Host
Write-Host "Over and out."


$licenseFilePath = "$rootDirectory\DevOps\Scripts\license.xml"

# Specify the certificate file path and password if you want to deploy Sitecore 9.0 XP or XDB configurations
$certificateFilePath = "$rootDirectory\DevOps\Scripts\EA1FAC1B9F10605EEA1DDC62E6A76C15E590051A.pfx" 
$certificatePassword = "secret"
$certificateBlob = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($certificateFilePath))
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path $licenseFilePath | Out-String

#$location = "westeurope"

Write-Host "##vso[task.setvariable variable=certblob]$certificateBlob"
Write-Host "##vso[task.setvariable variable=licenseContent]$licenseFileContent"
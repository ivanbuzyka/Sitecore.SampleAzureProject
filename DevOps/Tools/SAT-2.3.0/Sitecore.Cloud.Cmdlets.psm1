if (Test-Path "$PSScriptRoot\Sitecore.Cloud.Cmdlets.dll") {
  Import-Module "$PSScriptRoot\Sitecore.Cloud.Cmdlets.dll"
}
elseif (Test-Path "$PSScriptRoot\bin\Sitecore.Cloud.Cmdlets.dll") {
  Import-Module "$PSScriptRoot\bin\Sitecore.Cloud.Cmdlets.dll"
}
else {
  throw "Failed to find Sitecore.Cloud.Cmdlets.dll, searched $PSScriptRoot and $PSScriptRoot\bin"
}

# public functions
Function Start-SitecoreAzureDeployment{
    <#
        .SYNOPSIS
        You can deploy a new Sitecore instance on Azure for a specific SKU

        .DESCRIPTION
        Deploys a new instance of Sitecore on Azure

        .PARAMETER location
        Standard Azure region (e.g.: North Europe)
        .PARAMETER Name
        Name of the deployment
        .PARAMETER ArmTemplateUrl
        Url to the ARM template
        .PARAMETER ArmTemplatePath
        Path to the ARM template
        .PARAMETER ArmParametersPath
        Path to the ARM template parameter
        .PARAMETER LicenseXmlPath
        Path to a valid Sitecore license
        .PARAMETER SetKeyValue
        This is a hash table, use to set the unique values for the deployment parameters in Arm Template Parameters Json

        .EXAMPLE
        Import-Module -Verbose .\Cloud.Services.Provisioning.SDK\tools\Sitecore.Cloud.Cmdlets.psm1
        $SetKeyValue = @{
        "deploymentId"="xP0-QA";
        "Sitecore.admin.password"="!qaz2wsx";
        "sqlserver.login"="xpsqladmin";
        "sqlserver.password"="Password12345";    "analytics.mongodb.connectionstring"="mongodb://17.54.72.145:27017/xP0-QA-analytics";
        "tracking.live.mongodb.connectionstring"="mongodb://17.54.72.145:27017/xP0-QA-tracking_live";
        "tracking.history.mongodb.connectionstring"="mongodb://17.54.72.145:27017/xP0-QA-tracking_history";
        "tracking.contact.mongodb.connectionstring"="mongodb://17.54.72.145:27017/xP0-QA-tracking_contact"
        }
        Start-SitecoreAzureDeployment -Name $SetKeyValue.deploymentId -Region "North Europe" -ArmTemplatePath "C:\dev\azure\xP0.Template.json" -ArmParametersPath "xP0.Template.params.json" -LicenseXmlPath "D:\xp0\license.xml" -SetKeyValue $SetKeyValue
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
        [alias("Region")]
        [string]$Location,
        [parameter(Mandatory=$true)]
        [string]$Name,
        [parameter(ParameterSetName="Template URI", Mandatory=$true)]
        [string]$ArmTemplateUrl,
        [parameter(ParameterSetName="Template Path", Mandatory=$true)]
        [string]$ArmTemplatePath,
        [parameter(Mandatory=$true)]
        [string]$ArmParametersPath,
        [parameter(Mandatory=$true)]
        [string]$LicenseXmlPath,
        [hashtable]$SetKeyValue
    )

    try {
        Write-Host "Deployment Started..."

        if ([string]::IsNullOrEmpty($ArmTemplateUrl) -and [string]::IsNullOrEmpty($ArmTemplatePath)) {
            Write-Host "Either ArmTemplateUrl or ArmTemplatePath is required!"
            Break
        }

        if(!($Name -cmatch '^(?!.*--)[a-z0-9]{2}(|([a-z0-9\-]{0,37})[a-z0-9])$'))
        {
            Write-Error "Name should only contain lowercase letters, digits or dashes,
                         dash cannot be used in the first two or final character,
                         it cannot contain consecutive dashes and is limited between 2 and 40 characters in length!"
            Break;
        }

        if ($SetKeyValue -eq $null) {
            $SetKeyValue = @{}
        }

        # Set the Parameters in Arm Template Parameters Json
        $paramJson = Get-Content $ArmParametersPath -Raw

        Write-Verbose "Setting ARM template parameters..."
        
        # Read and Set the license.xml
        $licenseXml = Get-Content $LicenseXmlPath -Raw -Encoding UTF8
        $SetKeyValue.Add("licenseXml", $licenseXml)

        # Update params and save to a temporary file
        $paramJsonFile = "temp_$([System.IO.Path]::GetRandomFileName())"
        Set-SCAzureDeployParameters -ParametersJson $paramJson -SetKeyValue $SetKeyValue | Set-Content $paramJsonFile -Encoding UTF8

        Write-Verbose "ARM template parameters are set!"

        # Deploy Sitecore in given Location
        Write-Verbose "Deploying Sitecore Instance..."
        $notPresent = Get-AzureRmResourceGroup -Name $Name -ev notPresent -ea 0
        if (!$notPresent) {
            New-AzureRmResourceGroup -Name $Name -Location $Location -Tag @{ "provider" = "b51535c2-ab3e-4a68-95f8-e2e3c9a19299" }
        }
        else {
            Write-Verbose "Resource Group Already Exists."
        }

        if ([string]::IsNullOrEmpty($ArmTemplateUrl)) {
            $PSResGrpDeployment = New-AzureRmResourceGroupDeployment -Name $Name -ResourceGroupName $Name -TemplateFile $ArmTemplatePath -TemplateParameterFile $paramJsonFile
        }else{
            # Replace space character in the url, as it's not being replaced by the cmdlet itself
            $PSResGrpDeployment = New-AzureRmResourceGroupDeployment -Name $Name -ResourceGroupName $Name -TemplateUri ($ArmTemplateUrl -replace ' ', '%20') -TemplateParameterFile $paramJsonFile
        }
        $PSResGrpDeployment
    }
    catch {
        Write-Error $_.Exception.Message
        Break
    }
    finally {
      if ($paramJsonFile) {
        Remove-Item $paramJsonFile
      }
    }
}

Function Start-SitecoreAzurePackaging{
    <#
        .SYNOPSIS
        Using this command you can create SKU specific Sitecore Azure web deploy packages

        .DESCRIPTION
        Creates valid Azure web deploy packages for SKU specified in the sku configuration file

        .PARAMETER sitecorePath
        Path to the Sitecore's zip file
        .PARAMETER destinationFolderPath
        Destination folder path which web deploy packages will be generated into
        .PARAMETER cargoPayloadFolderPath
        Path to the root folder containing cargo payloads (*.sccpl files)
        .PARAMETER commonConfigPath
        Path to the common.packaging.config.json file
        .PARAMETER skuConfigPath
        Path to the sku specific config file (e.g.: xp1.packaging.config.json)
        .PARAMETER parameterXmlPath
        Path to the root folder containing MS Deploy xml files (parameters.xml)
        .PARAMETER fileVersion
        Generates a text file called version.txt, containing value passed to this parameter and puts it in the webdeploy package for traceability purposes - this parameter is optional
        .PARAMETER integratedSecurity
        Indicates should integrated security be used in connectionString. False by default

        .EXAMPLE
        Start-SitecoreAzurePackaging -sitecorePath "C:\Sitecore\Sitecore 8.2 rev. 161103.zip" ` -destinationPath .\xp1 `
        -cargoPayloadFolderPath .\Cloud.Services.Provisioning.SDK\tools\CargoPayloads `
        -commonConfigPath .\Cloud.Services.Provisioning.SDK\tools\Configs\common.packaging.config.json `
        -skuConfigPath .\Cloud.Services.Provisioning.SDK\tools\Configs\xp1.packaging.config.json `
        -parameterXmlPath .\Cloud.Services.Provisioning.SDK\tools\MSDeployXmls
        -integratedSecurity $true
    #>
    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
        [string]$SitecorePath,
        [parameter(Mandatory=$true)]
        [string]$DestinationFolderPath,
        [parameter(Mandatory=$true)]
        [string]$CargoPayloadFolderPath,
        [parameter(Mandatory=$true)]
        [string]$CommonConfigPath,
        [parameter(Mandatory=$true)]
        [string]$SkuConfigPath,
        [parameter(Mandatory=$true)]
        [string]$ParameterXmlPath,
        [parameter(Mandatory=$false)]
        [string]$FileVersion,
        [parameter(Mandatory=$false)]
        [bool]$IntegratedSecurity
    )

    try {

        $DestinationFolderPath = AddTailBackSlashToPathIfNotExists($DestinationFolderPath)
        $cargoPayloadFolderPath = AddTailBackSlashToPathIfNotExists($CargoPayloadFolderPath)
        $ParameterXmlPath = AddTailBackSlashToPathIfNotExists($ParameterXmlPath)

        # Create the Raw Web Deploy Package
        Write-Verbose "Creating the Raw Web Deploy Package..."
        if ($FileVersion -eq $null) {
                $sitecoreWebDeployPackagePath = New-SCWebDeployPackage -Path $SitecorePath -Destination $DestinationFolderPath -IntegratedSecurity $IntegratedSecurity
        }
        else {
                $sitecoreWebDeployPackagePath = New-SCWebDeployPackage -Path $SitecorePath -Destination $DestinationFolderPath -FileVersion $FileVersion -IntegratedSecurity $IntegratedSecurity -Force
        }
        Write-Verbose "Raw Web Deploy Package Created Successfully!"

        # Read and Apply the common Configs
        $commonConfigs = (Get-Content $CommonConfigPath -Raw) | ConvertFrom-Json
        $commonSccplPaths = @()
        foreach($sccpl in $commonConfigs.sccpls)
        {
            $commonSccplPaths += $CargoPayloadFolderPath + $sccpl;
        }

        Write-Verbose "Applying Common Cloud Configurations..."
        Update-SCWebDeployPackage -Path $sitecoreWebDeployPackagePath -CargoPayloadPath $commonSccplPaths
        Write-Verbose "Common Cloud Configurations Applied Successfully!"

        # Read the SKU Configs
        $skuconfigs = (Get-Content $SkuConfigPath -Raw) | ConvertFrom-Json
        foreach($scwdp in $skuconfigs.scwdps)
        {
            # Create the role specific scwdps
            $roleScwdpPath =  $sitecoreWebDeployPackagePath -replace ".scwdp", ("_" + $scwdp.role + ".scwdp")
            Copy-Item $sitecoreWebDeployPackagePath $roleScwdpPath -Verbose

            # Apply the role specific cargopayloads
            $sccplPaths = @()
            foreach($sccpl in $scwdp.sccpls)
            {
                $sccplPaths += $CargoPayloadFolderPath + $sccpl;
            }
            if ($sccplPaths.Length -gt 0) {
                Write-Verbose "Applying $($scwdp.role) Role Specific Configurations..."
                Update-SCWebDeployPackage -Path $roleScwdpPath -CargoPayloadPath $sccplPaths
                Write-Verbose "$($scwdp.role) Role Specific Configurations Applied Successfully!"
            }

            # Set the role specific parameters.xml and archive.xml
            Write-Verbose "Setting $($scwdp.role) Role Specific Web Deploy Package Parameters XML and Generating Archive XML..."
            Update-SCWebDeployPackage -Path $roleScwdpPath -ParametersXmlPath ($ParameterXmlPath + $scwdp.parametersXml)
            Write-Verbose "$($scwdp.role) Role Specific Web Deploy Package Parameters and Archive XML Added Successfully!"
        }

        # Remove the Raw Web Deploy Package
        Remove-Item -Path $sitecoreWebDeployPackagePath
    }
    catch {
        Write-Host $_.Exception.Message
        Break
    }
}

Function Start-SitecoreAzureModulePackaging {
    <#
        .SYNOPSIS
        Using this command you can create Sitecore Azure Module web deploy packages

        .DESCRIPTION
        Creates valid Sitecore Azure Module web deploy packages

        .PARAMETER SourceFolderPath
        Source folder path to the Sitecore's exm module package zip files

        .PARAMETER DestinationFolderPath
        Destination folder path which web deploy packages will be generated into

        .PARAMETER CargoPayloadFolderPath
        Root folder path which contain cargo payloads (*.sccpl files)

		.PARAMETER AdditionalWdpContentsFolderPath
        Root folder path which contain folders with additional contents to Wdp

        .PARAMETER ParameterXmlPath
        Root folder path which contain the msdeploy xml files (parameters.xml)

        .PARAMETER ConfigFilePath
        File path of SKU and Role config json files

        .EXAMPLE
		Start-SitecoreAzureModulePackaging -SourceFolderPath "D:\Sitecore\Modules\Email Experience Manager 3.5.0 rev. 170310" -DestinationFolderPath "D:\Work\EXM\WDPs" -CargoPayloadFolderPath "D:\Resources\EXM 3.5\CargoPayloads" -AdditionalWdpContentsFolderPath "D:\Work\EXM\AdditionalFiles" -ParameterXmlFolderPath "D:\Resources\EXM 3.5\MsDeployXmls" -ConfigFile "D:\Resources\EXM 3.5\Configs\EXM0.Packaging.config.json"
    #>

    [CmdletBinding()]
    param (
        [parameter(Mandatory=$true)]
        [string]$SourceFolderPath,
        [parameter(Mandatory=$true)]
        [string]$DestinationFolderPath,
        [parameter(Mandatory=$true)]
        [string]$CargoPayloadFolderPath,
		[parameter(Mandatory=$true)]
        [string]$AdditionalWdpContentsFolderPath,
        [parameter(Mandatory=$true)]
        [string]$ParameterXmlFolderPath,
        [parameter(Mandatory=$true)]
        [string]$ConfigFilePath
    )

    # Read the role config
    $skuconfigs = (Get-Content $ConfigFilePath -Raw) | ConvertFrom-Json
    ForEach($scwdp in $skuconfigs.scwdps) {

        # Find source package path
        Get-ChildItem $SourceFolderPath | Where-Object { $_.Name -match $scwdp.sourcePackagePattern } |
        Foreach-Object {
            $packagePath = $_.FullName
        }

        # Create the Wdp
        $wdpPath = ConvertTo-SCModuleWebDeployPackage -Path $packagePath -Destination $DestinationFolderPath

        # Apply the Cargo Payloads
        ForEach($sccpl in $scwdp.sccpls) {
            $cargoPayloadPath = $sccpl
            Update-SCWebDeployPackage -Path $wdpPath -CargoPayloadPath "$CargoPayloadFolderPath\$cargoPayloadPath"
        }

        # Embed the Cargo Payloads
        ForEach($embedSccpl in $scwdp.embedSccpls) {
            $embedCargoPayloadPath = $embedSccpl
            Update-SCWebDeployPackage -Path $wdpPath -EmbedCargoPayloadPath "$CargoPayloadFolderPath\$embedCargoPayloadPath"
        }

		# Add additional Contents To Wdp from given Folders
		ForEach($additionalContentFolder in $scwdp.additionalWdpContentsFolders) {
			$additionalContentsFolderPath = $additionalContentFolder
			Update-SCWebDeployPackage -Path $wdpPath -SourcePath "$AdditionalWdpContentsFolderPath\$additionalContentsFolderPath"
		}

		# Update the ParametersXml
		if($scwdp.parametersXml) {
			$parametersXml = $scwdp.parametersXml
			Update-SCWebDeployPackage -Path $wdpPath -ParametersXmlPath "$ParameterXmlFolderPath\$parametersXml"
		}

        # Rename the Wdp to be more role specific
        $role = $scwdp.role
        Rename-Item $wdpPath ($wdpPath -replace ".scwdp.zip", "_$role.scwdp.zip")
    }
}

Function ConvertTo-SitecoreWebDeployPackage {
    <#
        .SYNOPSIS
        Using this command, you can convert a Sitecore package to a web deploy package

        .DESCRIPTION
        Creates a new webdeploypackage from the Sitecore package passed to it

        .PARAMETER Path
        Path to the Sitecore installer package
        .PARAMETER Destination
        Destination folder that web deploy package will be created into - optional parameter, if not passed will use the current location
        .PARAMETER Force
        If set, will overwrite existing web deploy package with the same name

        .EXAMPLE
        ConvertTo-SitecoreWebDeployPackage -Path "C:\Sitecore\Modules\Web Forms for Marketers 8.2 rev. 160801.zip" -Force

        .REMARKS
        Currently, this CmdLet creates a webdeploy package only from "files" folder of the package
    #>
    [Obsolete("Use Start-SitecoreAzureModulePackaging for Sitecore module packaging")]
    [CmdletBinding()]
    param(
    [parameter(Mandatory=$true)]
    [string]$Path,
    [parameter()]
    [string]$Destination,
    [parameter()]
    [switch]$Force
    )

    if(!$Destination -or $Destination -eq "") {
        $Destination = (Get-Location).Path
    }

    if($Force) {
        return ConvertTo-SCWebDeployPackage -PSPath $Path -Destination $Destination -Force
    } else {
        return ConvertTo-SCWebDeployPackage -PSPath $Path -Destination $Destination
    }
}

Function Set-SitecoreAzureTemplates {
    <#
        .SYNOPSIS
        Using this command you can upload Sitecore ARM templates to an Azure Storage

        .DESCRIPTION
        Uploads all the ARM Templates files in the given folder and the sub folders to given Azure Storage in the same folder hierarchy

        .PARAMETER Path
        Path to the Sitecore ARM Templates folder
        .PARAMETER StorageContainerName
        Name of the target container in the Azure Storage Account
        .PARAMETER AzureStorageContext
        Azure Storage Context object returned by New-AzureStorageContext
        .PARAMETER StorageConnectionString
        Connection string of the target Azure Storage Account
        .PARAMETER Force
        If set, will overwrite existing templates with the same name in the target container

        .EXAMPLE
        $StorageContext = New-AzureStorageContext -StorageAccountName "samplestorageaccount" -StorageAccountKey "3pQEA23emk0aio2RK6luL0MfP2P81lg9JEo4gHSEHkejL9+/9HCU4IjhsgAbcXnQz6j72B3Xq8TZZpwj4GI+Qw=="
        Set-SitecoreAzureTemplates -Path "D:\Work\UploadSitecoreTemplates\Templates" -StorageContainerName "samplecontainer" -AzureStorageContext $StorageContext
    #>
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [string]$Path,
        [parameter(Mandatory=$true)]
        [string]$StorageContainerName,
        [parameter(ParameterSetName="context",Mandatory=$true)]
        [System.Object]$AzureStorageContext,
        [parameter(ParameterSetName="connstring",Mandatory=$true)]
        [string]$StorageConnectionString,
        [parameter()]
        [switch]$Force
    )

    if ([string]::IsNullOrEmpty($StorageConnectionString) -and ($AzureStorageContext -eq $null)) {
        Write-Host "Either StorageConnectionString or AzureStorageContext is required!"
        Break
    }

    if ($StorageConnectionString) {
        $AzureStorageContext = New-AzureStorageContext -ConnectionString $StorageConnectionString
    }

    $absolutePath = Resolve-Path -Path $Path
    $absolutePath = AddTailBackSlashToPathIfNotExists($absolutePath)

    $urlList = @()
    $files = Get-ChildItem $Path -Recurse -Filter "*.json"

    foreach($file in $files)
    {
        $localFile = $file.FullName
        $blobFile = $file.FullName.Replace($absolutePath, "")

        if ($Force) {
            $blobInfo = Set-AzureStorageBlobContent -File $localFile -Container $StorageContainerName -Blob $blobFile -Context $AzureStorageContext -Force
        } else{
            $blobInfo = Set-AzureStorageBlobContent -File $localFile -Container $StorageContainerName -Blob $blobFile -Context $AzureStorageContext
        }

        $urlList += $blobInfo.ICloudBlob.uri.AbsoluteUri
    }

    return ,$urlList
}

# Export public functions
Export-ModuleMember -Function Start-SitecoreAzureDeployment
Export-ModuleMember -Function Start-SitecoreAzurePackaging
Export-ModuleMember -Function Start-SitecoreAzureModulePackaging
Export-ModuleMember -Function ConvertTo-SitecoreWebDeployPackage
Export-ModuleMember -Function Set-SitecoreAzureTemplates
Export-ModuleMember -Cmdlet New-SCCargoPayload

# Internal functions
Function AddTailBackSlashToPathIfNotExists {
 param( [string]$Path)

    $Path = $Path.Trim()
    if (!$Path.EndsWith("\"))
    {
        $Path = $Path + "\"
    }

    return $Path
}

# SIG # Begin signature block
# MIIXwQYJKoZIhvcNAQcCoIIXsjCCF64CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUG9s+okV7VXhBlBJ9rvpF3Twc
# 8mOgghL8MIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUrMIIEE6ADAgECAhAHplztCw0v0TJNgwJhke9VMA0GCSqGSIb3DQEBCwUAMHIx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJ
# RCBDb2RlIFNpZ25pbmcgQ0EwHhcNMTcwODIzMDAwMDAwWhcNMjAwOTMwMTIwMDAw
# WjBoMQswCQYDVQQGEwJVUzELMAkGA1UECBMCY2ExEjAQBgNVBAcTCVNhdXNhbGl0
# bzEbMBkGA1UEChMSU2l0ZWNvcmUgVVNBLCBJbmMuMRswGQYDVQQDExJTaXRlY29y
# ZSBVU0EsIEluYy4wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7PZ/g
# huhrQ/p/0Cg7BRrYjw7ZMx8HNBamEm0El+sedPWYeAAFrjDSpECxYjvK8/NOS9dk
# tC35XL2TREMOJk746mZqia+g+NQDPEaDjNPG/iT0gWsOeCa9dUcIUtnBQ0hBKsuR
# bau3n7w1uIgr3zf29vc9NhCoz1m2uBNIuLBlkKguXwgPt4rzj66+18JV3xyLQJoS
# 3ZAA8k6FnZltNB+4HB0LKpPmF8PmAm5fhwGz6JFTKe+HCBRtuwOEERSd1EN7TGKi
# xczSX8FJMz84dcOfALxjTj6RUF5TNSQLD2pACgYWl8MM0lEtD/1eif7TKMHqaA+s
# m/yJrlKEtOr836BvAgMBAAGjggHFMIIBwTAfBgNVHSMEGDAWgBRaxLl7Kgqjpepx
# A8Bg+S32ZXUOWDAdBgNVHQ4EFgQULh60SWOBOnU9TSFq0c2sWmMdu7EwDgYDVR0P
# AQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGG
# L2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3Js
# MDWgM6Axhi9odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNz
# LWcxLmNybDBMBgNVHSAERTBDMDcGCWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxo
# dHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUH
# AQEEeDB2MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYI
# KwYBBQUHMAKGQmh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNI
# QTJBc3N1cmVkSURDb2RlU2lnbmluZ0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqG
# SIb3DQEBCwUAA4IBAQBozpJhBdsaz19E9faa/wtrnssUreKxZVkYQ+NViWeyImc5
# qEZcDPy3Qgf731kVPnYuwi5S0U+qyg5p1CNn/WsvnJsdw8aO0lseadu8PECuHj1Z
# 5w4mi5rGNq+QVYSBB2vBh5Ps5rXuifBFF8YnUyBc2KuWBOCq6MTRN1H2sU5LtOUc
# Qkacv8hyom8DHERbd3mIBkV8fmtAmvwFYOCsXdBHOSwQUvfs53GySrnIYiWT0y56
# mVYPwDj7h/PdWO5hIuZm6n5ohInLig1weiVDJ254r+2pfyyRT+02JVVxyHFMCLwC
# ASs4vgbiZzMDltmoTDHz9gULxu/CfBGM0waMDu3cMIIFMDCCBBigAwIBAgIQBAkY
# G1/Vu2Z1U0O1b5VQCDANBgkqhkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMG
# A1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQw
# IgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIw
# MDAwWhcNMjgxMDIyMTIwMDAwWjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhE
# aWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrb
# RPV/5aid2zLXcep2nQUut4/6kkPApfmJ1DcZ17aq8JyGpdglrA55KDp+6dFn08b7
# KSfH03sjlOSRI5aQd4L5oYQjZhJUM1B0sSgmuyRpwsJS8hRniolF1C2ho+mILCCV
# rhxKhwjfDPXiTWAYvqrEsq5wMWYzcT6scKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXp
# dOYr/mzLfnQ5Ng2Q7+S1TqSp6moKq4TzrGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWO
# D8Gi6CxR93O8vYWxYoNzQYIH5DiLanMg0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IB
# zTCCAckwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0l
# BAwwCgYIKwYBBQUHAwMweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1Ud
# HwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFz
# c3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwTwYDVR0gBEgwRjA4BgpghkgB
# hv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9D
# UFMwCgYIYIZIAYb9bAMwHQYDVR0OBBYEFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8G
# A1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IB
# AQA+7A1aJLPzItEVyCx8JSl2qB1dHC06GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew
# 4fbRknUPUbRupY5a4l4kgU4QpO4/cY5jDhNLrddfRHnzNhQGivecRk5c/5CxGwcO
# kRX7uq+1UcKNJK4kxscnKqEpKBo6cSgCPC6Ro8AlEeKcFEehemhor5unXCBc2XGx
# DI+7qPjFEmifz0DLQESlE/DmZAwlCEIysjaKJAL+L3J+HNdJRZboWR3p+nRka7Lr
# ZkPas7CM1ekN3fYBIM6ZMWM9CBoYs4GbT8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiF
# LpKR6mhsRDKyZqHnGKSaZFHvMYIELzCCBCsCAQEwgYYwcjELMAkGA1UEBhMCVVMx
# FTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNv
# bTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmlu
# ZyBDQQIQB6Zc7QsNL9EyTYMCYZHvVTAJBgUrDgMCGgUAoHAwEAYKKwYBBAGCNwIB
# DDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFF5kQGy2me/6rIQNj3RTbRfx
# H+uOMA0GCSqGSIb3DQEBAQUABIIBALiLN2MdJAw/tVLR/2n52pTvPVH4/PGtpCsG
# 9dBMjScn0O0wtv7r53v+gAGjC1vMssRYcAJUewqvSK5rA9LhUSKIl9o5gMGQVtmi
# hzuf8gm0ARw8gdlqdOl1K5FgrKVgymnsBUPrjwKkb5dqkw++sj0/i6Za0SkxGhdr
# 4N5DoIDE17kPFtJ1G8QvBHInJhk25BMsO+/qWE1hw0IRJDpP9sELA1dsBpJW6QPf
# DoZDzG503LL9GiNUj4GT8j5YAdNpyy0ykrEE7QifDzgqL/Ip83eAWCDY4ll8Sqbe
# 7Woi92EtEHNQoMu7kkypgRk9IJrbuAA9o7a1VG+7nnMS2pbm7qqhggILMIICBwYJ
# KoZIhvcNAQkGMYIB+DCCAfQCAQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMU
# U3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3Rh
# bXBpbmcgU2VydmljZXMgQ0EgLSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMC
# GgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcN
# MTkwNDA5MTMwMjI2WjAjBgkqhkiG9w0BCQQxFgQUXI037mY2+qul9dYCmyNVAYvt
# vjIwDQYJKoZIhvcNAQEBBQAEggEAf8oQJfMFJNkZ5QqwClyhPrUEUajlQ1E/l575
# qstfCniXhqeNqiz5TzWsOk+k3XWVX/66oGq8HsckUh+vqnlfz5zsTwfQrvVtUpn0
# ugLMwEJmgNybLxpd7DHfEbgU2/UHTH+/+4n9unP8YMjvkrskWSevCkInOt2ciRsK
# o+Y3M2w+qCnDv6nXnkM1JkOxYjyYuRMpNMhlQlH+w6bm/pRGPb8bNH4k6WdN8gGc
# W7Khl6L0tIa4ZX64bexZI+JmwDjgXRd0nlNlb9NfS+PrcLXofbknImZs8ojjV+GL
# +7kxMQ970tDrBUiLWQ4YwDVhwsu4z8PGW6HbzoND18TKkY4qaQ==
# SIG # End signature block

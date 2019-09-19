# Write your PowerShell commands here.

Write-Host "Publishing to Web via remoting..."

Import-Module -Name SPE -RequiredVersion 5.1.0

$session = New-ScriptSession -Username admin -Password password -ConnectionUri $(CMPreProdUrl)

Invoke-RemoteScript -Session $session -ScriptBlock {
   $indexes = Get-SearchIndex
   foreach($index in $indexes)
   {
      Write-Host "Rebuilding " $index.Name
      Initialize-SearchIndex -Name $index.Name -AsJob
   }
}

Stop-ScriptSession -Session $session
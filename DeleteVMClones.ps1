param(
    [int]$numClones,
	[int]$startAt
)

# Pre-flight checks
$configPath = "$PSScriptRoot\config.ps1"
if (-not (Test-Path $configPath)) {
    Write-Error "ERROR: config.ps1 not found!"
    Write-Host ""
    Write-Host "Please follow these steps:"
    Write-Host "1. Copy config-example.ps1 to config.ps1"
    Write-Host "2. Edit config.ps1 and set the username and password"
    Write-Host "3. Review other configuration values"
    Write-Host ""
    exit 1
}

# Load configuration
. $configPath

# Validate no placeholder values remain
$configContent = Get-Content $configPath -Raw
if ($configContent -match "<SET_THIS_VALUE>") {
    Write-Error "ERROR: config.ps1 contains placeholder values!"
    Write-Host ""
    Write-Host "Please edit config.ps1 and replace all <SET_THIS_VALUE> placeholders"
    Write-Host "At minimum, you must set:"
    Write-Host "  - userName"
    Write-Host "  - password"
    Write-Host ""
    exit 1
}

function deleteClonedVm{
param(
    [int]$id
)
	$vmNamePrefixLower = $vmNamePrefix.ToLower()
	$ipResourceName = $vmNamePrefixLower + "_" + $id + "_ip"
	$nsgResourceName = $vmNamePrefixLower + "_" + $id + "_nic_nsg"
	$nicResourceName = $vmNamePrefixLower + "_" + $id + "_nic"
	$osDiskName = $vmNamePrefix + "_ClonedOSDisk_" + $id

	$virtualMachineName = $vmNamePrefix + "_" + $id
	
	$vm = Get-AzVM -ResourceGroupName $resourceGroupName  -Name $virtualMachineName
	$diskStorageURI = $vm.DiagnosticsProfile.BootDiagnostics.StorageUri
	$storageAccountName =  ($diskStorageURI.Split('/')[2]).Split('.')[0]   

	Remove-AzVm -ResourceGroupName $resourceGroupName -Name $virtualMachineName -ForceDeletion $true -Force
	Remove-AzResource -ResourceGroupName $resourceGroupName -ResourceName $osDiskName -ResourceType "Microsoft.Compute/disks" -Force
	Remove-AzResource -ResourceGroupName $resourceGroupName -ResourceName $nicResourceName -ResourceType "Microsoft.Network/networkInterfaces" -Force
	Remove-AzResource -ResourceGroupName $resourceGroupName -ResourceName $nsgResourceName -ResourceType "Microsoft.Network/networkSecurityGroups" -Force
	Remove-AzResource -ResourceGroupName $resourceGroupName -ResourceName $ipResourceName -ResourceType "Microsoft.Network/publicIPAddresses" -Force
	# Remove storage account
	Remove-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -Force
}

If ($startAt -ne $null) {
	$endVal = $numClones + $startAt
}
Else {
	$startAt = 0
	$endVal = $numClones
}
for ($i=$startAt; $i -lt $endVal; $i++)
{
	$id_string = $i.ToString()
	Write-Host "Deleting VM" $id_string
	deleteClonedVm -id $i
}
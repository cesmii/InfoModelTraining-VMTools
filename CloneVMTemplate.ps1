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

Write-Host "Creating $numClones VMs"

function createClonedVm{

	param (
        [string]$id
    )


	Write-Host "Creating VM with id: $id"
	####################################
	# 1. Create Managed Disk
	####################################
	# Parameters
	####################################
	$diskName = $vmNamePrefix + "_ClonedOSDisk_" + $id
	$virtualMachineName = $vmNamePrefix + "_" + $id

	####################################
	# Sequence
	####################################
	Select-AzSubscription -SubscriptionId $SubscriptionId
	$snapshot = Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName

	####################################
	# 2. Create VM from Managed Disk 
	####################################
	# Sequence
	####################################
	# Create Disk
	$diskConfig = New-AzDiskConfig -Location $location -SourceResourceId $snapshot.Id -CreateOption Copy -DiskSizeGB $diskSize 
	$disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $diskName # TODO choose one or the other
	$VirtualMachine = New-AzVMConfig -VMName $virtualMachineName -VMSize $virtualMachineSize
	$VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -ManagedDiskId $disk.Id -CreateOption Attach -Windows
	
	# Create IP, VNet and NIC
	$publicIp = New-AzPublicIpAddress -Name ($VirtualMachineName.ToLower()+'_ip') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -AllocationMethod Static
	$vnet = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName
	$nic = New-AzNetworkInterface -Name ($VirtualMachineName.ToLower()+'_nic') -ResourceGroupName $resourceGroupName -Location $snapshot.Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id
	
	$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
	New-AzVM -VM $VirtualMachine -ResourceGroupName $resourceGroupName -Location $snapshot.Location -DisableBginfoExtension
	
	# Create NSG and add RDP rule to it
	$nsgName = $VirtualMachineName.ToLower()+'_nic_nsg'
	$nsg = New-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName -Location $location
	$nsg | Add-AzNetworkSecurityRuleConfig -Name "RDP" -Description "Allow RDP" -Access Allow -Direction Inbound -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix * -DestinationPortRange 3389 -Protocol Tcp
	$nsg | Set-AzNetworkSecurityGroup
	
	# Associate NSG with NIG
	$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName
	$nic.NetworkSecurityGroup = $nsg
	Set-AzNetworkInterface -NetworkInterface $nic
	
	# Set password
    $secPassword = ConvertTo-SecureString $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($userName, $secPassword)
	Set-AzVMAccessExtension -ResourceGroupName $resourceGroupName -VMName $virtualMachineName -Name "PasswordReset" -Location $vm.Location -Credential $cred
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
	$id = $i.ToString()
	createClonedVm -id $id
}

"Summary of VMs Created:" | Out-File -FilePath ".\summary.txt"

for ($i=$startAt; $i -lt $endVal; $i++)
{
	$virtualMachineName = $vmNamePrefix + "_" + $i.toString()

	# Print VM IP Address
	$nic = Get-AzNetworkInterface -Name ($VirtualMachineName.ToLower()+'_nic') -ResourceGroupName $resourceGroupName

	$publicIpId = $nic.IpConfigurations[0].PublicIpAddress.Id
    $publicIp = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name ($publicIpId.Split('/') | Select-Object -Last 1)
    $publicIpAddress = $publicIp.IpAddress
    Write-Host "Public IP Address: $publicIpAddress"
	$summary = "Created VM $virtualMachineName. IP Address$s $publicIpAddress"
	Write-Host $summary
	$summary | Out-File -FilePath ".\summary.txt" -Append

}

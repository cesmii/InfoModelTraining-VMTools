# Pre-flight checks
$configPath = "$PSScriptRoot\config.ps1"
if (-not (Test-Path $configPath)) {
    Write-Error "ERROR: config.ps1 not found!"
    Write-Host ""
    Write-Host "Please follow these steps:"
    Write-Host "1. Copy config-example.ps1 to config.ps1"
    Write-Host "2. Edit config.ps1 and set the subscriptionid, username and password"
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

# Select the subscription
Select-AzSubscription -SubscriptionId $subscriptionId | Out-Null

Write-Host ""
Write-Host "==================================================================="
Write-Host "VM Clones in Resource Group: $resourceGroupName"
Write-Host "==================================================================="
Write-Host ""

# Get all VMs in the resource group, excluding the source template VM and InfoModelTools
$vms = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object { $_.Name -ne $sourceVmName -and $_.Name -ne "InfoModelTools" } | Sort-Object -Property Name

if ($vms.Count -eq 0) {
    Write-Host "No VM clones found in resource group '$resourceGroupName'"
    Write-Host ""
    exit 0
}

# Create array to hold VM information
$vmList = @()

foreach ($vm in $vms) {
    $vmName = $vm.Name

    # Get the network interface
    $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
    $nicName = ($nicId.Split('/') | Select-Object -Last 1)

    try {
        $nic = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName -ErrorAction Stop

        # Get public IP if it exists
        $publicIpAddress = "N/A"
        if ($nic.IpConfigurations[0].PublicIpAddress) {
            $publicIpId = $nic.IpConfigurations[0].PublicIpAddress.Id
            $publicIpName = ($publicIpId.Split('/') | Select-Object -Last 1)
            $publicIp = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName -ErrorAction SilentlyContinue
            if ($publicIp -and $publicIp.IpAddress) {
                $publicIpAddress = $publicIp.IpAddress
            }
        }
    }
    catch {
        $publicIpAddress = "Error retrieving IP"
    }

    # Get creation time from the VM's tags or OS disk
    $creationTime = "N/A"
    if ($vm.TimeCreated) {
        $creationTime = $vm.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
    }

    # Add to list
    $vmList += [PSCustomObject]@{
        Name = $vmName
        PublicIP = $publicIpAddress
        Status = $vm.PowerState
        Created = $creationTime
    }
}

# Display the results in a formatted table
$vmList | Format-Table -Property Name, PublicIP, Status, Created -AutoSize

Write-Host ""
Write-Host "Total VM clones found: $($vmList.Count)"
#Write-Host ""
#Write-Host "Note: Template VM '$sourceVmName' and 'InfoModelTools' are excluded from this list"
Write-Host ""

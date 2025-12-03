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
    Write-Host "  - subscriptionId"
    Write-Host "  - userName"
    Write-Host "  - password"
    Write-Host ""
    exit 1
}

# Check for RDP template file
$rdpTemplatePath = "$PSScriptRoot\InfoModelTrainingVM.rdp"
if (-not (Test-Path $rdpTemplatePath)) {
    Write-Error "ERROR: InfoModelTrainingVM.rdp template file not found!"
    Write-Host ""
    Write-Host "Please ensure InfoModelTrainingVM.rdp exists in the same directory as this script."
    Write-Host ""
    exit 1
}

# Select the subscription
Select-AzSubscription -SubscriptionId $subscriptionId | Out-Null

# Create output folder with date format YY-MM-DD_RDP
$dateString = Get-Date -Format "yy-MM-dd"
$outputFolder = "$PSScriptRoot\${dateString}_RDP"

if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
    Write-Host "Created output folder: $outputFolder"
} else {
    Write-Host "Using existing output folder: $outputFolder"
}

Write-Host ""
Write-Host "==================================================================="
Write-Host "Generating RDP files for VM clones"
Write-Host "==================================================================="
Write-Host ""

# Get all VMs in the resource group, excluding the source template VM and InfoModelTools
$vms = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object { $_.Name -ne $sourceVmName -and $_.Name -ne "InfoModelTools" } | Sort-Object -Property Name

if ($vms.Count -eq 0) {
    Write-Host "No VM clones found in resource group '$resourceGroupName'"
    Write-Host ""
    exit 0
}

# Read the RDP template
$rdpTemplate = Get-Content $rdpTemplatePath -Raw

$successCount = 0
$failCount = 0

foreach ($vm in $vms) {
    $vmName = $vm.Name

    # Extract the numerical suffix from the VM name
    # Expected format: <prefix>_<number>
    if ($vmName -match "_(\d+)$") {
        $vmSuffix = $matches[1]
    } else {
        Write-Warning "Could not extract numerical suffix from VM name: $vmName. Skipping..."
        $failCount++
        continue
    }

    # Get the network interface
    $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
    $nicName = ($nicId.Split('/') | Select-Object -Last 1)

    try {
        $nic = Get-AzNetworkInterface -ResourceGroupName $resourceGroupName -Name $nicName -ErrorAction Stop

        # Get public IP if it exists
        $publicIpAddress = $null
        if ($nic.IpConfigurations[0].PublicIpAddress) {
            $publicIpId = $nic.IpConfigurations[0].PublicIpAddress.Id
            $publicIpName = ($publicIpId.Split('/') | Select-Object -Last 1)
            $publicIp = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName -ErrorAction SilentlyContinue
            if ($publicIp -and $publicIp.IpAddress) {
                $publicIpAddress = $publicIp.IpAddress
            }
        }

        if (-not $publicIpAddress) {
            Write-Warning "No public IP found for VM: $vmName. Skipping..."
            $failCount++
            continue
        }

        # Replace the placeholder with actual IP address
        $rdpContent = $rdpTemplate -replace "<IPADDRESS>", $publicIpAddress

        # Create output file name
        $outputFileName = "InfoModelTrainingVM_$vmSuffix.rdp"
        $outputFilePath = Join-Path $outputFolder $outputFileName

        # Write the RDP file
        $rdpContent | Out-File -FilePath $outputFilePath -Encoding ASCII -Force

        Write-Host "✓ Created: $outputFileName (IP: $publicIpAddress)"
        $successCount++
    }
    catch {
        Write-Warning "Error processing VM $vmName : $_"
        $failCount++
    }
}

Write-Host ""
Write-Host "==================================================================="
Write-Host "Summary"
Write-Host "==================================================================="
Write-Host "RDP files created: $successCount"
if ($failCount -gt 0) {
    Write-Host "Failed: $failCount" -ForegroundColor Yellow
}
Write-Host ""

# Zip the folder if any files were created
if ($successCount -gt 0) {
    Write-Host "Compressing RDP files into zip archive..."

    $zipFileName = "${dateString}_RDP.zip"
    # Place zip file in parent directory for easier access
    $parentDir = Split-Path $PSScriptRoot -Parent
    $zipFilePath = Join-Path $parentDir $zipFileName

    # Remove existing zip file if it exists
    if (Test-Path $zipFilePath) {
        Remove-Item $zipFilePath -Force
    }

    try {
        # Create zip archive
        Compress-Archive -Path "$outputFolder\*" -DestinationPath $zipFilePath -CompressionLevel Optimal

        # Delete the folder after successful zipping
        Remove-Item $outputFolder -Recurse -Force

        Write-Host "✓ Created zip file in parent directory: $zipFileName"
        Write-Host ""
        Write-Host "Download the zip file from Azure Cloud Shell:"
        Write-Host "  1. Go to Manage files -> Download"
        Write-Host "  2. Enter: $zipFileName"
        Write-Host ""
    }
    catch {
        Write-Warning "Failed to create zip file: $_"
        Write-Host "RDP files are still available in folder: $outputFolder"
        Write-Host ""
    }
} else {
    Write-Host "No RDP files were created."
    Write-Host ""
}

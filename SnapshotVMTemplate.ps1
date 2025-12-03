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

# Snapshot Creation
$sourceVm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $sourceVmName
$snapshotconfig = New-AzSnapshotConfig -SourceUri $sourceVm.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption Copy -EncryptionSettingsEnabled $false
New-AzSnapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName -Snapshot $snapshotconfig


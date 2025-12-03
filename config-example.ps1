# Configuration file for InfoModel Training VM Tools
# All scripts should source this file to use shared configuration

# Azure Subscription and Resource Group
$subscriptionId = "<SET_THIS_VALUE>"
$resourceGroupName = "InfoModelCourse"
$location = "East US 2"

# Base VM and Snapshot Configuration
$sourceVmName = "InfoModelTrainingTemplate"
$snapshotName = "InfoModelTrainingTemplate_snapshot_fromstopped"

# VM Deployment Configuration
$virtualNetworkName = "InfoModelTrainingTemplate-vnet"
$virtualMachineSize = "Standard_B4ms"
$diskSize = "128"
$storageType = "Standard_LRS"

# VM Credentials
$userName = "<SET_THIS_VALUE>"
$password = "<SET_THIS_VALUE>"

# Encrypted password for RDP files (optional)
# Generate this on a Windows machine using the EncryptPassword.ps1 helper script
# If not set, users will need to enter password manually when connecting to VMs
$encryptedPassword = ""

# VM Naming Pattern (used in all scripts)
# VMs will be named: InfoModelTraining_<id>
$vmNamePrefix = "InfoModelTraining"

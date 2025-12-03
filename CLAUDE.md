# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains PowerShell scripts for managing Azure VM clones for InfoModel Training courses. The scripts automate the process of creating VM snapshots, deploying multiple VM instances from those snapshots, and cleaning up VMs when no longer needed.

## Initial Setup

**IMPORTANT:** Before running any scripts, you must configure your credentials:

1. Copy `config-example.ps1` to `config.ps1`:
   ```powershell
   cp config-example.ps1 config.ps1
   ```

2. Edit `config.ps1` and set your credentials:
   - Replace `<SET_THIS_VALUE>` for `userName`
   - Replace `<SET_THIS_VALUE>` for `password`
   - Review and update other settings as needed

3. **Never commit `config.ps1`** to version control (it should be in .gitignore)

All scripts include pre-flight checks that will:
- Verify `config.ps1` exists
- Ensure no placeholder values (`<SET_THIS_VALUE>`) remain
- Exit with clear error messages if misconfigured

## Architecture

The system consists of a shared configuration file and four main PowerShell scripts that interact with Azure resources:

### config.ps1 (and config-example.ps1)
Central configuration file containing all shared variables used across the scripts. All scripts source this file at startup using `. "$PSScriptRoot\config.ps1"`.

**Configuration pattern:**
- `config-example.ps1` is the template (committed to version control)
- `config.ps1` is your local copy with real credentials (excluded from version control)

**Configuration variables:**
- Azure subscription ID and resource group
- Base VM name and snapshot name
- VM deployment settings (size, disk size, network)
- VM credentials (username and password)
- VM naming prefix

**Important - VM Size and Temporary Storage:**
The default VM size is `Standard_B4ms` which includes 300 GiB of temporary storage (local SSD) to maintain performance parity with the base template VM.

To modify any configuration (e.g., snapshot name, VM size, credentials), edit `config.ps1` rather than individual scripts.

### SnapshotVMTemplate.ps1
Creates a snapshot of the base VM template to be used for cloning. This is the first step when the base VM has been updated and needs to be propagated to training VMs. Uses configuration from config.ps1.

Includes pre-flight checks for config.ps1 existence and validation.

### CloneVMTemplate.ps1
Creates multiple VM instances from a snapshot. Each VM gets its own complete set of Azure resources:
- Managed disk (cloned from snapshot)
- Public IP address (static allocation)
- Network interface
- Network security group with RDP rule (port 3389)
- VM with boot diagnostics storage account

**Parameters:**
- `-numClones <int>`: Number of VMs to create
- `-startAt <int>`: Optional starting index (default: 0)

**Output:**
- Creates `summary.txt` with VM names and their public IP addresses

All VM configuration (size, disk, network, credentials) is loaded from config.ps1.

Includes pre-flight checks for config.ps1 existence and validation.

### ListVMClones.ps1
Lists all VM clones in the resource group with their details. Provides a quick overview of deployed training VMs.

**Output displays:**
- VM name
- Public IP address
- Power state (running/stopped)
- Creation date and time

The template VM (specified by `$sourceVmName`) is automatically excluded from the list.

Includes pre-flight checks for config.ps1 existence and validation.

### DeleteVMClones.ps1
Removes VM clones and all associated resources to clean up the environment. Uses configuration from config.ps1 to identify resource names.

Includes pre-flight checks for config.ps1 existence and validation.

**Parameters:**
- `-numClones <int>`: Number of VMs to delete
- `-startAt <int>`: Optional starting index (default: 0)

**Resources deleted per VM:**
- VM instance
- OS managed disk
- Network interface
- Network security group
- Public IP address
- Boot diagnostics storage account

## Common Commands

All scripts are designed to be run from **Azure Cloud Shell (PowerShell)**. Upload both `config.ps1` and the required script(s) via the portal interface before running commands.

**One-time setup in Azure Cloud Shell:**
```powershell
# Copy the example config and edit it
cp config-example.ps1 config.ps1
# Use the Cloud Shell editor to set credentials
code config.ps1
```

### Create new snapshot from base VM:
```powershell
./SnapshotVMTemplate.ps1
```

### Deploy 10 VMs starting at index 0:
```powershell
./CloneVMTemplate.ps1 -numClones 10
```

### Deploy 10 VMs starting at index 5 (creates VMs 5-14):
```powershell
./CloneVMTemplate.ps1 -numClones 10 -startAt 5
```

### List all VM clones with IP addresses and creation dates:
```powershell
./ListVMClones.ps1
```

### Delete VMs 0-9:
```powershell
./DeleteVMClones.ps1 -numClones 10
```

### Delete VMs 5-14:
```powershell
./DeleteVMClones.ps1 -numClones 10 -startAt 5
```

### Download VM summary:
In Azure Cloud Shell, go to Manage files -> Download, then type `summary.txt`

## Resource Naming Conventions

All Azure resources follow consistent naming patterns based on the VM index. The naming prefix is defined in config.ps1 (`$vmNamePrefix`):

- VM: `<vmNamePrefix>_<id>`
- Disk: `<vmNamePrefix>_ClonedOSDisk_<id>`
- NIC: `<vmNamePrefix lowercase>_<id>_nic`
- NSG: `<vmNamePrefix lowercase>_<id>_nic_nsg`
- Public IP: `<vmNamePrefix lowercase>_<id>_ip`
- Storage Account: Auto-generated by Azure for boot diagnostics

## Workflow

**First-time setup:**
1. Upload all `.ps1` files to Azure Cloud Shell
2. Copy `config-example.ps1` to `config.ps1`
3. Edit `config.ps1` to set credentials and review settings
4. Proceed with workflows below

**When base VM has changed:**
1. Update snapshot name in config.ps1 (`$snapshotName`) if needed
2. Run `./SnapshotVMTemplate.ps1` to create new snapshot
3. Run `./CloneVMTemplate.ps1 -numClones <count>` to create training VMs
4. Download summary.txt for VM details

**When base VM has not changed:**
1. Run `./CloneVMTemplate.ps1 -numClones <count>` to create VMs from existing snapshot
2. Use `-startAt` parameter if VMs are already deployed (e.g., `-numClones 5 -startAt 10`)
3. Download summary.txt for VM details

**To clean up:**
1. Run `./DeleteVMClones.ps1 -numClones <count>` to delete VMs
2. Use `-startAt` parameter to specify which VMs to delete
3. Ensure index ranges match the VMs you want to delete

**Configuration changes:**
All environment-specific settings (Azure subscription, resource names, VM sizes, credentials, etc.) are centralized in config.ps1. Modify this file when environment settings change.

**Security note:**
The config.ps1 file contains sensitive credentials and should never be committed to version control. Always use config-example.ps1 as the template for new environments.

## Important Notes

### Temporary Storage Requirements
Cloned VMs require temporary storage (local SSD) to match the performance of the base template VM. The configured VM size `Standard_B4ms` includes:
- 30 GiB temporary storage disk (typically D: drive on Windows)
- 19,000 IOPS and 250 MBps throughput
- Critical for page file, temp files, and application caching

If you need to change VM sizes, verify the new size includes temporary storage to avoid performance degradation.

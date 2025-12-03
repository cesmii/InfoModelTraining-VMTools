# Training VM Tools

Upload these scripts to your Azure Cloud Shell. Ensure you are in PowerShell (not Bash) mode.

Copy `config-example.ps1` to `config.ps1`.

## config.ps1

Check and update config.ps1 for variables that apply to all scripts.

Set the subscription id in the Azure Subscription section (find this in the header of almost any resource in the Azure portal).

Set the username and password in the VM Credentials section (see Sharepoint).

## SnapshotVMTemplate.ps1

This script takes the snapshot of the template VM. It uses the filenames in config.ps1

Run: `./SnapshotVMTemplate.ps1` to grab a snapshot for cloning.

## CloneVMTemplate.ps1

This script uses the snapshot created by SnapshotVMTemplate and creates as many clones as you wish.

Each clone is assigned a unique numerical suffix, starting at 0.

It accepts the arguments:
- numClones
- startAt

For example, to create 10 clones, run: `./DeployVM.ps1 -numClones 10`

To deploy 5 clones, starting at 5 ending at 9, run: `./DeployVm.ps1 -numClones 5 -startAt 5`

## ListVMClones.ps1

This script lists all cloned VMs in the resource group, showing their public IP addresses and creation dates. The template VM is automatically excluded from the list.

Run: `./ListVMClones.ps1` to view all VM clones.

## GenerateRDPFiles.ps1

This script generates RDP connection files for all cloned VMs using the InfoModelTrainingVM.rdp template. Each RDP file is configured with the correct public IP address for its corresponding VM.

The script:
- Creates RDP files for all VM clones
- Replaces `<IPADDRESS>` in the template with actual public IPs
- Names files with the VM's numerical suffix (e.g., InfoModelTrainingVM_0.rdp, InfoModelTrainingVM_1.rdp)
- Compresses all files into a date-stamped zip archive (e.g., 25-12-03_RDP.zip)
- Automatically deletes the temporary folder after zipping

Run: `./GenerateRDPFiles.ps1` to generate and zip RDP files for all VM clones.

## DeleteVMClones.ps1

This script deletes cloned VMs.

It accepts the arguments:
- numClones
- startAt
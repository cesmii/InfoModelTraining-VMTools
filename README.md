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

## DeleteVMClones.ps1

This script deletes cloned VMs. 

It accepts the arguments:
- numClones
- startAt

<#PSScriptInfo
.VERSION 1.0
.AUTHOR Seth Golden 
.RELEASENOTES
Version 1.0:  Original published version.
#>

# This script is simple -- grab a script from Azure Storage, then send it to the endpoint -- tested on AVDs, but it'll work for VMs in general too.
# If you need to do more complicated work on the endpoint like have it pull other items from storage, you want the script on the other end to be more complex.
# In that case, have it use a SAS token and periodically update that script.

# Prerequisites:
# use a service principal (the example assumes that this is being used -- it is a great practice) -- store the credential as an Azure Automation variable. (Can also retrieve from key vault.)
# storage account
# need to know what your targets are going to be. For Azure Automation, I was successfully able to target multiple virtual desktops as long as they were in a specific format:
# $targets format: ['avd_name-1','avd_name-2','avd_name-3']

# Again, this is just intended to be a simple script. A more complex one would be dynamic and look for devices that are missing extensions, then run them -- or poll devices in some other fashion.

Param (
	[Parameter(Mandatory=$false)]
	[string[]] $targets
)


Write-Output "Grabbing credentials."

# grab sp credential
$mycred = Get-AutomationPSCredential -Name "service_principal"

# grab subscription variable
$subscription = Get-AutomationVariable -Name "subscription"

# grab tenant variable
$tenant = Get-AutomationVariable -Name "tenant"

# connect to Azure with SP
Connect-AzAccount -ServicePrincipal -Credential $mycred -Tenant $tenant -Subscription $subscription

Write-Output "Targeting the following targets:"

Foreach($target in $targets){
	Write-Output $target
	}

# need to know the resource group of the VM(s). This assumes all VMs are in the same resource group.
$resourceGroup = <your_resource_group>


# now grab data from the storage account.

$containername = <your_storage_container>
$account = <your_storage_account>
$filename = <your_script_here.ps1>

# this is the actual geographical location. As an example, this would be "East US"
$location = <location_of_VM>

# the extension can be named anything -- you'll see it in the VM afterwards. Call it something that you'd expect to call it.
# for example, if this is a script to install some sort of agent, it'd probably be a good idea to call this "Agent Installer"

$name = <name_of_extension>
$storageaccountkey = Get-AutomationVariable -Name <your_storage_account_key>

# now run this in parallel on each VM -- the -NoWait switch will do that.

Foreach($target in $targets){
	Set-AzVMCustomScriptExtension -ResourceGroupName $resourcegroup `
	-VMName $target `
	-Location $location `
	-StorageAccountName $account `
	-StorageAccountKey $accountkey `
	-ContainerName $containername `
	-FileName $filename `
	-Name $name `
	-NoWait `
	-Verbose
	}



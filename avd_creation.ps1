<#PSScriptInfo

VERSION 1.0
.AUTHOR Seth Golden 
.RELEASENOTES
Version 1.0:  Original published version.
#>

# This script is an example script showing how one can connect up to their Azure tenant via a script in order to generate new virtual desktops in an EXISTING pool.

# Prerequisites:
# use a service principal (the example assumes that this is being used -- it is a great practice)
# encrypted password information exists for the service principal. This is done using PowerShell and AES 256 encryption, accessing those creds in a secured folder.
# the host pool MUST already exist
# JSON templates and parameters files have already been exported from Azure for use here
# You've already installed the proper Az modules 



Param (
	[Parameter(Mandatory=$false)]
	$instances = "1"
)

$filedatetime = Get-Date -Format FileDateTime
$logfile = "C:\Somefolder\vdi_creation_$filedatetime.log"
If($logfile){
	# do nothing
	}
Else{
	New-Item $logfile -ItemType File -Force
	}

# create transcript for debugging purposes

Start-Transcript $logfile

#import the module

Write-Host "Importing Az module."
Import-Module Az -Force

# instances parameter read back to screen

Write-Host "Creating this many AVDs: $instances."

# connect to AZ account with secured credentials
# Identify the AES keyfile located in a secured folder

$keyfile
$key = Get-Content $keyfile

# identify the encrypted password created with the above AES key file in a secured folder
$pfile

# identifier of the service principal itself
$spn

# create a PScredential object to use all of the above
$mycreds = New-Object System.Management.Automation.PSCredential -ArgumentList $spn, (Get-Content $pfile | ConvertTo-SecureString -key $key)

# define the tenant and subscription
$aztenant
$azsubscription

# connect to Azure PowerShell, first
Write-Host "Connecting to Azure."
Connect-AzAccount -ServicePrinicipal -Credential $mycreds -Tenant $aztenant -Subscription -azsubscription -Verbose

# next, connect to Azure CLI, which does some things that the Az PowerShell module does not do
Write-Host "Connecting to Azure CLI."
az login --service-principal -u $mycreds.UserName -p $mycreds.GetNetworkCredential().Password --tenant $aztenant

# if necessary, you can also swap subscriptions with this command
az account set -s $subscription

# pull the JSON template you've previously exported from "manually" building a new AVD in this host pool.
# this template should also be in a secured location to prevent changes to it

$templatefile

# pull the JSON parameters file that is associated with the above template. Combined with the JSON template above, it will set all of the values needed for creation.
# mainly this contains host pool information and a standard setup within that pool -- vCPUs, networks, etc.

$paramfile

# hostpool subscription -- where is the host pool located?
$hostpoolSubscription

# resource group -- where is the host pool / other resources located?
$resourceGroup

# name of the host pool
$hostpoolName

# Now we want to pull a registration token. There's no need to do this manually.
# This snippet will look first to see if there's already an active registration token. If so, it will use that token.
# If there is not an active registration token, then one will be created and will expire within a short period of time.

Write-Host "Pulling registration info.

# store this info in a variable
$registered = Get-AzwvdRegistrationInfo -SubscriptionID $hostpoolSubscription -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName -Verbose
$now = Get-Date

# if there is NO expiration time (meaning no current token) or the expiration time of the token it DID find was <= to NOW, it's time to get that new token
If(($null -eq $registered.ExpirationTime) -or ($registered.ExpirationTime -le ($now))) {
	# generate a token for this host pool in this resource group -- expiration time is set to 1 hour from now
	# we're overwriting the above variable $registered because there's no token
	$registered = New-AzWvdRegistrationInfo -SubscriptionId $hostpoolSubscription -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName -ExpirationTime $((Get-Date).ToUniversalTime().AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')) -Verbose 
	}

# do we have a token?
If($registered.Token){
	Write-Host "Found token."
	Write-Host "Creating secured key."
	# convert the token to a secure string so that it can be used.
	$registered.Token | ConvertToSecureString -AsPlainText -Force
}

# since we're creating a new host within a host pool, a number is appended to the VM name.
# the below snippet will grab existing host pool session hosts, determine how many are present, get their assigned "numbers", then automatically add one more number to the topmost number.
# There's probably other ways to do this but it worked well enough in my use cases.

Write-Host "Get hostpool information to determine where to start."
# Get current sessionhost information

$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName

# This also assumes you have a hybrid-joined VM. Include your domain in that case because the script will strip that part out for you.
$domain

# Do a quick check first -- no reason to start at a specific number if you don't have any hosts in the pool yet, or if you've recently decommissioned every host in the pool.
If($null -eq $sessionHosts){
	Write-Host "No sessionhosts found in hostpool $hostpoolname. Setting initialnumber to 0."
	$vmInitialNumber = "0"
}
Else{
	# create an array object first
	$hostarray = New-Object TypeName "System.Collections.ArrayList"
	# for each sessionhost in the existing pool, add to the array object
	Foreach($item in $sessionHosts){
		# split the name string to get the hostname first
		$hostname = $item.Name.Split("/")[1]
		# this splits the number from the hostname so that you ONLY get the number
		[int]$hostnum = $hostname.TrimEnd($domain).Split("-")[2]
		# add that number to the array created above
		[void]$hostarray.Add($hostnum)
		}
	# now, let PowerShell do the math and sorting for you. Sort the array by number and find the highest number.
	$top = $hostarray | Sort-Object -Descending | Select-Object -First 1
	# now that we have the highest number, add one number to that
	$hostarrayplus = $top + 1
	# this makes sure to pass that number through as an integer
	$vmInitialNumber = [int]$hostarrayplus
	Write-Host "Starting at $vmInitialNumber for this build."
}

# store info on hosts CURRENTLY in the pool for comparison later, if needed.
# this assumes that other VMs are not being built at the same time. If for some reason that is the case, it can be scripted around.

Write-Host "Creating VMs, but first capturing which devices are there vs what will be present later after building new ones."

$prev = (Get-AzVM -ResourceGroupName $resourceGroup).Name

# once connected, pull secured passwords from shares

# get the encrypted join domain account / pwd for the vm from secured share
$vmadmf

#get the content of the pwd
vmadmp = (Get-Content $vmadmf | ConvertTo-SecureString -key $key)

#encrypted admin password for the VM (later taken over by LAPS if you have LAPS implemented in your environment)
$admf

# get the content of the pwd
$admp = (Get-Content $admf | ConvertTo-SecureString -key $key)

# now identify the deployment, helps to find it later if you ever need to
$deployname = "deployer_$filedatetime"

# use parameters to determine what to do here
# target the templatefile, paramfile, token for registration to the host pool, vm admin password for joining to domain, local admin pwd, instances from parameter, and initial number to use
$datadump = New-AzResourceGroupDeployment -Name $deployname -ResourceGroupName $resourceGroup `
			-TemplateFile $templateFile `
			-TemplateParameterFile $paramfile `
			-HostPoolToken $token `
			-vmAdministratorAccountPassword $vmadmp `
			-administratorAccountPassword $admp `
			-vmNumberOfInstances $instances `
			-vmInitialNumber $vmInitialNumber ` `
			-Verbose

# if there's a failure, exit. You can notify in several ways.

If($datadump.ProvisioningState -eq "Failed"){
	Write-Host "Failure detected. Yeet this bad boy back to the creation team for review."
	Exit
	}

# now compare your current VMs in the resource group to the VMs that were there before.

$current = (Get-AzVM -ResourceGroupName $resourceGroup).Name
$newvms = @()

Foreach($vm in $current){
	If($prev -notcontains $vm){
		Write-Host "Found $vm as a new device."
		# use the az vm commands to get any ip addresses from Azure, instead of relying on DNS resolution.
		$ip = az vm list-ip-addresses -g $resourceGroup -n $vm
		$jsonip = $ip | ConvertFrom-Json
		$realip = $jsonip.virtualMachine.network.privateIpAddresses
		$PSObject = New-Object PSObject -Property @{
			SessionHost = $session
			IP = $realip
			} | Select-Object SessionHost,IP
		$newvms += $PSObject
		}
	}

Stop-Transcript
Exit
	

$mycreds = New-Object

<#PSScriptInfo
.VERSION 1.0
.AUTHOR Seth Golden 
.RELEASENOTES
Version 1.1:  Original published version.
#>

# This script is similar to the local script -- the main differences here are using it in Azure Automation, which is much more streamlined.

# Prerequisites:
# use a service principal (the example assumes that this is being used -- it is a great practice) -- store the credential as an Azure Automation variable. (Can also retrieve from key vault.)
# the host pool MUST already exist
# JSON templates and parameters files have already been put into Azure Storage

Param (
	[Parameter(Mandatory=$false)]
	$instances = "1"
)

Write-Output "Creating this many AVDs: $instances."

Write-Output "Grabbing credentials."

# grab sp credential
$mycred = Get-AutomationPSCredential -Name "service_principal"

# grab subscription variable
$subscription = Get-AutomationVariable -Name "subscription"

# grab tenant variable
$tenant = Get-AutomationVariable -Name "tenant"

# connect to Azure with SP
Connect-AzAccount -ServicePrincipal -Credential $mycred -Tenant $tenant -Subscription $subscription

# define resource group and host pool name

$resourceGroup = <your_resource_group>
$hostpoolName = <your_hostpool_name>

# Now we want to pull a registration token. There's no need to do this manually.
# This snippet will look first to see if there's already an active registration token. If so, it will use that token.
# If there is not an active registration token, then one will be created and will expire within a short period of time.

$registered = Get-AzwvdRegistrationInfo -SubscriptionID $subscription -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName -Verbose
$now = Get-Date
# if there is NO expiration time (meaning no current token) or the expiration time of the token it DID find was <= to NOW, it's time to get that new token
If(($null -eq $registered.ExpirationTime) -or ($registered.ExpirationTime -le ($now))) {
	# generate a token for this host pool in this resource group -- expiration time is set to 1 hour from now
	# we're overwriting the above variable $registered because there's no token
	$registered = New-AzWvdRegistrationInfo -SubscriptionId $subscription -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName -ExpirationTime $((Get-Date).ToUniversalTime().AddHours(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')) -Verbose 
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

# Get current sessionhost information

$sessionHosts = (Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName).Name

Write-Output $sessionHosts

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

Write-Output "Creating VMs."

# now grab data from the storage account.

$container = <your_storage_container>
$account = <your_storage_account>
$blob1 = <your_template.json file>
$blob2 = <your_parameters.json file>
$storageaccountkey = Get-AutomationVariable -Name <your_storage_account_key>

# establish the storage context
$context = New-AzureStorageContext -StorageAccountName $account -StorageAccountKey $storageaccountkey -Verbose

# grab the template and temporarily store in the sandbox
Try{
    Get-AzurestorageBlob -Container $container -blob $blob1 -Context $context | Get-AzureStorageBlobContent -Destination C:\Temp
}
Catch{
    $_
  }
 Try{
 	Get-AzurestorageBlob -Container $container -blob $blob2 -Context $context | Get-AzureStorageBlobContent -Destination C:\Temp
	}
Catch{
	$_
	}

# define the json template locations for use
$template = "C:\temp\$blob"
$paramfile = "C:\temp\$blob2"

# get the credentials (already stored) for the local admin account and join domain account for the virtual desktop
$vmadm = Get-AutomationPSCredential -Name "local_admin"
$adm = Get-AutomationPSCredential -Name "join_domain"

# define a name for the deployment and create a filedatetime variable to append.

$filedatetime = Get-Date -Format FileDateTime
$deployname = "avd_deploy_for_hostpool_$filedatetime"

# target the templatefile, paramfile, token for registration to the host pool, vm admin password for joining to domain, local admin pwd, instances from parameter, and initial number to use
$deployer = New-AzResourceGroupDeployment -Name $deployname -ResourceGroupName $resourceGroup `
			-TemplateFile $templateFile `
			-TemplateParameterFile $paramfile `
			-HostPoolToken $token `
			-vmAdministratorAccountPassword $vmadmp.Password `
			-administratorAccountPassword $admp.Password `
			-vmNumberOfInstances $instances `
			-vmInitialNumber $vmInitialNumber ` `
			-Verbose

# this can be cleaner output but the below also works well enough -- ideally you would have this tied to Logic Apps and have it notify on failures

If($deployer.ProvisioningState -eq "Failed"){
	Write-Error "Failure detected. Yeet this bad boy back to the creation team for review."
	Exit
}

# determine what your new adds were -- for any deployment after, such as with an extension script

$current = (Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName).Name

# subtract current devices from previous devices if you want

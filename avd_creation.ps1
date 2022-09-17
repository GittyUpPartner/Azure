# This script is an example script showing how one can connect up to their Azure tenant via a script in order to generate new virtual desktops in an EXISTING pool.

# Prerequisites:
# use a service principal (the example assumes that this is being used -- it is a great practice)
# encrypted password information exists for the service principal. This is done using PowerShell and AES 256 encryption, accessing those creds in a secured folder.
# the host pool MUST already exist
# JSON templates and parameters files have already been exported from Azure for use here



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

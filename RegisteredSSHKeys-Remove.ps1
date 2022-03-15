param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function RegisteredSSHKeys-Remove {
<#
.SYNOPSIS
    Removes SSH keys from the ssh-agent.
.DESCRIPTION
    RegisteredSSHKeys-Remove unregisters SSH keys from the ssh-agent.
.NOTES
	Author: Helmut Janisch
	Copyright (c) 2022
	Released under the [MIT license](https://spdx.org/licenses/MIT#licenseText)
#>	
   [CmdletBinding()]
	param (
		# Show this help
		[Parameter(Mandatory=$False)]
		[switch]$help = $False,
		# Optional list of public SSH keys which will be removed from the ssh-agent.
		# If none specified, key names from a file named ssh_keys.config are 
		# loaded and used.
		# Example: RegisteredSSHKeys-Remove -keynames "key1.pub,key2.pub,key3.pub,.."
		[Parameter(ValueFromRemainingArguments=$true, Position=1)]
		[string[]]$keynames	
	)

	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}		
	
	if ($help) {
		Get-Help -Name RegisteredSSHKeys-Remove -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nUnregister SSH keys"
	Write-Output "-------------------`n"

	$sshAdd = "ssh-add"

	Write-Verbose "Checking for OpenSSH ..."
	$sshInstalled = Get-Command $sshAdd -ErrorAction SilentlyContinue

	if (!$sshInstalled) {
		Write-Error "OpenSSH is not installed. Please install OpenSSH for Windows and rerun this script again."
		Exit-Script $keyPress
	}
	else {
		Write-Verbose "OpenSSH is installed."
	}
	
	$sshKeysConfigFile = "ssh_keys.config"
	$sshKeys = @()

	if ($keynames.Count -eq 0) {
		Write-Verbose "No SSH keys to unregister specified via command line."
		Write-Verbose "Checking for SSH keys user config file $sshKeysConfigFile ..."
		
		if (Test-Path $sshKeysConfigFile -PathType leaf) {
			Write-Verbose "Reading SSH keys user config file $sshKeysConfigFile ..."
			$sshKeys = Get-Content $sshKeysConfigFile | Foreach {$_.Trim() + ".pub"} | where {$_ -ne ".pub"}
			Write-Output ("Found " + $sshKeys.Count + " SSH keys to unregister in user config file $sshKeysConfigFile.")
		} else {
			Write-Output "Could not find SSH keys user config file $sshKeysConfigFile."
		}	
	} else {
		Write-Output ("Found " + $keynames.Count + " SSH keys to unregister specified via command line.")
		foreach ($sshKey in $keynames) {
			$sshKeys += $sshKey
		}
	}	
	
	if ($sshKeys.Count -eq 0) {
		Write-Warning "No SSH keys found to unregister from ssh-agent."
		Exit-Script $keyPress
	}	
	
	foreach ($sshKey in $sshKeys) {
		if (Test-Path $sshKey -PathType leaf) {				
			Write-Output "`nUnregistering SSH key $sshKey from ssh-agent ..."
			
			& $sshAdd -d $sshKey 2>$null
			if ($LASTEXITCODE -ne 0) {
				Write-Error "Could not unregister SSH key $sshKey from ssh-agent."
			} else {			
				Write-Output "Unregistered SSH key $sshKey from ssh-agent."
			}
		}
		else {
			Write-Warning "Could not find SSH key file $sshKey."
		}
	}

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("RegisteredSSHKeys-Remove " + $cmdLine)

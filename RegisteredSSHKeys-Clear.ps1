param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function RegisteredSSHKeys-Clear {
<#
.SYNOPSIS
    Clear SSH keys registered with the ssh-agent.
.DESCRIPTION
    RegisteredSSHKeys-Clear removes all registered SSH keys from the ssh-agent.
.NOTES
	Author: Helmut Janisch
	Copyright (c) 2022
	Released under the [MIT license](https://spdx.org/licenses/MIT#licenseText)
#>	
   [CmdletBinding()]
	param (
		# Show this help
		[Parameter(Mandatory=$False)]
		[switch]$help = $False
	)

	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}
	
	if ($help) {
		Get-Help -Name RegisteredSSHKeys-Clear -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nClear registered SSH keys"
	Write-Output "-------------------------`n"

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

	Write-Verbose "Removing registered SSH keys from ssh-agent ..."
	& $sshAdd -D 2>$null
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Could not remove registered SSH keys from ssh-agent."
	} else {			
		Write-Output "Removed registered SSH keys from ssh-agent."
	}

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("RegisteredSSHKeys-Clear " + $cmdLine)

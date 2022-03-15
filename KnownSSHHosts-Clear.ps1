param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function KnownSSHHosts-Clear {
<#
.SYNOPSIS
    Deletes all trusted SSH hosts from known hosts file
.DESCRIPTION
    KnownSSHHosts-Clear removes all authorized SSH hosts from known hosts file.
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
		# Optional custom known SSH hosts file
		# If none specified, the location of the known SSH host file is obtained from the ssh agent
		[Parameter(Mandatory=$False)]
		[string]$knownhostsfile = $null,
		# Skip creating a backup of the known SSH hosts file
		[Parameter(Mandatory=$False)]
		[switch]$nobackup = $False
	)

	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}	
	
	if ($help) {
		Get-Help -Name KnownSSHHosts-Clear -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nClear known SSH hosts"
	Write-Output "---------------------`n"

	$ssh = "ssh"

	Write-Verbose "Checking for OpenSSH ..."
	$sshInstalled = Get-Command $ssh -ErrorAction SilentlyContinue

	if (!$sshInstalled) {
		Write-Error "OpenSSH is not installed. Please install OpenSSH for Windows and rerun this script again."
		Exit-Script $keyPress
	}
	else {
		Write-Verbose "OpenSSH is installed."
	}	

	if (!$knownhostsfile) {
		Write-Verbose "Checking for user known SSH hosts config file ..."
		$userKnownSSHHostsFileParts = ((& $ssh -G localhost | select-string '^userknownhostsfile') -split ' ')
		if ($LASTEXITCODE -ne 0 -or $userKnownSSHHostsFileParts.Count -le 2) {
			Write-Error "Could not find user known SSH hosts config file."
			Exit-Script $keyPress
		}
		$userKnownSSHHostsFile = $userKnownSSHHostsFileParts[1]
		
	} else {
		$userKnownSSHHostsFile = $knownhostsfile
	}
	
	Write-Verbose "Known SSH Hosts config file found at $userKnownSSHHostsFile."

	$userKnownSSHHostsBakFile = $userKnownSSHHostsFile + "_$((Get-Date).ToString('yyyyddMM_hhmmss')).bak"

	if (Test-Path $userKnownSSHHostsFile -PathType leaf) {
		if (-Not $nobackup) {
			$userKnownSSHHostsBakFile = $userKnownSSHHostsFile + "_$((Get-Date).ToString('yyyyddMM_hhmmss')).bak"
			Write-Verbose "Creating known SSH hosts backup config file $userKnownSSHHostsBakFile for known SSH hosts config file $userKnownSSHHostsFile ..."
			Copy-Item -Path $userKnownSSHHostsFile -Destination $userKnownSSHHostsBakFile -Force -Confirm:$False
			Write-Output "Created known SSH hosts backup config file $userKnownSSHHostsBakFile."
		}		
		
		Write-Verbose "Clearing known SSH hosts config file $userKnownSSHHostsFile ..."
		Clear-Content -Path $userKnownSSHHostsFile -Force -Confirm:$False
		Write-Output "Cleared known SSH hosts config file $userKnownSSHHostsFile."
	} else {
		Write-Warning "Could not find known SSH hosts config file $userKnownSSHHostsFile."
	}

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("KnownSSHHosts-Clear " + $cmdLine)


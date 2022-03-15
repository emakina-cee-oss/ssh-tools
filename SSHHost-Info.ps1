param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function SSHHost-Info {
<#
.SYNOPSIS
    Shows information about SSH hosts.
.DESCRIPTION
    SSHHost-Info displays information about SSH hosts.
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
		# Optional list of SSH hosts for which information will be shown
		# If none specified, host names from a file named ssh_hosts.config are 
		# loaded and used.
		# Example: SSHHost-Info -hostnames "github.com,gitlab.com,ip,.."
		[Parameter(ValueFromRemainingArguments=$true, Position=1)]
		[string[]]$hostnames,
		# Optional Timeout in seconds for retrieving the public key from the host.
		# Default timeout is 3 seconds.
		[Parameter(Mandatory=$False)]
		[int]$timeout = 3		
	)
	
	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}	
	
	if ($help) {
		Get-Help -Name SSHHost-Info -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nShow SSH Host Info"
	Write-Output "------------------`n"

	$sshKeyScan = "ssh-keyscan"

	Write-Verbose "Checking for OpenSSH ..."
	$sshInstalled = Get-Command $sshKeyScan -ErrorAction SilentlyContinue

	if (!$sshInstalled) {
		Write-Error "OpenSSH is not installed. Please install OpenSSH for Windows and rerun this script again."
		Exit-Script $keyPress
	}
	else {
		Write-Verbose "OpenSSH is installed."
	}

	$sshHostsConfigFile = "ssh_hosts.config"
	$sshHosts = @()

	if ($hostnames.Count -eq 0) {
		Write-Verbose "No SSH hosts specified via command line."
		Write-Verbose "Checking for SSH hosts user config file $sshHostsConfigFile ..."
		
		if (Test-Path $sshHostsConfigFile -PathType leaf) {
			Write-Verbose "Reading SSH hosts user config file $sshHostsConfigFile ..."
			$sshHosts = Get-Content $sshHostsConfigFile | Foreach {$_.Trim()} | where {$_ -ne "" }
			Write-Output ("Found " + $sshHosts.Count + " SSH hosts in user config file $sshHostsConfigFile.")
		} else {
			Write-Output "Could not find SSH hosts user config file $sshHostsConfigFile."
		}	
	} else {
		Write-Output ("Found " + $hostnames.Count + " SSH hosts specified via command line.")
		foreach ($hostname in $hostnames) {
			$sshHosts += $hostname
		}
	}

	if ($sshHosts.Count -eq 0) {
		Write-Warning "No SSH hosts found to show info."
		Exit-Script $keyPress
	}
	
	$md5Service = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	$sha256Service = New-Object -TypeName System.Security.Cryptography.SHA256CryptoServiceProvider
	
	foreach ($sshHost in $sshHosts) {
		Write-Output "`nFetching public SSH keys for host $sshHost ..."
		
		$fetchedSSHKeys = & $sshKeyScan -T $timeout $sshHost 2>$null
		
		if ($LASTEXITCODE -ne 0 -or !$fetchedSSHKeys) {
			Write-Error "Could not scan public SSH keys for host $sshHost."
		} else {
			Write-Verbose "Fetched public SSH keys for host $sshHost."
			
			foreach ($fetchedSSHKey in $fetchedSSHKeys) {
				
				$fetchedSSHKeyParts = $fetchedSSHKey -split " "
				if ($fetchedSSHKeyParts.Count -ne 3) {
					Write-Error "Could not parse public SSH keys for host $sshHost."
				}
				else {
					$hostname = $fetchedSSHKeyParts[0]
					$keyType = $fetchedSSHKeyParts[1]
					$thumbprint = $fetchedSSHKeyParts[2]
					
					$bin = [System.Convert]::FromBase64String($thumbprint)
					$md5 = [System.BitConverter]::ToString($md5Service.ComputeHash($bin)).Replace("-", ":").ToLower()
					$sha256 = [System.Convert]::ToBase64String($sha256Service.ComputeHash($bin)).TrimEnd("=")
					
					Write-Output "Host: $hostname"
					Write-Output "Key type: $keyType"
					Write-Output "Thumbprint: $thumbprint"
					Write-Output "Fingerprint MD5: $md5"
					Write-Output "Fingerprint SHA256: $sha256`n"
				}
			}
		}
	}

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("SSHHost-Info " + $cmdLine)

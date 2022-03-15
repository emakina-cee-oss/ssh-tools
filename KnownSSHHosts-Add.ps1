param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function KnownSSHHosts-Add {
<#
.SYNOPSIS
    Adds trusted SSH hosts to known hosts file
.DESCRIPTION
    KnownSSHHosts-Add pre-authorizes the system with public keys from the specified hosts
	by adding them to the known SSH hosts file.
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
		# Optional list of hosts which will be added to known hosts file.
		# If none specified, the host names from a file named ssh_hosts.config are loaded and used.
		# Example: KnownSSHHosts-Add -hostnames "github.com,gitlab.com,ip,.."
		[Parameter(ValueFromRemainingArguments=$true, Position=1)]
		[string[]]$hostnames,
		# Optional custom known SSH hosts file
		# If none specified, the location of the known SSH host file is obtained by the ssh agent
		[Parameter(Mandatory=$False)]
		[string]$knownhostsfile = $null,
		# Optional Timeout in seconds for retrieving the public key from the host.
		# Default timeout is 3 seconds.
		[Parameter(Mandatory=$False)]
		[int]$timeout = 3,
		# Skip creating a backup of the known SSH hosts file
		[Parameter(Mandatory=$False)]
		[switch]$nobackup = $False
	)
	
	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}		
	
	if ($help) {
		Get-Help -Name KnownSSHHosts-Add -Detailed
		Exit-Script $keyPress
	}	

	Write-Output "`nAdd known SSH hosts"
	Write-Output "-------------------`n"
	
	$sshKeyScan = "ssh-keyscan"
	$ssh = "ssh"

	Write-Verbose "Checking for OpenSSH ..."
	$sshKeyScanInstalled = Get-Command $sshKeyScan -ErrorAction SilentlyContinue
	$sshInstalled = Get-Command $ssh -ErrorAction SilentlyContinue

	if (!$sshKeyScanInstalled -Or !$sshInstalled) {
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
	
	Write-Verbose "Reading known SSH host config file $userKnownSSHHostsFile..."
	if (Test-Path $userKnownSSHHostsFile -PathType leaf) {
		$userKnownSSHHosts = Get-Content $userKnownSSHHostsFile | Foreach {$_.Trim()} | where {$_ -ne "" -and (-Not $_.StartsWith("#")) }
	} else {
		$userKnownSSHHosts = @()
	}
	Write-Output ("Found " + $userKnownSSHHosts.Count + " known SSH Hosts in config file $userKnownSSHHostsFile.")

	$knownSSHConfigHostsFile = "ssh_hosts.config"
	$knownSSHHosts = @()

	if ($hostnames.Count -eq 0) {
		Write-Verbose "No known SSH hosts specified via command line."
		Write-Verbose "Checking for known SSH hosts user config file $knownSSHConfigHostsFile ..."
		
		if (Test-Path $knownSSHConfigHostsFile -PathType leaf) {
			Write-Verbose "Reading known SSH hosts user config file $knownSSHConfigHostsFile ..."
			$knownSSHHosts = Get-Content $knownSSHConfigHostsFile | Foreach {$_.Trim()} | where {$_ -ne "" }
			Write-Output ("Found " + $knownSSHHosts.Count + " known SSH hosts in user config file $knownSSHConfigHostsFile.")
		} else {
			Write-Warning "Could not find known SSH hosts user config file $knownSSHConfigHostsFile."
		}	
	} else {
		Write-Output ("Found " + $hostnames.Count + " known SSH hosts specified via command line to be added to config file $userKnownSSHHostsFile.")
		foreach ($knownHost in $hostnames) {
			$knownSSHHosts += $knownHost
		}
	}

	if ($knownSSHHosts.Count -eq 0) {
		Write-Warning "No known SSH hosts found to add to config file $userKnownSSHHostsFile."
		Exit-Script $keyPress
	}
	
	$md5Service = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	$sha256Service = New-Object -TypeName System.Security.Cryptography.SHA256CryptoServiceProvider
	
	$backupDone = $False

	foreach ($knownSSHHost in $knownSSHHosts) {
		Write-Output "`nFetching public SSH keys for host $knownSSHHost ..."
		
		$fetchedSSHKeys = & $sshKeyScan -T $timeout $knownSSHHost 2>$null
		
		if ($LASTEXITCODE -ne 0 -or !$fetchedSSHKeys) {
			Write-Error "Could not scan public SSH keys for host $knownSSHHost."
		}
		else {
			Write-Verbose "Fetched public SSH keys for host $knownSSHHost."
			
			foreach ($fetchedSSHKey in $fetchedSSHKeys) {
				
				$fetchedSSHKeyParts = $fetchedSSHKey -split " "
				if ($fetchedSSHKeyParts.Count -ne 3) {
					Write-Error "Could not add host $knownSSHHost to known SSH hosts config file $userKnownSSHHostsFile."
				} else {
					$keyType = $fetchedSSHKeyParts[1]
					$thumbprint = $fetchedSSHKeyParts[2]
					
					$bin = [System.Convert]::FromBase64String($thumbprint)
					$md5 = [System.BitConverter]::ToString($md5Service.ComputeHash($bin)).Replace('-', ':').ToLower()
					$sha256 = [System.Convert]::ToBase64String($sha256Service.ComputeHash($bin)).TrimEnd("=")
				
					if ($fetchedSSHKey -notin $userKnownSSHHosts) {
						
						if (-Not $nobackup -And -Not $backupDone) {
							$backupDone = $True
							$userKnownSSHHostsBakFile = $userKnownSSHHostsFile + "_$((Get-Date).ToString('yyyyddMM_hhmmss')).bak"
							Write-Verbose "Creating known SSH hosts backup config file $userKnownSSHHostsBakFile for known SSH hosts config file $userKnownSSHHostsFile ..."
							Copy-Item -Path $userKnownSSHHostsFile -Destination $userKnownSSHHostsBakFile -Force -Confirm:$False
							Write-Output "Created known SSH hosts backup config file $userKnownSSHHostsBakFile."
						}
						
						Write-Verbose "Adding SSH key $keyType for host $knownSSHHost to known SSH hosts config file $userKnownSSHHostsFile ..."
						$fetchedSSHKey | Out-FileUtf8NoBom -LiteralPath $userKnownSSHHostsFile -Append
						Write-Output "Added SSH key $keyType for host $knownSSHHost to known SSH hosts config file $userKnownSSHHostsFile."
						Write-Output "Thumbprint: $thumbprint"
						Write-Output "Fingerprint MD5: $md5"
						Write-Output "Fingerprint SHA256: $sha256`n"
						
					} else {
						Write-Output "SSH key $keyType for host $knownSSHHost is already present in known SSH hosts config file $userKnownSSHHostsFile."
					}
				}
			}
		}
	}

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("KnownSSHHosts-Add " + $cmdLine)

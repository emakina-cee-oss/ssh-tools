param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function KnownSSHHosts-Remove {
<#
.SYNOPSIS
    Removes trusted SSH hosts from known hosts file
.DESCRIPTION
    KnownSSHHosts-Remove removes authorized SSH hosts from the known SSH hosts file.
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
		# Optional list of hosts which will be removed from known hosts file.
		# If none specified, the host names from a file named ssh_hosts.config are loaded and used.
		# Wildcards are allowed. Use char ~ for ? and use # for *
		# Example: KnownSSHHosts-Remove -hostnames "github.com,gitlab.com,ip,..."
		[Parameter(ValueFromRemainingArguments=$true, Position=1)]
		[string[]]$hostnames,
		# Optional custom known SSH hosts file.
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
		Get-Help -Name KnownSSHHosts-Remove -Detailed
		Exit-Script $keyPress
	}	

	Write-Output "`nRemove known SSH hosts"
	Write-Output "----------------------`n"
	
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
	
	$knownSSHConfigHostsFile = "ssh_hosts.config"
	$knownSSHHosts = @()

	if ($hostnames.Count -eq 0) {
		Write-Verbose "No known SSH hosts specified via command line."
		Write-Verbose "Checking for known SSH hosts user config file $knownSSHConfigHostsFile ..."
		
		if (Test-Path $knownSSHConfigHostsFile -PathType leaf) {
			Write-Verbose "Reading known SSH hosts user config file $knownSSHConfigHostsFile ..."
			$knownSSHHosts = Get-Content $knownSSHConfigHostsFile | Foreach {$_.Trim()} | where {$_ -ne ""}
			Write-Output ("Found " + $knownSSHHosts.Count + " known SSH hosts in user config file $knownSSHConfigHostsFile.")
		} else {
			Write-Output "Could not find known SSH hosts user config file $knownSSHConfigHostsFile."
		}	
	} else {
		Write-Output ("Found " + $hostnames.Count + " known SSH hosts specified via command line.")
		foreach ($knownHost in $hostnames) {
			$knownSSHHosts += $knownHost
		}
	}

	if ($knownSSHHosts.Count -eq 0) {
		Write-Warning "No known SSH hosts found to remove from config file $userKnownSSHHostsFile."
		Exit-Script $keyPress
	}
	
	if (Test-Path $userKnownSSHHostsFile -PathType leaf) {
		Write-Verbose "Reading from known SSH hosts file $userKnownSSHHostsFile ..."
		
		# Based on https://jdhitsolutions.com/blog/powershell/7848/parsing-ssh-known-hosts-with-powershell-and-regular-expressions/
		$removedKnownSSHHosts = [System.Collections.Generic.list[object]]::New()
		[regex]$rx = "(?<host>^\S+?)((?=:))?((?<=:)(?<port>\d+))?(,(?<address>\S+))?\s(?<type>[\w-]+)\s(?<thumbprint>.*)"
		
		$entries = (Get-Content -Path $userKnownSSHHostsFile) -split "`n"
		
		$md5Service = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
		$sha256Service = New-Object -TypeName System.Security.Cryptography.SHA256CryptoServiceProvider
		
		$newEntries = [System.Collections.Generic.list[object]]::New()
		$line = 1

		foreach ($entry in $entries) {
			$matched = $rx.Match($entry)

			$removeEntry = $False
			
			if ($matched.Success) {
				$hostn = $matched.groups["host"].value -replace ":$|\[|\]", ""
				
				foreach ($knownSSHHost in $knownSSHHosts) {
					
					$hostname = $knownSSHHost -replace "#", "*"
					$hostname = $hostname -replace "~", "?"
					
					if ($hostn -like $hostname) {
						$removeEntry = $True
						break
					}
				}
				
				if ($removeEntry) {
					$address = $matched.groups["address"].value -replace "\[|\]", ""
					$keytype = $matched.groups["type"].value
					$port = $matched.groups["port"].value
					$thumbprint = $matched.groups["thumbprint"].value
					$bin = [System.Convert]::FromBase64String($thumbprint)
					$md5 = [System.BitConverter]::ToString($md5Service.ComputeHash($bin)).Replace('-', ':').ToLower()
					$sha256 = [System.Convert]::ToBase64String($sha256Service.ComputeHash($bin)).TrimEnd("=")

					$removedKnownSSHHost = [pscustomobject]@{
						PSTypeName = "removedKnownSSHHost"
						Hostname   = $hostn
						Address    = $address
						Port       = $port
						Keytype    = $keytype
						Thumbprint = $thumbprint
						Md5        = $md5
						Sha256     = $sha256
						Line       = $line
					}
					
					$removedKnownSSHHosts.Add($removedKnownSSHHost)
					
				}
			} 

			if (!$removeEntry) {
				$newEntries.Add($entry)
			}
			
			$line++
		}

		Write-Output ("Found " + $removedKnownSSHHosts.Count + " known SSH hosts to remove from config file $userKnownSSHHostsFile.")

		if ($removedKnownSSHHosts.Count -gt 0) {

			if (-Not $nobackup) {
				$userKnownSSHHostsBakFile = $userKnownSSHHostsFile + "_$((Get-Date).ToString('yyyyddMM_hhmmss')).bak"
				Write-Verbose "Creating known SSH hosts backup config file $userKnownSSHHostsBakFile for known SSH hosts config file $userKnownSSHHostsFile ..."
				Copy-Item -Path $userKnownSSHHostsFile -Destination $userKnownSSHHostsBakFile -Force -Confirm:$False
				Write-Output "Created known SSH hosts backup config file $userKnownSSHHostsBakFile."
			}
				
			foreach ($removedKnownSSHHost in $removedKnownSSHHosts) {
				Write-Output "`nRemoving SSH key $($removedKnownSSHHost.Keytype) for host $($removedKnownSSHHost.Hostname) from known SSH hosts config file $userKnownSSHHostsFile ..."
				Write-Output "Line: $($removedKnownSSHHost.Line)"
				if ($removedKnownSSHHost.Address) {
					Write-Output "Address: $($removedKnownSSHHost.Address)"
				}
				if ($removedKnownSSHHost.Port) {
					Write-Output "Port: $($removedKnownSSHHost.Port)"
				}
				Write-Output "Thumbprint: $($removedKnownSSHHost.Thumbprint)"
				Write-Output "Fingerprint MD5: $($removedKnownSSHHost.Md5)"
				Write-Output "Fingerprint SHA256: $($removedKnownSSHHost.Sha256)"
			}
			
			Write-Verbose "Updating known SSH hosts config file $userKnownSSHHostsFile ..."
			$newEntries | Out-FileUtf8NoBom -LiteralPath $userKnownSSHHostsFile
			Write-Output "Updated known SSH hosts config file $userKnownSSHHostsFile."
		}
	} else {
		Write-Warning "Could not find known SSH hosts config file $userKnownSSHHostsFile."
	}
	
	Exit-Script $keyPress	
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("KnownSSHHosts-Remove " + $cmdLine)

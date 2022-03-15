param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function KnownSSHHosts-List {
<#
.SYNOPSIS
    Lists trusted SSH hosts from known hosts file
.DESCRIPTION
    KnownSSHHosts-List lists all authorized SSH host entries from known hosts file.
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
		# Optional hostname to filter for (wildcards are allowed)
		# Use char ~ for ? and use # for *
		[Parameter(Mandatory=$False)]
		[SupportsWildcards()]
		[string]$hostname = $null,
		# Optional custom known SSH hosts file
		# If none specified, the location of the known SSH host file is obtained from the ssh agent		
		[Parameter(Mandatory=$False)]
		[string]$knownhostsfile = $null
	)
	
	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}	
	
	if ($help) {
		Get-Help -Name KnownSSHHosts-List -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nList known SSH hosts"
	Write-Output "--------------------`n"

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
			Write-Error "Could not find user known SSH config hosts file."
			Exit-Script $keyPress
		}
		$userKnownSSHHostsFile = $userKnownSSHHostsFileParts[1]
		
	} else {
		$userKnownSSHHostsFile = $knownhostsfile
	}
	
	Write-Verbose "Known SSH Hosts file found at $userKnownSSHHostsFile."

	if (Test-Path $userKnownSSHHostsFile -PathType leaf) {
		Write-Verbose "Reading known SSH host config file $userKnownSSHHostsFile..."
		
		# Based on https://jdhitsolutions.com/blog/powershell/7848/parsing-ssh-known-hosts-with-powershell-and-regular-expressions/
		$knownSSHHosts = [System.Collections.Generic.list[object]]::New()
		[regex]$rx = "(?<host>^\S+?)((?=:))?((?<=:)(?<port>\d+))?(,(?<address>\S+))?\s(?<type>[\w-]+)\s(?<thumbprint>.*)"
		
		$entries = (Get-Content -Path $userKnownSSHHostsFile) -split "`n"
		$hostname = $hostname -replace "#", "*"
		$hostname = $hostname -replace "~", "?"
		
		$md5Service = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
		$sha256Service = New-Object -TypeName System.Security.Cryptography.SHA256CryptoServiceProvider

		foreach ($entry in $entries) {
			$matched = $rx.Match($entry)
			
			if (-Not $matched.Success) {
				continue
			}
			
			$hostn = $matched.groups["host"].value -replace ":$|\[|\]", ""
			
			if ($hostname -And -Not ($hostn -like $hostname)) {
				continue
			}
			
            $address = $matched.groups["address"].value -replace "\[|\]", ""
			$keytype = $matched.groups["type"].value
			$port = $matched.groups["port"].value
			$thumbprint = $matched.groups["thumbprint"].value
			$bin = [System.Convert]::FromBase64String($thumbprint)
			$md5 = [System.BitConverter]::ToString($md5Service.ComputeHash($bin)).Replace('-', ':').ToLower()
			$sha256 = [System.Convert]::ToBase64String($sha256Service.ComputeHash($bin)).TrimEnd("=")

			$knownSSHHost = [pscustomobject]@{
				PSTypeName = "knownSSHHost"
				Hostname   = $hostn
				Address    = $address
				Port       = $port
				Keytype    = $keytype
				Thumbprint = $thumbprint
				Md5        = $md5
				Sha256     = $sha256
			}
			
			$knownSSHHosts.Add($knownSSHHost)
		}
		
		Write-Output ("Found " + $knownSSHHosts.Count + " known SSH hosts in config file $userKnownSSHHostsFile.")
		
		foreach ($knownSSHHost in $knownSSHHosts) {
			Write-Output "`nHost: $($knownSSHHost.Hostname)"
			if ($knownSSHHost.Address) {
				Write-Output "Address: $($knownSSHHost.Address)"
			}
			if ($knownSSHHost.Port) {
				Write-Output "Port: $($knownSSHHost.Port)"
			}
			Write-Output "Key type: $($knownSSHHost.Keytype)"
			Write-Output "Thumbprint: $($knownSSHHost.Thumbprint)"
			Write-Output "Fingerprint MD5: $($knownSSHHost.Md5)"
			Write-Output "Fingerprint SHA256: $($knownSSHHost.Sha256)"
		}
	} else {
		Write-Warning "Could not find known SSH hosts config file $userKnownSSHHostsFile."
	}
	
	Exit-Script $keyPress	
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("KnownSSHHosts-List " + $cmdLine)


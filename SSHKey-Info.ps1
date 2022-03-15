param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function SSHKey-Info {
<#
.SYNOPSIS
    Shows information about SSH keys. 
.DESCRIPTION
    SSHKey-Info displays information about SSH keys.
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
		# Optional list of public SSH keys for which information will be shown
		# If none specified, key names from a file named ssh_keys.config are 
		# loaded and used.
		# Example: SSHKey-Info -keynames "key1.pub,key2.pub,key3.pub,.."
		[Parameter(ValueFromRemainingArguments=$true, Position=1)]
		[string[]]$keynames
	)
	
	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}	
	
	if ($help) {
		Get-Help -Name SSHKey-Info -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nShow SSH Key Info"
	Write-Output "-----------------`n"

	$sshKeyGen = "ssh-keygen"

	Write-Verbose "Checking for OpenSSH ..."
	$sshInstalled = Get-Command $sshKeyGen -ErrorAction SilentlyContinue

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
		Write-Verbose "No SSH keys specified via command line."
		Write-Verbose "Checking for user SSH keys user config file $sshKeysConfigFile ..."
		
		if (Test-Path $sshKeysConfigFile -PathType leaf) {
			Write-Verbose "Reading SSH keys user config file $sshKeysConfigFile ..."
			$sshKeys = Get-Content $sshKeysConfigFile | Foreach {$_.Trim() + ".pub"} | where {$_ -ne ".pub"}
			Write-Output ("Found " + $sshKeys.Count + " SSH keys in user config file $sshKeysConfigFile.")
		} else {
			Write-Output "Could not find SSH keys user config file $sshKeysConfigFile."
		}	
	} else {
		Write-Output ("Found " + $keynames.Count + " SSH keys specified via command line.")
		foreach ($sshKey in $keynames) {
			$sshKeys += $sshKey
		}
	}

	if ($sshKeys.Count -eq 0) {
		Write-Warning "No SSH keys found to show info."
		Exit-Script $keyPress
	}
	
	foreach ($sshKey in $sshKeys) {
		if (Test-Path $sshKey -PathType leaf) {
			
			Write-Verbose "Reading sha256 info from SSH key $sshKey ..."
			$sha256KeyInfo = & $sshKeyGen -lf $sshKey -E sha256 2>$null
			Write-Output $sha256KeyInfo
			
			if ($LASTEXITCODE -ne 0) {
				Write-Error "Could not read sha256 info from SSH key $sshKey."
			} else {
				Write-Verbose "Reading md5 info from SSH key $sshKey ..."
				$md5KeyInfo = & $sshKeyGen -lf $sshKey -E md5 2>$null
				Write-Verbose "Read md5 info from SSH key $sshKey."
				
				if ($LASTEXITCODE -ne 0) {
					Write-Error "Could not md5 read info from SSH key $sshKey."
				} else {
					Write-Verbose "Read sha256 info from SSH key $sshKey."
					
					$sha256KeyParts = $sha256KeyInfo -split " "
					$md5KeyParts = $md5KeyInfo -split " "
					
					if ($sha256KeyParts.Count -le 3 -or $md5KeyParts.Count -le 3) {
						Write-Error "Could not parse info from SSH key $sshKey."
					} else {

						Write-Verbose "Reading public key for SSH key $sshKey ..."
						$publicKey = Get-Content $sshKey
						Write-Verbose "Read public key for SSH key $sshKey."
						
						$keySize = $sha256KeyParts[0]
						$sha256 = $sha256KeyParts[1] -replace "SHA256:", ""
						$md5 = $md5KeyParts[1] -replace "MD5:", ""
						$keyType = $sha256KeyParts[$sha256KeyParts.Count - 1] -replace "[()]",""
						$comment = ""
						for ($i = 2; $i -le $sha256KeyParts.Count - 2; $i++) {
							$comment += $sha256KeyParts[$i] + " "
						}
						
						Write-Output "`nPublic key file: $sshKey"
						Write-Output "Public key: $publicKey"						
						Write-Output "Key type: $keyType"
						Write-Output "Key size: $keySize bits"
						Write-Output "Comment: $comment"
						Write-Output "Fingerprint MD5: $md5"
						Write-Output "Fingerprint SHA256: $sha256"
					}
				}
			}
		}
		else {
			Write-Error "Could not find SSH key file $sshKey."
		}
	}

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("SSHKey-Info " + $cmdLine)

param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function SSHKey-Create {
<#
.SYNOPSIS
    Creates an Open SSH key with a private and public key file
.DESCRIPTION
    SSHKey-Create generates an Open SSH key pair with the specified key options
	by generating a private and a public key file (*.pub). Enable interactive mode 
	to be prompted for key parameters not specified via command line.
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
		# Enable interactive input mode for key parameters not specified via command line
		[Parameter(Mandatory=$False)]
		[switch]$interactive = $False,
		# Overwrite existing private/public key files
		[Parameter(Mandatory=$False)]
		[switch]$overwrite = $False,
		# Use specified algorithm (ed25519 or rsa) to generate key
		[Parameter(Mandatory=$False)]
		[ValidateSet("ed25519", "rsa")]
		[string]$algo = $null,
		# Optional key file/path for the private and public key file
		# If not specified the following template is used to generate the file:
		# id_<algorithm-type>(_<servername>)(_<username>)[.pub]
		[Parameter(Mandatory=$False)]
		[string]$file = $null,
		# Optional key passphrase used to encrypt the private key
		[Parameter(Mandatory=$False)]
		[string]$passphrase  = $null,
		# Optional servername used in key comment and filename generation.
		# If servername is not specified the hostname is used.
		[Parameter(Mandatory=$False)]
		[string]$servername  = $null,
		# Optional username used in key comment and filename generation.
		# If username is not specified the login username is used.
		[Parameter(Mandatory=$False)]
		[string]$username  = $null,
		# Optional key comment
		# If not specified the following template is used to generate the comment:
		# <algorithm-type>-key-<yyyyddMM>( <servername>)( <username>)
		# If servername is not specified the hostname is used.
		# If username is not specified the login username is used.
		[Parameter(Mandatory=$False)]
		[string]$comment = $null
	)
	
	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}
	
	if ($help) {
		Get-Help -Name SSHKey-Create -Detailed
		Exit-Script $keyPress
	}

	Write-Output "`nCreate SSH key"
	Write-Output "--------------`n"

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
	
	if ($keyPress) {
		$interactive = $True
	}

	if (!$algo -And $interactive) {
		$rsa = ((Read-Host -Prompt "Algorithm ED25519 or RSA (e/r)") -match "[rR]")
	} else {
		$rsa = $algo -like "rsa"
	}

	if ($rsa) {
		$algoType = "rsa"
		
		# Key size in bit length
		$keySize = 4096
		
	} else {
		$algoType = "ed25519"
		
		# It’s the numbers of KDF (Key Derivation Function) rounds. 
		# Higher numbers result in slower passphrase verification, 
		# increasing the resistance to brute-force password cracking 
		# should the private-key be stolen.		
		$keyDerivations = [int]512 
	}
		
	if (!$file -And $interactive) {
		$file = Read-Host -Prompt "File"
	}
	
	if (!$passphrase -And $interactive) {
		while ($True) {
			$securePassphrase = Read-Host -Prompt "Passphrase" -AsSecureString
			if ($securePassphrase.Length -eq 0) {
				break
			}
			else {
				$secureVerifyPassphrase = Read-Host -Prompt "Verify passphrase" -AsSecureString
				if ($secureVerifyPassphrase.Length -ne 0) {
					$tempPassphrase = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassphrase))
					$verifyPassphrase = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureVerifyPassphrase))
					if ($tempPassphrase -ne $verifyPassphrase) {
						Write-Error "Passphrase does not match verify passphrase. Please retype again or leave passphrase empty."
					}
					else {
						$passphrase = $tempPassphrase
						break
					}
				}
				else {
						Write-Error "Passphrase does not match verify passphrase. Please retype again or leave passphrase empty."
				}
			}
		}
	}

	if (!$servername -And $interactive) {
		$servername = Read-Host -Prompt "Servername"
	}

	if (!$username -And $interactive) {
		$username = Read-Host -Prompt "Username"
	}

	if (!$comment -And $interactive) {
		$comment = Read-Host -Prompt "Comment"
	}
	
	if (!$comment) {
		Write-Verbose "Key comment not specified, using a generated one ..."
		$comment = "$algoType-key-$((Get-Date).ToString('yyyyddMM'))"
		
		if ($servername) {
			$comment += " $servername"
		} else {
			$hostname = [System.Net.Dns]::GetHostName()
			Write-Verbose "Server name not specified, using $hostname in the key comment."
			$comment += " " + $hostname
		}
		
		if ($username) {
			$comment += " $username"
		} else {
			$envUsername = $env:Username
			Write-Verbose "User name not specified, using $envUsername in the key comment."
			$comment += " " + $envUsername
		}
		Write-Verbose "Generated key comment: $comment"
	}

	if ($file) {
		$filedir = [System.IO.Path]::GetDirectoryName($file)
		
		if ($filedir) {
			Write-Verbose "Key directory specified, using directory $filedir."
		}
		
		$filename = [System.IO.Path]::GetFileName($file)
		
		if ($filename) {
			Write-Verbose "Key filename specified, using filename $filename."
		}
	}

	if (!$filename) {
		Write-Verbose "Key filename not specified, using a generated one ..."
		
		$filename = "id_" + $algoType
		
		if ($servername) {
			Write-Verbose "Server name is specified, using $servername in the key filename."
			$filename += "_" + $servername
		}
		
		if ($username) {
			Write-Verbose "User name is specified, using $username in the key filename."
			$filename += "_" + $username
		}
		
		$filename = $filename.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
		Write-Verbose "Generated key filename: $filename"
	}
	
	$file = [IO.Path]::Combine($filedir, $filename)
	$pkFile = $file
	$pubkFile = $file + ".pub"
	
	if (!$overwrite) {
		Write-Verbose "Checking if private SSH key $pkFile already exists ..."
		if (Test-Path $pkFile -PathType leaf) {
			Write-Error "Private SSH key file $pkFile already exists."
			Exit-Script $keypress
		}
		Write-Verbose "Private SSH key file $pkFile does not exist."
		
		Write-Verbose "Checking if public SSH key $pubkFile already exists ..."
		if (Test-Path $pubkFile -PathType leaf) {
			Write-Error "Private SSH key file $pubkFile already exists."
			Exit-Script $keypress
		}
		
		Write-Verbose "Public SSH key file $pubkFile does not exist."
	}

	Write-Verbose "Creating SSH key with private key file $pkFile and public key file $pubkFile ..."

	$args = @()
	$args += "-t"
	$args += $algoType
	if (!$rsa) {
		$args += "-a"
		$args += $keyDerivations
	} else {
		$args += "-b"
		$args += $keySize
	}
	$args += "-q"
	$args += "-f"
	$args += $file

	if ($comment) {
		$args += "-C"
		$args += $comment
	}

	$args += "-N"
	$args += $(If ($passphrase) { $passphrase } else { '""' })
	
	Write-Output ("y" | & $sshKeyGen $args 3>$null 2>$null >$null)

	if ($LASTEXITCODE -ne 0) {
		Write-Error "Could not create SSH key with private key file $pkFile and public key file $pubkFile."
		Exit-Script $keyPress
	}

	Write-Output "Created SSH key with private key file $pkFile and public key file $pubkFile."

	$keySize = ""
	$md5 = ""
	$sha256 = ""
	
	Write-Verbose "Reading SHA256 SSH key info from private key file $pkFile ..."
	$keyInfosSha256 = ((& $sshKeyGen -l -E sha256 -f $pkFile) -split " ")	 
	if ($LASTEXITCODE -ne 0 -or $keyInfosSha256.Count -le 2) {
		Write-Error "Could not read SHA256 SSH key info from private key file $pkFile."
	}
	else {
		Write-Verbose "Read SHA256 SSH key info from private key file $pkFile."
		$keySize = $keyInfosSha256[0]
		$sha256 = $keyInfosSha256[1] -replace "SHA256:", ""
	}

	Write-Verbose "Reading MD5 SSH key info from private key file $pkFile ..."
	$keyInfosMd5 = ((& $sshKeyGen -l -E md5 -f $pkFile) -split " ")	
	if ($LASTEXITCODE -ne 0 -or $keyInfosMd5.Count -le 2) {
		Write-Error "Could not read MD5 SSH key info from private key file $pkFile."
	}
	else {
		Write-Verbose "Read MD5 SSH key info from private key file $pkFile."
		$keySize = $keyInfosMd5[0]
		$md5 = ($keyInfosMd5[1] -replace "MD5:", "")
	}

	Write-Output "Private key file: $pkFile"
	Write-Output "Public key file: $pubkFile"
	Write-Output "Algorithm: $algoType"
	Write-Output "Key size: $keySize bits"
	if ($keyDerivations) {
		Write-Output "Key derivations: $keyDerivations"
	}
	Write-Output "Passphrase: $(If ($passphrase) { "yes" } else { "no"})"
	if ($comment) {
		Write-Output "Comment: $comment"
	}
	Write-Output "Fingerprint MD5: $md5"
	Write-Output "Fingerprint SHA256: $sha256"
	
	$pubk = Get-Content $pubkFile
	Write-Output "Public key: $pubk"
	
	Write-Verbose "Copying public key to clipboard ..."
	Set-Clipboard $pubk
	Write-Output "Copied public key to clipboard."

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("SSHKey-Create " + $cmdLine)

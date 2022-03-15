param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function RegisteredSSHKeys-List {
<#
.SYNOPSIS
    Lists SSH keys registered with the ssh-agent.
.DESCRIPTION
    RegisteredSSHKeys-List shows all SSH keys which are registered with the ssh-agent.
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
		Get-Help -Name RegisteredSSHKeys-List -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nList registered SSH keys"
	Write-Output "------------------------`n"

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

	Write-Verbose "Reading registered SSH keys sha256 info..."
	$sshKeysSha256 = & $sshAdd -l -k -E sha256 2>$null
	
	if ($sshKeysSha256 -eq "The agent has no identities."){
		Write-Output "Found 0 SSH keys registered with ssh-agent."
		Exit-Script $keyPress
	}
	
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Could not read registered SSH keys sha256 info from ssh-agent."
		Exit-Script $keyPress
	}
	Write-Verbose "Read registered SSH keys sha256 info."

	Write-Verbose "Reading registered SSH keys md5 info..."
	$sshKeysMd5 = & $sshAdd -l -k -E md5 2>$null
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Could not read registered SSH keys md5 info from ssh-agent."
		Exit-Script $keyPress
	}			
	Write-Verbose "Read registered SSH keys md5 info."
	
	Write-Verbose "Reading registered SSH keys public key info ..."
	$sshKeys = & $sshAdd -L -k 2>$null
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Could not read registered SSH keys public key info from ssh-agent."
		Exit-Script $keyPress
	}
	Write-Verbose "Read registered public SSH keys public key info."
	
	if ($sshKeysSha256.Count -ne $sshKeysMd5.Count -Or $sshKeysSha256.Count -ne $sshKeys.Count) {
		Write-Error "Could not read registered SSH keys from ssh-agent."
		Exit-Script $keyPress
	}			

	Write-Output ("Found " + $sshKeysSha256.Count + " SSH keys registered with ssh-agent.")

	$i = 0
	foreach ($sshKeySha256 in $sshKeysSha256) {
		
        $keySize = ""
        $sha256 = ""
		
        $sshKeySha256Parts = $sshKeySha256 -split " "
		
        if ($sshKeySha256Parts.Count -le 2) {
            Write-Warning "Could not parse key size and sha256 fingerprint."
        } else {
            $keySize = $sshKeySha256Parts[0]
            $sha256 = $sshKeySha256Parts[1] -replace "SHA256:", ""
        }
		
        $md5 = ""
        
		$sshKeyMd5Parts = $sshKeysMd5[$i] -split " "
        if ($sshKeyMd5Parts.Count -le 2) {
            $sshKeyMd5Parts = $sshKeysMd5 -split " "
        }
        $md5 = $sshKeyMd5Parts[1] -replace "MD5:", ""
        
		$keyType = ""
        $comment = ""
        $publicKeyParams = ""
        
		$sshKeyParts = $sshKeys[$i] -split " "
        if ($sshKeyParts.Count -le 2) {
            $sshKeyParts = $sshKeys -split " "
        }
        
		$keyType = $sshKeyParts[0]
        $publicKeyPart = $sshKeyParts[1]
        
		if ($sshKeyParts.Count -ge 2) {
            for ($j = 2; $j -le $sshKeyParts.Count; $j++) {
                $comment += $sshKeyParts[$j] + " "
            }
        }
		
        Write-Output "`nPublic key part: $publicKeyPart"
        Write-Output "Key type: $keyType"
        Write-Output "Key size: $keySize bits"
        Write-Output "Fingerprint MD5: $md5"
        Write-Output "Fingerprint SHA256: $sha256"
        Write-Output "Comment: $comment"
		
        $i++
    }
	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("RegisteredSSHKeys-List " + $cmdLine)

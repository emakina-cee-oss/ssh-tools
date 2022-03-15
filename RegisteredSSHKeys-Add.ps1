param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function RegisteredSSHKeys-Add {
<#
.SYNOPSIS
    Adds SSH keys to the ssh-agent.
.DESCRIPTION
    RegisteredSSHKeys-Add registers SSH keys to the ssh-agent.
.NOTES
	Author: Helmut Janisch
#>	
   [CmdletBinding()]
	param (
		# Show this help
		[Parameter(Mandatory=$False)]
		[switch]$help = $False,
		# Optional list of private SSH keys which will be added to the ssh-agent.
		# If none specified, the private key names from a file named ssh_keys.config are 
		# loaded and used.
		# Example: RegisteredSSHKeys-Add -keynames "key1,key2,key3,.."
		[Parameter(ValueFromRemainingArguments=$true, Position=1)]
		[string[]]$keynames
	)
	
	$keyPress = ($withinCmd -eq $False) -Or ($elevated -eq $True)
	
	if (IsRunByWindowsTerminal) {
		$keyPress = $False
	}	
	
	if ($help) {
		Get-Help -Name RegisteredSSHKeys-Add -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nRegister SSH keys"
	Write-Output "-----------------`n"

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
		Write-Verbose "No SSH keys to register specified via command line."
		Write-Verbose "Checking for SSH keys user config file $sshKeysConfigFile ..."
		
		if (Test-Path $sshKeysConfigFile -PathType leaf) {
			Write-Verbose "Reading SSH keys user config file $sshKeysConfigFile ..."
			$sshKeys = Get-Content $sshKeysConfigFile | Foreach {$_.Trim()} | where {$_ -ne ""}
			Write-Output ("Found " + $sshKeys.Count + " SSH keys to register in user config file $sshKeysConfigFile.")
		} else {
			Write-Output "Could not find SSH keys user config file $sshKeysConfigFile."
		}	
	} else {
		Write-Output ("Found " + $keynames.Count + " SSH keys to register specified via command line.")
		foreach ($sshKey in $keynames) {
			$sshKeys += $sshKey
		}
	}

	if ($sshKeys.Count -eq 0) {
		Write-Warning "No SSH keys found to register with ssh-agent."
		Exit-Script $keyPress
	}
	
	foreach ($sshKey in $sshKeys) {
		if (Test-Path $sshKey -PathType leaf) {	
			Write-Output "`nRegistering SSH key $sshKey with ssh-agent ..."
			
			& $sshAdd $sshKey 2>$null
			
			if ($LASTEXITCODE -ne 0) {
				Write-Error "Could not register SSH key $sshKey with ssh-agent."
			} else {
				Write-Output "Registered SSH key $sshKey with ssh-agent."
			}
		}
		else {
			Write-Warning "Could not find SSH key file $sshKey."
		}
	}

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("RegisteredSSHKeys-Add " + $cmdLine)

param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function OpenSSH-Install {
<#
.SYNOPSIS
    Installs Open SSH for Windows
.DESCRIPTION
    OpenSSH-Install installs and setups native Open SSH for Windows to be used with git.
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
		Get-Help -Name OpenSSH-Install -Detailed
		Exit-Script $keyPress
	}		

	Write-Output "`nInstall OpenSSH"
	Write-Output "---------------`n"

	Write-Output "Checking for Windows ..."
	if ((Get-Variable -Name "IsWindows" -Scope Global -ErrorAction SilentlyContinue) -eq $null)
	{
		# We know we're on Windows PowerShell 5.1 or earlier
		$IsWindows = $true
	}
	
	if (!$IsWindows) {
		Write-Error "No Windows detected."
		Exit-Script $keyPress
	}
	Write-Output "Windows detected."
	
	Write-Output "Reading windows info ..."
	$wmi = Get-WmiObject Win32_OperatingSystem -ErrorAction SilentlyContinue
	if (!$wmi) {
		Write-Error "Could not read windows info."
		Exit-Script $keyPress
	} else {
		Write-Output "Windows info found: $($wmi.Caption), $($wmi.OsArchitecture), Version: $($wmi.Version), Build: $($wmi.BuildNumber)"
	}
	
	Write-Output "Checking windows version ..."
	$winMajorVersion = [int]($wmi.Version -Replace "^(\d+).*$",'$1')
	if ($winMajorVersion -lt 10) {
		Write-Error "You need at least Windows 10 to proceed."
		Exit-Script $keyPress
	} else {
		Write-Output "Windows version is ok (Windows 10 or newer)."
	}
	
	$featureName = "OpenSSH.Client*"
	Write-Output "Checking for optional windows feature $featureName ..."
	$capResult = Get-WindowsCapability -Name $featureName -Online -ErrorAction SilentlyContinue

	if (!$capResult) {
		$openSSHUrl = "https://github.com/PowerShell/Win32-OpenSSH/releases"
		Write-Error "Your windows version does not support OpenSSH for Windows natively."
		Write-Error "Either update your windows to at least Windows 10 version 21H1"
		Write-Error "(May 2021 Update, Build 19043) or download and install manually at"
		Write-Error "least OpenSSH for Windows version 8.1 manually from"
		Write-Error "$openSSHUrl and rerun this script again."
		Write-Output "Opening $openSSHUrl in browser ..."
		Start-Process $openSSHUrl
		Exit-Script $keyPress
	}

	if ($capResult.State -ne "Installed") {
		Write-Output "Installing optional windows feature $featureName ..."
		$capInstallResult = Add-WindowsCapability -Name $featureName -Online -ErrorAction SilentlyContinue
		
		if (!$capInstallResult) {
			Write-Error "Could not install optional windows feature $featureName."
			Exit-Script $keyPress
		} else {
			Write-Output "Installed optional windows feature $featureName."
		}

		if ($capInstallResult.RestartNeeded -eq $true) {
			$choice = Read-Host -Prompt "A restart is required. Do you want to restart? (y/n)"
			if ($choice -match "[yY]") {
				Read-Host -Prompt "Please rerun this script again after the restart! Press any key to restart ..."
				Restart-Computer -Force
			}
			Write-Output "Please restart and rerun this script again."
			Exit-Script $keyPress
		}
	} else {
		Write-Output "Optional windows feature $featureName is already installed."
	}

	$serviceName = "ssh-agent"
	Write-Output "Checking $serviceName service ..."
	$serviceResult = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
		
	if (!$serviceResult) {
		Write-Error "Could not find service $serviceName."
		Exit-Script $keyPress
	} else {
		Write-Output "Service $serviceName is ok."
	}

	$serviceStartType = "Automatic"
		
	if ($serviceResult.StartType -ne $serviceStartType) {
		Write-Output "Changing $serviceName service startup type to $serviceStartType ..."
		do {
			Set-Service -Name $serviceName -StartupType $serviceStartType
			Start-Sleep 10
		} until ((Get-Service -Name $serviceName -ErrorAction SilentlyContinue).StartType -eq $serviceStartType)
		Write-Output "Changed $serviceName service startup type to $serviceStartType."
	} else {
		Write-Output "$serviceName service startup type is $serviceStartType."
	}

	$serviceStatus = "Running"
		
	if ((Get-Service -Name $serviceName -ErrorAction SilentlyContinue).Status -ne $serviceStatus) {
		Write-Output "Changing $serviceName service status to $serviceStatus..."
		do {
		   Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
		   Start-Sleep 10
		} until ((Get-Service -Name $serviceName -ErrorAction SilentlyContinue).Status -eq $serviceStatus)
		Write-Output "Changed $serviceName service status to $serviceStatus."
	} else {
		Write-Output "$serviceName service status is $serviceStatus."
	}

	$ssh = "ssh"

	Write-Output "Checking for OpenSSH ..."
	$sshInstalled = Get-Command $ssh -ErrorAction Ignore
	if (!$sshInstalled) {
		Write-Error "OpenSSH is not installed. Please install OpenSSH for Windows and rerun this script again."
		Exit-Script $keyPress
	} else {
		$sshPath = ($sshInstalled | Select-Object -ExpandProperty Path).Replace("\", "/")
		Write-Output "OpenSSH is installed."
		Write-Output "$ssh found at $sshPath."
	}

	Write-Output "Reading OpenSSH version ..."
	$sshInfo = & $ssh -V 2>&1  
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Could not read OpenSSH version."
	} else {
		Write-Output "OpenSSH version found: $sshInfo"
	}

	$git = "git"
	Write-Output "Checking for Git ..."
	$gitInstalled = Get-Command $git -ErrorAction SilentlyContinue

	if (!$gitInstalled) {
		$gitUrl = "https://git-scm.com/download/win"
		Write-Error "Git is not installed. Please install Git for Windows from"
		Write-Error "$gitUrl and rerun this script again."
		Write-Output "Opening $gitUrl in browser ..."
		Start-Process $gitUrl
		Exit-Script $keyPress
	}
	else {
		Write-Output "Git is installed."
	}
	
	Write-Output "Reading Git version ..."
	$gitInfo = & $git --version 2>$null  
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Could not read Git version."
	} else {
		Write-Output "Git version found: $gitInfo"
	}	

	Write-Output "Reading environment variable GIT_SSH ..."
	$envGitSSHPath = $env:GIT_SSH

	if ($envGitSSHPath) {
		if ($envGitSSHPath -ne $sshPath) {
			Write-Warning "Environment variable GIT_SSH is set to $envGitSSHPath, but it should be set to $sshPath."
			Exit-Script $keyPress
		} else {
			Write-Output "Environment variable GIT_SSH is already set to $sshPath."
		}
	} else {
		Write-Output "Environment variable GIT_SSH is not set."

		Write-Output "Reading core.sshCommand setting from global .gitconfig file ..."
		$gitSSH = & $git config --global core.sshCommand 2>$null
		if ($LASTEXITCODE -eq 1 -And !$gitSSH) {
			Write-Output "Global .gitconfig file does not exist."
		} else {
			if ($LASTEXITCODE -ne 0) {
				Write-Error "Could not read core.sshCommand setting from global .gitconfig file."
				Exit-Script $keyPress
			}
		}
			
		if ($gitSSH) {
			if ($gitSSH -ne $sshPath) {
				Write-Warning "core.sshCommand in global .gitconfig file is set to $gitSSH, but it should be set to $sshPath."
				Exit-Script $keyPress
			} else {
				Write-Output "core.sshCommand in global .gitconfig file is already set to $sshPath."
			}
		} else {
			Write-Output "Setting core.sshCommand in global .gitconfig file to $sshPath ..."
			& $git config --global core.sshCommand $sshPath 2>$null
			if ($LASTEXITCODE -ne 0) {
				Write-Error "Could not set core.sshCommand in global .gitconfig file to $sshPath."
				Exit-Script $keyPress
			}
			Write-Output "core.sshCommand was successfully set in global .gitconfig file to $sshPath."
		}
	}
	
	Write-Output "OpenSSH is successfully installed and configured to use with git."
	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("OpenSSH-Install " + $cmdLine)

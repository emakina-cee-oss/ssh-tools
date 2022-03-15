param (
	[Parameter(Mandatory=$False)]
    [switch]$withinCmd = $False,
	[Parameter(Mandatory=$False)]
	[switch]$elevated = $False,
	[Parameter(ValueFromRemainingArguments = $true, Position=1)]
	$cmdArgs
)

. "$PSScriptRoot\Utils.ps1"

function TestTool {
<#
.SYNOPSIS
    TestTool Overview
.DESCRIPTION
    TestTool Description
.NOTES
	Author: 
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
		Get-Help -Name List-SSHKeys -Detailed
		Exit-Script $keyPress
	}		

	# -------------
	# TestTool Code
	# -------------
	
	Write-Output "I am the test tool"

	Exit-Script $keyPress
}

$cmdLine = $cmdArgs -join " "
Invoke-Expression("TestTool " + $cmdLine)

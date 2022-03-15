#requires -version 5.1

Function Out-FileUtf8NoBom {
<#
.SYNOPSIS
  Outputs to a UTF-8-encoded file *without a BOM* (byte-order mark).
.DESCRIPTION
  Mimics the most important aspects of Out-File:
    * Input objects are sent to Out-String first.
    * -Append allows you to append to an existing file, -NoClobber prevents
      overwriting of an existing file.
    * -Width allows you to specify the line width for the text representations
       of input objects that aren't strings.
  However, it is not a complete implementation of all Out-File parameters:
    * Only a literal output path is supported, and only as a parameter.
    * -Force is not supported.
    * Conversely, an extra -UseLF switch is supported for using LF-only newlines.
  Caveat: *All* pipeline input is buffered before writing output starts,
          but the string representations are generated and written to the target
          file one by one.
.NOTES
  The raison d'être for this advanced function is that Windows PowerShell
  lacks the ability to write UTF-8 files without a BOM: using -Encoding UTF8 
  invariably prepends a BOM.
  Copyright (c) 2017, 2020 Michael Klement <mklement0@gmail.com> (http://same2u.net), 
  released under the [MIT license](https://spdx.org/licenses/MIT#licenseText).
#>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position=0)] [string] $LiteralPath,
    [switch] $Append,
    [switch] $NoClobber,
    [AllowNull()] [int] $Width,
    [switch] $UseLF,
    [Parameter(ValueFromPipeline)] $InputObject
  )

  # Convert the input path to a full one, since .NET's working dir. usually
  # differs from PowerShell's.
  $dir = Split-Path -LiteralPath $LiteralPath
  if ($dir) { $dir = Convert-Path -ErrorAction Stop -LiteralPath $dir } else { $dir = $pwd.ProviderPath}
  $LiteralPath = [IO.Path]::Combine($dir, [IO.Path]::GetFileName($LiteralPath))

  # If -NoClobber was specified, throw an exception if the target file already
  # exists.
  if ($NoClobber -and (Test-Path $LiteralPath)) {
    Throw [IO.IOException] "The file '$LiteralPath' already exists."
  }

  # Create a StreamWriter object.
  # Note that we take advantage of the fact that the StreamWriter class by default:
  # - uses UTF-8 encoding
  # - without a BOM.
  $sw = New-Object System.IO.StreamWriter $LiteralPath, $Append

  $htOutStringArgs = @{}
  if ($Width) {
    $htOutStringArgs += @{ Width = $Width }
  }

  # Note: By not using begin / process / end blocks, we're effectively running
  #       in the end block, which means that all pipeline input has already
  #       been collected in automatic variable $Input.
  #       We must use this approach, because using | Out-String individually
  #       in each iteration of a process block would format each input object
  #       with an indvidual header.
  try {
    $Input | Out-String -Stream @htOutStringArgs | % { 
      if ($UseLf) {
        $sw.Write($_ + "`n") 
      }
      else {
        $sw.WriteLine($_) 
      }
    }
  } finally {
    $sw.Dispose()
  }

}

Function Exit-Script($keyPress) {
<#
	Author: Helmut Janisch
	Copyright (c) 2022
	Released under the [MIT license](https://spdx.org/licenses/MIT#licenseText)
#>	
	if ($keyPress -eq $True)	{
		Write-Host "`nPress any key to continue ..."
		$Host.UI.RawUI.FlushInputBuffer()   # Make sure buffered input doesn't "press a key" and skip the ReadKey().
		$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
	} else {
		Write-Host "`n"
	}

	exit	
}

function Write-Error($message) {
<#
	Author: Helmut Janisch
	Copyright (c) 2022
	Released under the [MIT license](https://spdx.org/licenses/MIT#licenseText)
#>	
    [Console]::ForegroundColor = "red"
    [Console]::Error.WriteLine($message)
    [Console]::ResetColor()
}

function IsRunByWindowsTerminal() {
<#
	Author: Helmut Janisch
	Copyright (c) 2022
	Released under the [MIT license](https://spdx.org/licenses/MIT#licenseText)
#>	
	$processId = $pid
	
	do {
		$currentProcess = Get-CimInstance -ClassName win32_process -filter "processid=$processId"
		if (!$currentProcess) {
			return $false
		}
		
        $parentProcess = Get-Process -id $currentProcess.ParentProcessId -ErrorAction SilentlyContinue
		
		if ($parentProcess) {
			$parentProcessName = $parentProcess.ProcessName;
			if ($parentProcessName -eq "WindowsTerminal") {
				return $True
			}
			
			$processId = $parentProcess.Id
		}
	} while ($parentProcess)
	
	return $False
}

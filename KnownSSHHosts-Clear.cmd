@ECHO OFF
SETLOCAL EnableDelayedExpansion
SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%%~n0.ps1

SET Args=

FOR %%a IN (%*) DO (
	SET Args=!Args! '%%a'
)

SET WithinCmd=-WithinCmd
IF "!cmdcmdline!" neq "!cmdcmdline:%~f0=!" SET WithinCmd=

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%PowerShellScriptPath%' %WithinCmd% %Args%";
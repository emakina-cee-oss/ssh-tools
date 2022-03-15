@ECHO OFF
SETLOCAL EnableDelayedExpansion
SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%%~n0.ps1

SET Args=

FOR %%a IN (%*) DO (
	SET Args=!args! """"%%a""""
)

SET WithinCmd=-WithinCmd
IF "!cmdcmdline!" neq "!cmdcmdline:%~f0=!" SET WithinCmd=

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File """"%PowerShellScriptPath%""""" %WithinCmd% -Elevated %Args%' -Verb RunAs}";

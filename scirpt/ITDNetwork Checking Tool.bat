@echo off
echo Starting ITD Network Checking Tool...
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0ITD Network Checking Tool.ps1"



echo.
echo Press any key to exit...
pause > nul 
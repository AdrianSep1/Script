@echo off
setlocal enabledelayedexpansion
title PC Troubleshooting Tool
color 0A

:menu
cls
echo.
echo ========================================
echo     PC TROUBLESHOOTING TOOL
echo ========================================
echo.
echo 1. Run System File Checker (SFC)
echo 2. Run Disk Check (CHKDSK)
echo 3. Clear Temporary Files
echo 4. Check Disk Space
echo 5. View System Information
echo 6. Check Network Connectivity
echo 7. Run Defragmentation
echo 8. Clear Event Logs
echo 9. Check Running Processes
echo 10. Repair Windows Image (DISM)
echo 11. Exit
echo.
set /p choice="Select an option (1-11): "

if "%choice%"=="1" goto sfc
if "%choice%"=="2" goto chkdsk
if "%choice%"=="3" goto cleanup
if "%choice%"=="4" goto diskspace
if "%choice%"=="5" goto sysinfo
if "%choice%"=="6" goto network
if "%choice%"=="7" goto defrag
if "%choice%"=="8" goto eventlog
if "%choice%"=="9" goto processes
if "%choice%"=="10" goto dism
if "%choice%"=="11" goto end
goto menu

:sfc
cls
echo Running System File Checker...
echo This may take several minutes. Please wait...
timeout /t 2
sfc /scannow
pause
goto menu

:chkdsk
cls
echo Running Disk Check...
echo Note: This requires admin rights and may need a system restart.
timeout /t 2
chkdsk C: /F /R
pause
goto menu

:cleanup
cls
echo Clearing temporary files...
del /q /f /s "%temp%\*.*" >nul 2>&1
del /q /f /s "C:\Windows\Temp\*.*" >nul 2>&1
echo Temporary files cleared successfully!
pause
goto menu

:diskspace
cls
echo Checking Disk Space...
echo.
wmic logicaldisk get name, size, freespace
echo.
pause
goto menu

:sysinfo
cls
echo System Information
echo.
systeminfo
pause
goto menu

:network
cls
echo Testing Network Connectivity...
echo.
ipconfig /all
echo.
echo Pinging Google DNS (8.8.8.8)...
ping 8.8.8.8 -n 4
echo.
pause
goto menu

:defrag
cls
echo Running Defragmentation...
echo Note: This may take a while on large drives.
timeout /t 2
defrag C: /U /V
pause
goto menu

:eventlog
cls
echo Clearing Event Logs...
echo This requires admin rights.
timeout /t 2
for /F "tokens=*" %%A in ('wevtutil el') do (
    wevtutil cl "%%A" 2>nul
)
echo Event logs cleared!
pause
goto menu

:processes
cls
echo Running Processes
echo.
tasklist /v
echo.
pause
goto menu

:dism
cls
echo Running DISM (Windows Image Repair)...
echo This may take several minutes. Please wait...
timeout /t 2
dism /online /cleanup-image /restorehealth
echo.
echo DISM repair completed!
pause
goto menu

:end
cls
echo Thank you for using PC Troubleshooting Tool!
timeout /t 2
exit /b
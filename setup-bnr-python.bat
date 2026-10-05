@echo off
setlocal
REM One-time BNR Python setup/repair. Keep this file in the repository root.
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0scripts\powershell\setup-bnr-python.ps1" %*
set "BNR_SETUP_RESULT=%ERRORLEVEL%"
echo.
if not "%BNR_SETUP_RESULT%"=="0" echo BNR Python setup did not complete. Read the message above.
pause
exit /b %BNR_SETUP_RESULT%

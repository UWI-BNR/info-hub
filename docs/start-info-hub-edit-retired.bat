@echo off
REM ============================================================
REM BNR info-hub edit session launcher
REM Opens VS Code and starts a local Quarto preview server.
REM The repository root is derived from this BAT file location.
REM ============================================================

REM Resolve project paths from the folder containing this BAT file.
set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "SITE=%REPO%\site"
set "VENV=%REPO%\venv-info-hub"
set "PORT=4200"
set "URL=http://127.0.0.1:%PORT%/"

REM Check repo folder exists
if not exist "%REPO%" (
    echo ERROR: Repo folder not found:
    echo %REPO%
    pause
    exit /b 1
)

REM Check site folder and Quarto config exist
if not exist "%SITE%\_quarto.yml" (
    echo ERROR: Quarto site config not found:
    echo %SITE%\_quarto.yml
    echo.
    echo Check that this BAT file is stored in the info-hub repository root.
    pause
    exit /b 1
)

REM Check virtual environment exists
if not exist "%VENV%\Scripts\activate.bat" (
    echo ERROR: Python virtual environment not found:
    echo %VENV%
    echo.
    echo Complete Technical Manual Chapter 2 workstation setup first.
    pause
    exit /b 1
)

REM Move to repo root
cd /d "%REPO%"

REM Find VS Code
set "VSCODE=%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe"
if not exist "%VSCODE%" set "VSCODE=%PROGRAMFILES%\Microsoft VS Code\Code.exe"

REM Open VS Code without leaving a second command window open.
if exist "%VSCODE%" (
    powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%VSCODE%' -ArgumentList '%REPO%'"
) else (
    echo WARNING: VS Code executable not found in expected locations.
    echo Opening the repo folder in File Explorer instead.
    powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%REPO%'"
)

REM Start Quarto preview in its own Command Prompt.
start "BNR info-hub Quarto Preview" cmd /k "cd /d ""%REPO%"" && call ""%VENV%\Scripts\activate.bat"" && cd /d ""%SITE%"" && quarto preview --host 127.0.0.1 --port %PORT% --no-browser"

REM Give Quarto a few seconds to start before opening the browser.
timeout /t 5 >nul

REM Prefer Firefox when installed; otherwise use the default browser.
if exist "C:\Program Files\Mozilla Firefox\firefox.exe" (
    powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe' -ArgumentList '%URL%'"
) else (
    powershell -NoProfile -WindowStyle Hidden -Command "Start-Process '%URL%'"
)

exit

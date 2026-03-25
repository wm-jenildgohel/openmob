@echo off
title OpenMob - Mobile Device Automation
echo.
echo   ___                   __  __       _
echo  / _ \ _ __   ___ _ __ ^|  \/  ^| ___ ^| ^|__
echo ^| ^| ^| ^| '_ \ / _ \ '_ \^| ^|\/^| ^|/ _ \^| '_ \
echo ^| ^|_^| ^| ^|_) ^|  __/ ^| ^| ^| ^|  ^| ^| (_) ^| ^|_) ^|
echo  \___/^| .__/ \___^|_^| ^|_^|_^|  ^|_^|\___/^|_.__/
echo       ^|_^|
echo.
echo  Free, self-hosted mobile device automation
echo  ============================================
echo.

:: Check ADB
where adb >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] ADB not found. Install Android Platform Tools:
    echo     https://developer.android.com/tools/releases/platform-tools
    echo     Or: winget install Google.PlatformTools
    echo.
)

:: Show connected devices
echo [*] Connected devices:
adb devices -l 2>nul || echo     (none)
echo.

:: Check if Hub exe exists
if exist "%~dp0openmob_hub.exe" (
    echo [*] Starting OpenMob Hub...
    start "" "%~dp0openmob_hub.exe"
    echo     Hub started!
) else (
    echo [!] openmob_hub.exe not found.
    echo     Build it on Windows: cd openmob_hub ^&^& flutter build windows
    echo     Copy build\windows\x64\runner\Release\* here
    echo.
)

echo.
echo [*] MCP server: %~dp0openmob-mcp.exe
echo     Add to your AI tool's MCP config:
echo     { "command": "%~dp0openmob-mcp.exe" }
echo.
echo [*] AiBridge: %~dp0aibridge.exe
echo     Usage: aibridge.exe -- claude
echo.
echo ============================================
echo [*] OpenMob ready!
echo     Dashboard: http://127.0.0.1:8686
echo     API: http://127.0.0.1:8686/api/v1/devices/
echo ============================================
echo.
pause

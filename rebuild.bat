@echo off
REM Rebuild DX.TOML projects using universal Build-DPROJ.ps1 script
REM This is a simple wrapper around the PowerShell build script

echo ========================================
echo Rebuilding DX.TOML Projects
echo ========================================
echo.

REM Run the PowerShell build-and-test script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0BuildScripts\build-and-test.ps1" -SkipTests

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo ERROR: Build failed!
    echo ========================================
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo ========================================
echo.
echo To run unit tests:
echo   Win32\Debug\DX.TOML.Tests.exe
echo.
echo To run full build and test:
echo   powershell -ExecutionPolicy Bypass -File BuildScripts\build-and-test.ps1
echo.

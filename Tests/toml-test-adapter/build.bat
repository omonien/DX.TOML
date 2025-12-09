@echo off
REM Build script for DX.TOML.TestAdapter using universal Build-DPROJ.ps1

echo Building DX.TOML toml-test adapter...
echo.

REM Call the universal build script
powershell.exe -ExecutionPolicy Bypass -File "..\..\BuildScripts\Build-DPROJ.ps1" -ProjectFile "%~dp0DX.TOML.TestAdapter.dproj" -Config Debug -Platform Win32

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build successful!
    echo Executable: %~dp0DX.TOML.TestAdapter.exe
    echo.
    echo To run toml-test:
    echo   C:\tools\toml-test.exe "%~dp0DX.TOML.TestAdapter.exe"
) else (
    echo.
    echo Build failed!
    exit /b 1
)
